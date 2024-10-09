defmodule Nebulex.Adapters.Horde do
  @moduledoc """
  Nebulex adapter for [Horde][Horde].

  NOTE: This adapter only supports Nebulex v2.0.0 onwards.

  [Horde]: https://hexdocs.pm/horde/readme.html

  ## Overall features

    * In-memory data storage in GenServer, distributed relying on Horde with CRDT.
    * Every cache entry is a process supervised by Horde.
    * Expired entries are lost forever (process termination).
    * Processes hand-off with graceful shutdown thanks to Horde.
    * Configurable primary storage adapter.
    * Support for transactions via Erlang global name registration facility.
    * Stats support rely on the primary storage adapter.

  ## Configuration

  You can define a cache using Horde as follows:

  ```elixir
  defmodule MyApp.Cache do
    use Nebulex.Cache,
      otp_app: :my_app,
      adapter: Nebulex.Adapters.Horde,
      horde: [
        members: :auto,
        process_redistribution: :passive
        # any other horde configs
      ]
  end
  ```

  And in the `application.ex` file:

  ```elixir
  def start(_type, _args) do
    children = [
      {MyApp.Cache, []},
    ]
    ...
  end
  ```
  """

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Entry
  @behaviour Nebulex.Adapter.Queryable
  @behaviour Nebulex.Adapter.Stats

  # Inherit default transaction implementation
  use Nebulex.Adapter.Transaction

  # Inherit default persistence implementation
  use Nebulex.Adapter.Persistence

  import Nebulex.Adapter
  import Nebulex.Helpers

  alias Nebulex.Adapters.Horde.Cache

  @compile {:inline, to_ttl: 1}

  ## Nebulex.Adapter

  @impl true
  defmacro __before_compile__(env) do
    otp_app = Module.get_attribute(env.module, :otp_app)
    opts = Module.get_attribute(env.module, :opts)
    primary = Keyword.get(opts, :primary_storage_adapter, Nebulex.Adapters.Local)

    quote do
      defmodule Primary do
        @moduledoc """
        This is the cache for the primary storage.
        """
        use Nebulex.Cache,
          otp_app: unquote(otp_app),
          adapter: unquote(primary)
      end

      @doc """
      A convenience function for getting the primary storage cache.
      """
      def __primary__, do: Primary
    end
  end

  @impl true
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)
    name = normalize_module_name([opts[:name] || cache, Horde])

    registry_name = normalize_module_name([name, Registry])
    dynamic_supervisor_name = normalize_module_name([name, DynamicSupervisor])
    telemetry_prefix = Keyword.fetch!(opts, :telemetry_prefix)
    telemetry = Keyword.fetch!(opts, :telemetry)
    stats = get_boolean_option(opts, :stats)

    horde_registry_opts =
      [
        members: :auto,
        process_redistribution: :passive
      ]
      |> Keyword.merge(opts[:horde] || [])

    horde_dynamic_supervisor_opts =
      [
        name: dynamic_supervisor_name,
        strategy: :one_for_one
      ]
      |> Keyword.merge(horde_registry_opts)

    # Primary cache options
    primary_opts =
      Keyword.merge(
        [telemetry_prefix: telemetry_prefix ++ [:primary], telemetry: telemetry, stats: stats],
        Keyword.get(opts, :primary, [])
      )

    # Maybe put a name to primary storage
    primary_opts =
      if opts[:name],
        do: [name: normalize_module_name([name, Primary])] ++ primary_opts,
        else: primary_opts

    child_spec =
      Nebulex.Adapters.Supervisor.child_spec(
        name: normalize_module_name([name, Supervisor]),
        strategy: :rest_for_one,
        children: [
          {cache.__primary__(), primary_opts},
          Nebulex.Adapters.Horde.Registry.child_spec(registry_name, horde_registry_opts),
          {Nebulex.Adapters.Horde.DynamicSupervisor, horde_dynamic_supervisor_opts}
        ]
      )

    adapter_meta = %{
      name: dynamic_supervisor_name,
      registry_name: registry_name,
      telemetry: telemetry,
      telemetry_prefix: telemetry_prefix,
      stats: stats,
      primary_name: primary_opts[:name],
      started_at: DateTime.utc_now(),
      cache: cache
    }

    {:ok, child_spec, adapter_meta}
  end

  ## Nebulex.Adapter.Entry

  @impl true
  defspan get(adapter_meta, key, _opts) do
    Cache.get!(adapter_meta, key)
  end

  @impl true
  defspan get_all(adapter_meta, keys, _opts) do
    Cache.get_all!(adapter_meta, keys)
  end

  @impl true
  defspan put(adapter_meta, key, value, ttl, on_write, _opts) do
    do_put(adapter_meta, key, value, ttl, on_write)
  end

  defp do_put(adapter_meta, key, value, ttl, :put) do
    Cache.put!(adapter_meta, key, value, to_ttl(ttl))
  end

  defp do_put(adapter_meta, key, value, ttl, :replace) do
    Cache.update!(adapter_meta, key, value, to_ttl(ttl))
  end

  defp do_put(adapter_meta, key, value, ttl, :put_new) do
    Cache.put_new!(adapter_meta, key, value, to_ttl(ttl))
  end

  @impl true
  defspan put_all(adapter_meta, entries, ttl, on_write, _opts) do
    do_put_all(adapter_meta, entries, ttl, on_write)
  end

  defp do_put_all(adapter_meta, entries, ttl, on_write) when is_map(entries) do
    do_put_all(adapter_meta, Map.to_list(entries), ttl, on_write)
  end

  defp do_put_all(adapter_meta, entries, ttl, :put) when is_list(entries) do
    Cache.put_all!(adapter_meta, entries, to_ttl(ttl))
  end

  defp do_put_all(adapter_meta, entries, ttl, :put_new) when is_list(entries) do
    Cache.put_new_all!(adapter_meta, entries, to_ttl(ttl))
  end

  @impl true
  defspan delete(adapter_meta, key, _opts) do
    Cache.delete!(adapter_meta, key)
  end

  @impl true
  defspan take(adapter_meta, key, _opts) do
    Cache.take!(adapter_meta, key)
  end

  @impl true
  defspan has_key?(adapter_meta, key) do
    Cache.exists?(adapter_meta, key)
  end

  @impl true
  defspan ttl(adapter_meta, key) do
    Cache.ttl!(adapter_meta, key)
  end

  @impl true
  defspan expire(adapter_meta, key, ttl) do
    Cache.expire!(adapter_meta, key, to_ttl(ttl))
  end

  @impl true
  defspan touch(adapter_meta, key) do
    Cache.touch!(adapter_meta, key)
  end

  @impl true
  defspan update_counter(adapter_meta, key, amount, ttl, default, _opts) do
    Cache.update_counter!(adapter_meta, key, amount, to_ttl(ttl), default)
  end

  ## Nebulex.Adapter.Queryable

  @impl true
  defspan execute(adapter_meta, operation, query, opts) do
    do_execute(adapter_meta, operation, query, opts)
  end

  defp do_execute(adapter_meta, :count_all, query, _opts) when query in [nil, :unexpired] do
    Cache.count_all(adapter_meta)
  end

  defp do_execute(adapter_meta, :delete_all, query, _opts) when query in [nil, :unexpired] do
    Cache.delete_all(adapter_meta)
  end

  defp do_execute(adapter_meta, :all, query, opts) when query in [nil, :unexpired] do
    Cache.all(adapter_meta, opts[:return])
  end

  defp do_execute(_adapter_meta, operation, query, _opts) do
    raise Nebulex.QueryError, message: "unsupported #{operation}", query: query
  end

  @impl true
  defspan stream(adapter_meta, query, opts) do
    do_stream(adapter_meta, query, opts)
  end

  defp do_stream(adapter_meta, nil, opts) do
    Cache.stream_all(adapter_meta, opts[:return])
  end

  defp do_stream(_adapter_meta, query, _opts) do
    raise Nebulex.QueryError, message: "unsupported stream all operation", query: query
  end

  ## Nebulex.Adapter.Transaction

  @impl true
  defspan transaction(adapter_meta, opts, fun) do
    nodes =
      Horde.Cluster.members(adapter_meta.name)
      |> Enum.map(fn
        {_name, node} -> node
        node -> node
      end)

    super(adapter_meta, Keyword.put(opts, :nodes, nodes), fun)
  end

  @impl true
  defspan in_transaction?(adapter_meta) do
    super(adapter_meta)
  end

  ## Nebulex.Adapter.Persistence

  @impl true
  defspan dump(adapter_meta, path, opts) do
    super(adapter_meta, path, opts)
  end

  @impl true
  defspan load(adapter_meta, path, opts) do
    super(adapter_meta, path, opts)
  end

  ## Nebulex.Adapter.Stats

  @impl true
  defspan stats(adapter_meta) do
    with_dynamic_cache(adapter_meta, :stats, [])
  end

  ## Helpers

  @doc false
  def with_dynamic_cache(%{cache: cache, primary_name: nil}, action, args) do
    apply(cache.__primary__(), action, args)
  end

  def with_dynamic_cache(%{cache: cache, primary_name: primary_name}, action, args) do
    cache.__primary__().with_dynamic_cache(primary_name, fn ->
      apply(cache.__primary__(), action, args)
    end)
  end

  ## Private functions

  defp to_ttl(:infinity), do: nil
  defp to_ttl(ttl), do: ttl
end
