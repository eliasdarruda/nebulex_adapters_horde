benchmarks = %{
  "get" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :get, [input])
  end,
  "get_all" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :get_all, [[input, "foo", "bar"]])
  end,
  "put" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :put, [input, input])
  end,
  "put_new" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :put_new, [input, input])
  end,
  "replace" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :replace, [input, input])
  end,
  "put_all" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :put_all, [[{input, input}, {"foo", "bar"}]])
  end,
  "delete" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :delete, [input])
  end,
  "take" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :take, [input])
  end,
  "has_key?" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :has_key, [input])
  end,
  "size" => fn {_input, node} ->
    :rpc.block_call(node, BenchCache, :size, [])
  end,
  "ttl" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :ttl, [input])
  end,
  "expire" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :expire, [input, 1])
  end,
  "incr" => fn {_input, node} ->
    :rpc.block_call(node, BenchCache, :incr, [:counter, 1])
  end,
  "update" => fn {input, node} ->
    :rpc.block_call(node, BenchCache, :update, [input, 1, &Kernel.+(&1, 1)])
  end,
  "all" => fn {_input, node} ->
    :rpc.block_call(node, BenchCache, :all, [])
  end
}

BenchCache.put(:ping_cache, :self_check)
cache_active? = BenchCache.get(:ping_cache) == :self_check

if not cache_active?, do: raise "Cache is not loaded for some reason"

1..50
|> Flow.from_enumerable(max_demand: System.schedulers_online)
|> Flow.map(fn n ->
  try do
    SlaveNode.spawn()

    IO.puts "Node #{n} spawned"
  catch
    :exit, _ ->
      IO.puts "Node #{n} not ok"
  end
end)
|> Flow.run

IO.puts "Nodes connected count #{Node.list() |> Enum.count}"
IO.puts "---------------------------------------------------"

Benchee.run(
  benchmarks,
  inputs: %{"rand" => 100_000},
  before_each: fn n -> {:rand.uniform(n), Node.list ++ [Node.self()] |> Enum.random} end,
  formatters: [
    {Benchee.Formatters.Console, comparison: false, extended_statistics: true},
    # {Benchee.Formatters.HTML, extended_statistics: true, auto_open: false}
  ],
  print: [
    fast_warning: false
  ]
)
