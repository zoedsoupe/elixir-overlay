defmodule PhoenixFixtureWeb.Router do
  use Phoenix.Router

  get("/", PhoenixFixtureWeb.PageController, :index)
end
