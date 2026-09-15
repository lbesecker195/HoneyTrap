defmodule Mix.Tasks.Registry.SyncOfficial do
  @shortdoc "Copies servers from the official MCP Registry: mix registry.sync_official [--full]"
  @moduledoc @shortdoc
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    mode = if "--full" in args, do: :full, else: :auto

    case McpRegistry.OfficialRegistry.sync(mode: mode) do
      {:ok, stats} -> Mix.shell().info("Sync finished: #{inspect(stats)}")
      {:error, :already_running} -> Mix.raise("A sync is already running.")
      {:error, reason, stats} -> Mix.raise("Sync failed: #{reason}. Progress: #{inspect(stats)}")
    end
  end
end
