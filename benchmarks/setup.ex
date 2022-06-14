defmodule BenchTestApplication do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BenchCache
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BenchTestApplication.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule BenchCache do
  use Nebulex.Cache,
    otp_app: :nebulex_adapters_horde,
    adapter: Nebulex.Adapters.Horde
end
