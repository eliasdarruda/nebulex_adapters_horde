defmodule Nebulex.Adapters.HordeTest do
  @moduledoc """
  Shared Tests
  """

  defmacro __using__(_opts) do
    quote do
      use Nebulex.Cache.EntryTest
      use Nebulex.Cache.EntryExpirationTest
      use Nebulex.Cache.TransactionTest
      use Nebulex.Adapters.Horde.PersistenceTest
      use Nebulex.Adapters.Horde.QueryableTest
    end
  end
end
