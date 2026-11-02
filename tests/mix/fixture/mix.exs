defmodule MixFixture.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_fixture,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
