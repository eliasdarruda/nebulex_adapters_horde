defmodule Nebulex.Adapters.Horde.Registry do
  @moduledoc """
  Defines a distributed registry for all processes under Horde.DynamicSupervisor
  """
  use Horde.Registry

  def child_spec(name, opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [name, opts]}
    }
  end

  @doc false
  def start_link(name, opts) do
    # Horde Registry doesn't support duplicate keys
    opts = opts |> Keyword.put(:keys, :unique)

    Horde.Registry.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(args) do
    Horde.Registry.init(args)
  end
end
