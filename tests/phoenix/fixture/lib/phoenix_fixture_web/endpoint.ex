defmodule PhoenixFixtureWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_fixture

  plug(Plug.Static,
    at: "/",
    from: :phoenix_fixture,
    gzip: false,
    only: ~w(assets favicon.ico robots.txt)
  )

  plug(PhoenixFixtureWeb.Router)
end
