defmodule McpRegistry.Repo do
  use Ecto.Repo,
    otp_app: :mcp_registry,
    adapter: Ecto.Adapters.Postgres
end
