defmodule NebulexAdaptersHorde.LocalTest do
  use ExUnit.Case, async: true
  use Nebulex.Adapters.HordeTest

  import Nebulex.CacheCase

  alias NebulexAdaptersHorde.TestCache.Local

  setup_with_dynamic_cache(Local, :local_with_horde)

  describe "count_all/2 error:" do
    test "unsupported query", %{cache: cache} do
      assert_raise Nebulex.QueryError, ~r"unsupported count_all in query", fn ->
        cache.count_all(:expired)
      end
    end
  end

  describe "delete_all/2 error:" do
    test "unsupported query", %{cache: cache} do
      assert_raise Nebulex.QueryError, ~r"unsupported delete_all in query", fn ->
        cache.delete_all(:expired)
      end
    end
  end

  describe "all/2 error:" do
    test "unsupported query", %{cache: cache} do
      assert_raise Nebulex.QueryError, ~r"unsupported all in query", fn ->
        cache.all(:expired)
      end
    end
  end
end
