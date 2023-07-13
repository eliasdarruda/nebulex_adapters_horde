# Nebulex.Adapters.Horde

This implements a Nebulex adapter using [Horde](https://github.com/derekkraan/horde) to store in-memory distributed data, you can check Horde page to see more details about its advantages.

This is a alternative to `Nebulex Partitioned Cache` that uses `:pg` under the hood.

**NOTE**: This adapter only supports Nebulex v2.0.0 onwards.

## Overall features

  * In-memory data storage in GenServer, distributed relying on Horde with CRDT.
  * Every cache entry is a process supervised by Horde.
    * This trades off with memory, every cache entry will also have the memory from the process itself with it.
    * Its good when you know that you are not going to have a huge amount of entries.
  * Expired entries are lost forever (process termination).
  * Processes hand-off with graceful shutdown thanks to Horde.
  * Configurable primary storage adapter.
  * Support for transactions via Erlang global name registration facility.
  * Stats support rely on the primary storage adapter.

## Installation

Add `nebulex_adapters_horde` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_adapters_horde, "~> 1.0.0"}
  ]
end
```

## Usage

You can define a Cache using this adapter as follows:

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Horde,
    horde: [
      members: :auto,
      process_redistribution: :passive
      # any other Horde options ...
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

## Roadmap

- [x] Cache Entry
- [x] Common Nebulex Functions
- [x] Iteraction with `Horde.DynamicSupervisor` and `Horde.Registry`
- [x] Every Cache Entry is a process supervised by `Horde`
- [x] Transaction and correct transaction locks
- [x] Stats fallback to Primary Cache (it will only export stats inserted through Local, this is only useful when using Multilevel)
- [ ] Distributed Stats Mechanism

## Testing

Since `Nebulex.Adapters.Horde` uses the support modules and shared tests
from `Nebulex` and by default its test folder is not included in the Hex
dependency, the following steps are required for running the tests.

First of all, make sure you set the environment variable `NEBULEX_PATH`
to `nebulex`:

```
export NEBULEX_PATH=nebulex
```

Second, make sure you fetch `:nebulex` dependency directly from GtiHub
by running:

```
mix nbx.setup
```

Third, fetch deps:

```
mix deps.get
```

Finally, you can run the tests:

```
mix test
```

## Running Benchmarks

Everything related to benchmark is in `benchmarks/benchmarks.exs`, to run it you can use: `MIX_ENV=test mix run benchmarks/benchmarks.exs`

The details of benchmark of `Horde` against `Partitioned` adapter is in `benchmarks/details.txt`

## Notes

This is heavily influenced by [nebulex_adapters_cache by cabol](https://github.com/cabol/nebulex_adapters_cachex), I've used a lot of the testing method implemented there
