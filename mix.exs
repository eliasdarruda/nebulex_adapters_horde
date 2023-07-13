defmodule NebulexAdaptersHorde.MixProject do
  use Mix.Project

  @source_url "https://github.com/eliasdarruda/nebulex_adapters_horde"
  @version "1.0.1"

  def project do
    [
      app: :nebulex_adapters_horde,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      package: package(),
      description: "A Nebulex adapter for Horde",

      # Docs
      docs: [
        main: "Nebulex.Adapters.Horde",
        source_ref: "v#{@version}",
        source_url: @source_url
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "benchmarks"]
  defp elixirc_paths(_), do: ["lib"]

  if Mix.env() == :test do
    def application do
      [
        mod: {BenchTestApplication, []}
      ]
    end
  else
    def application do
      []
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      nebulex_dep(),
      {:horde, "~> 0.8.7"},
      {:benchee, "~> 1.0", only: :test},
      {:benchee_html, "~> 1.0", only: :test},
      {:flow, "~> 1.1", only: :test},

      # Docs
      {:ex_doc, "~> 0.23", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "nbx.setup": [
        "cmd rm -rf nebulex",
        "cmd git clone --depth 1 --branch v2.3.2 https://github.com/cabol/nebulex"
      ]
    ]
  end

  defp package do
    [
      name: :nebulex_adapters_horde,
      maintainers: ["Elias Arruda"],
      licenses: [],
      links: %{"GitHub" => @source_url},
      source_url: @source_url
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
