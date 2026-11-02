import Config

config :phoenix_fixture, PhoenixFixtureWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  server: false,
  secret_key_base: String.duplicate("a", 64),
  render_errors: [formats: [html: PhoenixFixtureWeb.ErrorHTML], layout: false]

config :phoenix_fixture, ecto_repos: []

config :tailwind,
  version: "4.3.1",
  default: ["--input=assets/css/app.css", "--output=priv/static/assets/app.css"]

config :esbuild,
  version: "0.27.2",
  default: ["js/app.js", "--bundle", "--target=es2017", "--outdir=../priv/static/assets"]

import_config "#{config_env()}.exs"
