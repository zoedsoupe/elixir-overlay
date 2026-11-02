defmodule PhoenixFixture.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [PhoenixFixtureWeb.Endpoint]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: PhoenixFixture.Supervisor
    )
  end
end
