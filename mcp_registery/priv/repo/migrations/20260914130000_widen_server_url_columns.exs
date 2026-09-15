defmodule McpRegistry.Repo.Migrations.WidenServerUrlColumns do
  use Ecto.Migration

  # Official registry listings include hosted URLs thousands of characters long.
  def change do
    alter table(:servers) do
      modify :remote_url, :text, from: :string
      modify :package_identifier, :text, from: :string
      modify :repository_url, :text, from: :string
      modify :website_url, :text, from: :string
    end
  end
end
