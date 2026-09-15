defmodule McpRegistryWeb.API.ServerJSON do
  alias McpRegistry.Registry.Manifest
  alias McpRegistry.Registry.Server

  def index(%{servers: servers, total: total, limit: limit, offset: offset}) do
    next_offset = offset + limit

    %{
      servers: Enum.map(servers, &entry/1),
      metadata: %{
        count: length(servers),
        total: total,
        limit: limit,
        offset: offset,
        next_offset: if(next_offset < total, do: next_offset, else: nil)
      }
    }
  end

  def show(%{server: server}), do: entry(server)

  defp entry(%Server{} = server) do
    %{
      server: Manifest.to_map(server),
      _meta: %{
        "io.mcpregistry/official" => %{
          status: server.status,
          origin: server.origin,
          synced_at: server.synced_at,
          published_at: server.inserted_at,
          updated_at: server.updated_at,
          is_latest: true
        }
      }
    }
  end
end
