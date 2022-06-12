defmodule Nebulex.Adapters.Horde.QueryableTest do
  import Nebulex.CacheCase

  deftests do
    import Nebulex.CacheCase

    describe "all/2" do
      test "returns all keys in cache", %{cache: cache} do
        set1 = cache_put(cache, 1..50)
        set2 = cache_put(cache, 51..100)

        for x <- 1..100, do: assert(cache.get(x) == x)
        expected = set1 ++ set2

        assert :lists.usort(cache.all()) == expected

        set3 = Enum.to_list(20..60)
        :ok = Enum.each(set3, &cache.delete(&1))
        expected = :lists.usort(expected -- set3)

        assert :lists.usort(cache.all()) == expected
      end
    end

    describe "stream/2" do
      @entries for x <- 1..10, into: %{}, do: {x, x * 2}

      test "returns all keys in cache", %{cache: cache} do
        :ok = cache.put_all(@entries)

        assert nil
               |> cache.stream()
               |> Enum.to_list()
               |> :lists.usort() == Map.keys(@entries)
      end

      test "returns all values in cache", %{cache: cache} do
        :ok = cache.put_all(@entries)

        assert cache.stream(nil, return: :value)
               |> Enum.to_list()
               |> :lists.usort() == Map.values(@entries)
      end

      test "returns all key/value pairs in cache", %{cache: cache} do
        :ok = cache.put_all(@entries)

        assert cache.stream(nil, return: {:key, :value})
               |> Enum.to_list()
               |> :lists.usort() == :maps.to_list(@entries)
      end

      test "raises error when using query", %{cache: cache} do
        assert_raise Nebulex.QueryError, fn ->
          :invalid_query
          |> cache.stream()
          |> Enum.to_list()
        end
      end
    end
  end
end
