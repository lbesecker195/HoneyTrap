import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mcp_registry, McpRegistry.Repo,
  username: System.get_env("PGUSER", "logan"),
  password: System.get_env("PGPASSWORD", ""),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "mcp_registry_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mcp_registry, McpRegistryWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "vH29Ekr1YwBV5aq/V4g/PFU9FJiHmkwjD72dL1Tj4AAvjtdzCGyT5EroQ8RHOEq0",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Many tests submit from the same address; the rate limit test lowers this itself.
config :mcp_registry, :submissions,
  per_client_per_hour: 10_000,
  max_pending: 10_000

# The official registry is stubbed with Req.Test in tests.
config :mcp_registry, :official_registry,
  page_delay_ms: 0,
  req_options: [plug: {Req.Test, McpRegistry.OfficialRegistry}, retry_delay: 0, max_retries: 2]
