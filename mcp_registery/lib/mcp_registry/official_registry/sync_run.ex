defmodule McpRegistry.OfficialRegistry.SyncRun do
  @moduledoc "One run of the official registry sync, kept for scheduling and troubleshooting."
  use Ecto.Schema

  schema "registry_syncs" do
    field :mode, :string
    field :status, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :stats, :map, default: %{}
    field :error, :string

    timestamps(type: :utc_datetime)
  end
end
