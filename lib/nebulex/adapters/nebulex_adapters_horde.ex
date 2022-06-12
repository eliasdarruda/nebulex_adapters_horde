defmodule Nebulex.Adapters.Horde do
  @moduledoc """
  Nebulex adapter for [Horde][Horde].

  [Horde]: https://hexdocs.pm/horde/readme.html

  ## Example
  You can define a cache using Horde as follows:

  ```
  defmodule MyApp.Cache do
    use Nebulex.Cache,
      otp_app: :my_app,
      adapter: Nebulex.Adapters.Horde,
      horde: [
        members: :auto,
        process_redistribution: :passive
      ]
  end
  ```
  """

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Entry
  @behaviour Nebulex.Adapter.Queryable

  # Inherit default transaction implementation
  use Nebulex.Adapter.Transaction

  # Inherit default persistence implementation
  use Nebulex.Adapter.Persistence

  # Inherit default stats implementation
  use Nebulex.Adapter.Stats

  import Nebulex.Adapter
  import Nebulex.Helpers

  alias Nebulex.Adapters.Horde.Cache

  @compile {:inline, to_ttl: 1}

  ## Nebulex.Adapter

  @impl true
  defmacro __before_compile__(_), do: :ok

  @impl true
  def init(opts) do
    name =
      normalize_module_name([
        opts[:name] || Keyword.fetch!(opts, :cache),
        Horde
      ])

    registry_name = normalize_module_name([name, Registry])
    dynamic_supervisor_name = normalize_module_name([name, DynamicSupervisor])

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

    child_spec =
      Nebulex.Adapters.Supervisor.child_spec(
        name: normalize_module_name([name, Supervisor]),
        strategy: :rest_for_one,
        children: [
          Nebulex.Adapters.Horde.Registry.child_spec(registry_name, horde_registry_opts),
          {Nebulex.Adapters.Horde.DynamicSupervisor, horde_dynamic_supervisor_opts}
        ]
      )

    adapter_meta = %{
      name: dynamic_supervisor_name,
      registry_name: registry_name,
      telemetry: Keyword.fetch!(opts, :telemetry),
      telemetry_prefix: Keyword.fetch!(opts, :telemetry_prefix),
      stats: stats,
      started_at: DateTime.utc_now()
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
    super(adapter_meta, Keyword.put(opts, :nodes, Horde.Cluster.members(adapter_meta.name)), fun)
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
    if stats = super(adapter_meta) do
      %{stats | metadata: Map.put(stats.metadata, :started_at, adapter_meta.started_at)}
    end
  end

  ## Private functions

  defp to_ttl(:infinity), do: nil
  defp to_ttl(ttl), do: ttl
end
