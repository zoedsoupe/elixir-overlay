defmodule PhoenixFixtureWeb.PageController do
  use Phoenix.Controller, formats: [:html]

  def index(conn, _params) do
    text(conn, "phoenix fixture is running")
  end
end
