defmodule McpRegistry.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :name, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :version, :string, null: false, default: "0.1.0"
      add :status, :string, null: false, default: "active"
      add :transport, :string, null: false, default: "stdio"
      add :remote_url, :string
      add :package_registry, :string
      add :package_identifier, :string
      add :repository_url, :string
      add :website_url, :string
      add :license, :string
      add :env_vars, {:array, :string}, null: false, default: []
      add :tags, {:array, :string}, null: false, default: []
      add :tools, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:servers, [:name])
    create index(:servers, [:status])
    create index(:servers, [:transport])
    create index(:servers, [:tags], using: :gin)
  end
end
