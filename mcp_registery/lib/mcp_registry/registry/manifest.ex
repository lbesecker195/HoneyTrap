defmodule McpRegistry.Registry.Manifest do
  @moduledoc """
  Converts between `Server` records and the `server.json` manifest format used
  by the MCP registry project, so agents and publishers can speak the same
  shape they use with the official registry.

  Schema: https://static.modelcontextprotocol.io/schemas/2025-09-29/server.schema.json
  """
  alias McpRegistry.Registry.Server

  @schema "https://static.modelcontextprotocol.io/schemas/2025-09-29/server.schema.json"
  @meta_prefix "io.mcpregistry/"

  def schema_url, do: @schema

  @doc "Renders a server as a `server.json` map."
  def to_map(%Server{} = server) do
    %{
      "$schema" => @schema,
      "name" => server.name,
      "title" => server.title,
      "description" => server.description,
      "version" => server.version
    }
    |> put_if("repository", repository(server.repository_url))
    |> put_if("websiteUrl", server.website_url)
    |> put_if("packages", packages(server))
    |> put_if("remotes", remotes(server))
    |> Map.put(
      "_meta",
      %{
        (@meta_prefix <> "transport") => server.transport,
        (@meta_prefix <> "tags") => server.tags,
        (@meta_prefix <> "tools") => server.tools,
        (@meta_prefix <> "license") => server.license
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)
    )
  end

  @doc """
  Parses a `server.json` map into attributes for `Server.changeset/2`. Only the
  first package and first remote are kept; the remote, when present, decides the
  primary transport.
  """
  def from_map(%{} = json) do
    package = json |> Map.get("packages") |> first_map()
    remote = json |> Map.get("remotes") |> first_map()
    meta = Map.get(json, "_meta") || %{}

    transport =
      cond do
        remote -> normalize_transport(remote["type"])
        package -> "stdio"
        true -> nil
      end

    %{
      "name" => json["name"],
      "title" => json["title"] || default_title(json["name"]),
      "description" => json["description"],
      "version" => json["version"] || (package && package["version"]),
      "transport" => transport,
      "remote_url" => remote && remote["url"],
      "package_registry" => package && package["registryType"],
      "package_identifier" => package && package["identifier"],
      "repository_url" => get_in(json, ["repository", "url"]),
      "website_url" => json["websiteUrl"],
      "license" => meta[@meta_prefix <> "license"] || json["license"],
      "env_vars" => package |> env_vars(),
      "tags" => meta[@meta_prefix <> "tags"] || json["tags"] || [],
      "tools" => meta[@meta_prefix <> "tools"] || json["tools"] || []
    }
  end

  defp packages(%Server{package_registry: registry, package_identifier: identifier})
       when is_nil(registry) or is_nil(identifier),
       do: nil

  defp packages(%Server{} = server) do
    [
      %{
        "registryType" => server.package_registry,
        "identifier" => server.package_identifier,
        "version" => server.version,
        "transport" => %{"type" => "stdio"},
        "environmentVariables" =>
          Enum.map(server.env_vars, fn name ->
            %{"name" => name, "isRequired" => true, "isSecret" => secret?(name)}
          end)
      }
    ]
  end

  defp remotes(%Server{remote_url: nil}), do: nil

  defp remotes(%Server{} = server) do
    [%{"type" => remote_type(server.transport), "url" => server.remote_url}]
  end

  defp remote_type("sse"), do: "sse"
  defp remote_type(_), do: "streamable-http"

  defp normalize_transport("sse"), do: "sse"
  defp normalize_transport(_), do: "streamable-http"

  defp repository(nil), do: nil

  defp repository(url) do
    source = if String.contains?(url, "github.com"), do: "github", else: "other"
    %{"url" => url, "source" => source}
  end

  defp env_vars(nil), do: []

  defp env_vars(package) do
    package
    |> Map.get("environmentVariables", [])
    |> Enum.map(& &1["name"])
    |> Enum.reject(&is_nil/1)
  end

  defp secret?(name) do
    String.contains?(String.upcase(name), ["TOKEN", "KEY", "SECRET", "PASSWORD"])
  end

  defp first_map(list) when is_list(list), do: Enum.find(list, &is_map/1)
  defp first_map(_), do: nil

  defp default_title(nil), do: nil
  defp default_title(name), do: name |> Server.short_name() |> String.replace(["-", "_"], " ")

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
