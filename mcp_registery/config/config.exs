# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mcp_registry,
  ecto_repos: [McpRegistry.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :mcp_registry, McpRegistryWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: McpRegistryWeb.ErrorHTML, json: McpRegistryWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: McpRegistry.PubSub,
  live_view: [signing_salt: "Zg13WBT8"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mcp_registry: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  mcp_registry: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Seriously Simple Analytics (https://seriouslysimpleanalytics.com).
# One account ID drives both the browser tag in the root layout and the
# server-side pings in McpRegistry.Analytics. Set SSA_ACCOUNT_ID at runtime;
# with no ID configured, analytics is a no-op.
config :mcp_registry, :analytics,
  account_id: nil,
  project: "mcp-registry"

# API publishing (POST /api/v0/servers) requires a bearer token. Leave it nil
# to disable API publishing; the /submit web form still works.
config :mcp_registry, :registry, publish_token: nil

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
