defmodule Mix.Tasks.Mcp.Approve do
  @shortdoc "Approves a pending server listing: mix mcp.approve io.github.acme/weather"
  @moduledoc @shortdoc
  use Mix.Task

  @impl true
  def run([name]) do
    Mix.Task.run("app.start")

    case McpRegistry.Registry.approve_server(name) do
      {:ok, server} -> Mix.shell().info("Approved #{server.name} (#{server.title}).")
      {:error, :not_found} -> Mix.raise("No server named #{name}.")
      {:error, changeset} -> Mix.raise("Could not approve: #{inspect(changeset.errors)}")
    end
  end

  def run(_), do: Mix.raise("Usage: mix mcp.approve <namespace/server-name>")
end
