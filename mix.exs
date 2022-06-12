defmodule NebulexAdaptersHorde.MixProject do
  use Mix.Project

  def project do
    [
      app: :nebulex_adapters_horde,
      version: "0.0.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      nebulex_dep(),
      {:horde, "~> 0.8.7"}
    ]
  end

  defp aliases do
    [
      "nbx.setup": [
        "cmd rm -rf nebulex",
        "cmd git clone --depth 1 --branch v2.3.2 https://github.com/cabol/nebulex"
      ],
      check: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "coveralls.html",
        "sobelow --exit --skip",
        "dialyzer --format short"
      ]
    ]
  end

  defp nebulex_dep do
    if path = System.get_env("NEBULEX_PATH") do
      {:nebulex, "~> 2.3", path: path}
    else
      {:nebulex, "~> 2.3"}
    end
  end
end
