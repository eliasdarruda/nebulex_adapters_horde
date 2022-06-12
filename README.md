# Nebulex.Adapters.Horde (WIP)

This implements a Nebulex adapter using [Horde](https://github.com/derekkraan/horde) to store in-memory distributed data, you can check Horde page to see more details about its advantages.

This is a alternative to `Nebulex Partitioned Cache` that uses `:pg` under the hood.


## TODO 

- [x] Cache Entry
- [x] Common Nebulex Functions
- [x] Iteraction with `Horde.DynamicSupervisor` and `Horde.Registry`
- [x] Every Cache Entry is a process supervised by `Horde`
- [x] Transaction
- [ ] Stats Exporting
- [ ] Transaction Aborted Test

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

## Installation (not available yet)

Add `nebulex_adapters_horde` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_adapters_horde, "~> 0.0.1"}
  ]
end
```

## Usage

You can define a Cache using this adapter as follows:

```
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