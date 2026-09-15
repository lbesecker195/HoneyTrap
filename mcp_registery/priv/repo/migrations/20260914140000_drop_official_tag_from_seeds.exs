defmodule McpRegistry.Repo.Migrations.DropOfficialTagFromSeeds do
  use Ecto.Migration

  # The starter catalogue tagged reference servers "official", which now reads
  # as "from the official MCP Registry". Their "reference" tag already says it.
  def up do
    execute "UPDATE servers SET tags = array_remove(tags, 'official') WHERE origin = 'seed'"
  end

  def down, do: :ok
end
