defmodule PhoenixFixture.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_fixture,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PhoenixFixture.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.16"},
      {:tailwind, "~> 0.5.2", runtime: Mix.env() == :prod},
      {:esbuild, "~> 0.10.1", runtime: Mix.env() == :prod}
    ]
  end

  defp aliases do
    [
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
