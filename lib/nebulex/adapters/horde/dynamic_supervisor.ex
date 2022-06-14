defmodule Nebulex.Adapters.Horde.DynamicSupervisor do
  @moduledoc """
  The Distributed Driver.DynamicSupervisor supervises Cache Items as they are needed
  """
  use Horde.DynamicSupervisor

  alias Nebulex.Adapters.Horde.GenServerItem

  def child_spec(args, id \\ nil) do
    %{
      id: id || __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient
    }
  end

  def start_link(opts) do
    Horde.DynamicSupervisor.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(args), do: Horde.DynamicSupervisor.init(args)

  @doc "Adds a GenServerItem process to Horde DynamicSupervisor tree"
  def add_gen_server_child(name, registry_name, key, value, ttl) do
    Horde.DynamicSupervisor.start_child(
      name,
      GenServerItem.child_spec(registry_name, key, value, ttl)
    )
  end
end
