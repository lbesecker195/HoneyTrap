defmodule McpRegistry.Repo.Migrations.AddOfficialRegistrySync do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      # Where a listing came from: local (submitted here), seed (starter
      # catalogue) or official (copied from the official MCP Registry).
      add :origin, :string, null: false, default: "local"
      add :source_updated_at, :utc_datetime_usec
      add :synced_at, :utc_datetime_usec
    end

    create index(:servers, [:origin])
    create index(:servers, [:status, :origin, :title])

    execute(
      "UPDATE servers SET origin = 'seed' WHERE name IN ('io.github.modelcontextprotocol/server-filesystem','io.github.modelcontextprotocol/server-memory','io.github.modelcontextprotocol/server-sequential-thinking','io.github.modelcontextprotocol/server-everything','io.github.modelcontextprotocol/fetch','io.github.modelcontextprotocol/git','io.github.modelcontextprotocol/time','io.github.github/github-mcp-server','io.github.microsoft/playwright-mcp','io.github.upstash/context7','com.brave/brave-search','com.supabase/mcp-server-supabase','com.notion/mcp','com.linear/mcp','com.sentry/mcp','com.stripe/mcp','com.cloudflare/docs','com.deepwiki/mcp','com.huggingface/mcp','io.github.exa-labs/exa-mcp-server')",
      "SELECT 1"
    )

    create table(:registry_syncs) do
      add :mode, :string, null: false
      add :status, :string, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec
      add :stats, :map, null: false, default: %{}
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:registry_syncs, [:status, :started_at])
  end
end
