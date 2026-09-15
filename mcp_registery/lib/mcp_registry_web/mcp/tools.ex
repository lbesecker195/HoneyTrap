defmodule McpRegistryWeb.MCP.Tools do
  @moduledoc """
  The tools the registry offers over MCP: find servers, read one, and add one.
  Descriptions are written for the model that calls them.
  """
  import McpRegistryWeb.Routes

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Install, Manifest, Server}
  alias McpRegistryWeb.Submissions

  @search_limit 50

  def definitions do
    [
      %{
        name: "search_servers",
        title: "Search MCP servers",
        description:
          "Search the registry for MCP servers. Matches names, titles, descriptions, tags and the names of the tools each server exposes. " <>
            "Returns short summaries; call get_server for install instructions. Search before submit_server so you don't add a duplicate.",
        inputSchema: %{
          type: "object",
          properties: %{
            query: %{
              type: "string",
              description:
                ~s(Free text, e.g. "github issues", or a tool name such as "get_forecast". Omit to list everything.)
            },
            transport: %{
              type: "string",
              enum: Server.transports(),
              description: "Only servers with this transport."
            },
            tag: %{type: "string", description: "Only servers with this tag, e.g. search."},
            limit: %{type: "integer", minimum: 1, maximum: @search_limit, default: 10},
            offset: %{type: "integer", minimum: 0, default: 0}
          },
          additionalProperties: false
        },
        annotations: %{readOnlyHint: true, openWorldHint: false}
      },
      %{
        name: "get_server",
        title: "Get an MCP server",
        description:
          "Get one server by its exact name: its server.json manifest, its review status, and ready-to-use install snippets. " <>
            "Use it to check on a server you submitted; status is pending until a maintainer approves it.",
        inputSchema: %{
          type: "object",
          properties: %{
            name: %{
              type: "string",
              description: "Exact server name, e.g. io.github.acme/weather-mcp."
            }
          },
          required: ["name"],
          additionalProperties: false
        },
        annotations: %{readOnlyHint: true, openWorldHint: false}
      },
      %{
        name: "submit_server",
        title: "Submit an MCP server",
        description:
          "Add an MCP server to the registry. New submissions are reviewed by a maintainer before they appear in search; get_server shows their status meanwhile. " <>
            "Fill in what you know from the server's README or package metadata. If the result is an error, fix the fields it names and call again. " <>
            "Never include secrets: env_vars takes variable names only, not values.",
        inputSchema: %{
          type: "object",
          properties: %{
            name: %{
              type: "string",
              description:
                "Unique name: a reverse-DNS namespace you can vouch for, a slash, and a short name. For a GitHub project use io.github.<owner>/<repo>, e.g. io.github.acme/weather-mcp. Lowercase letters, digits, dots, hyphens and underscores."
            },
            title: %{
              type: "string",
              maxLength: 120,
              description: "Human-readable name, e.g. Weather."
            },
            description: %{
              type: "string",
              minLength: 10,
              maxLength: 1000,
              description:
                "What the server does and anything it needs to run, in one or two sentences."
            },
            version: %{
              type: "string",
              description: "Current version, e.g. 1.2.0. Defaults to 0.1.0."
            },
            transport: %{
              type: "string",
              enum: Server.transports(),
              description:
                "stdio for a server run locally from a package; streamable-http for a hosted server reached by URL; sse only for older hosted servers."
            },
            remote_url: %{
              type: "string",
              description: "Required for streamable-http and sse: the URL clients connect to."
            },
            package_registry: %{
              type: "string",
              enum: Server.registries(),
              description: "Required for stdio: where the package is published."
            },
            package_identifier: %{
              type: "string",
              description:
                "Required for stdio: the package name or image, e.g. @acme/weather-mcp or ghcr.io/acme/weather-mcp."
            },
            env_vars: %{
              type: "array",
              items: %{type: "string"},
              description:
                "Names of environment variables the server needs, e.g. WEATHER_API_KEY. Names only."
            },
            tools: %{
              type: "array",
              items: %{type: "string"},
              description: "Names of the tools the server exposes."
            },
            tags: %{
              type: "array",
              items: %{type: "string"},
              maxItems: 12,
              description: "Lowercase topic tags, e.g. weather, data."
            },
            repository_url: %{type: "string", description: "Source repository URL."},
            website_url: %{type: "string", description: "Documentation or home page URL."},
            license: %{type: "string", description: "SPDX license identifier, e.g. MIT."}
          },
          required: ["name", "title", "description", "transport"],
          additionalProperties: false
        },
        annotations: %{
          readOnlyHint: false,
          destructiveHint: false,
          idempotentHint: false,
          openWorldHint: false
        }
      }
    ]
  end

  def names, do: Enum.map(definitions(), & &1.name)

  @doc "Runs a tool. Returns `{:ok, call_tool_result}` or `{:error, :unknown_tool}`."
  def call(name, arguments, %Plug.Conn{} = conn) when is_map(arguments) do
    case name do
      "search_servers" -> {:ok, search(arguments)}
      "get_server" -> {:ok, get(arguments)}
      "submit_server" -> {:ok, submit(arguments, conn)}
      _ -> {:error, :unknown_tool}
    end
  end

  defp search(args) do
    limit = args |> int("limit", 10) |> min(@search_limit) |> max(1)
    offset = args |> int("offset", 0) |> max(0)
    opts = [q: str(args, "query"), transport: str(args, "transport"), tag: str(args, "tag")]
    servers = Registry.list_servers(opts ++ [limit: limit, offset: offset])
    total = Registry.count_servers(opts)

    ok(%{
      total: total,
      next_offset: if(offset + limit < total, do: offset + limit),
      servers:
        Enum.map(servers, fn server ->
          %{
            name: server.name,
            title: server.title,
            description: server.description,
            transport: server.transport,
            origin: server.origin,
            tags: server.tags,
            tools: server.tools,
            url: page_url(server)
          }
        end)
    })
  end

  defp get(args) do
    with name when is_binary(name) <- str(args, "name"),
         {:ok, server} <- Registry.fetch_server(name) do
      ok(%{
        status: server.status,
        origin: server.origin,
        url: page_url(server),
        server: Manifest.to_map(server),
        install: Enum.map(Install.snippets(server), &Map.take(&1, [:label, :code]))
      })
    else
      _ ->
        tool_error(
          "No server is named #{inspect(args["name"])}. Use search_servers to find the exact name."
        )
    end
  end

  defp submit(args, conn) do
    case Submissions.submit(conn, args, "mcp") do
      {:ok, server} ->
        message =
          if server.status == "active",
            do: "Published #{server.name}. It is live in search now.",
            else:
              "Submitted #{server.name} for review. It will appear in search once a maintainer approves it; call get_server to check its status."

        ok(%{status: server.status, name: server.name, url: page_url(server), message: message})

      {:error, %Ecto.Changeset{} = changeset} ->
        details = Submissions.error_details(changeset)

        fixes =
          Enum.map_join(details, "; ", fn {field, messages} ->
            "#{field} #{Enum.join(messages, ", ")}"
          end)

        tool_error(
          "The submission was not accepted. Fix these fields and call submit_server again: #{fixes}.",
          %{error: "validation_failed", details: details}
        )

      {:error, {:rate_limited, retry_after}} ->
        tool_error(
          "Too many submissions from this client. Try again in about #{div(retry_after + 59, 60)} minutes.",
          %{error: "rate_limited", retry_after_seconds: retry_after}
        )

      {:error, :queue_full} ->
        tool_error("The review queue is full right now. Try again later.", %{error: "queue_full"})

      {:error, :unauthorized} ->
        tool_error(
          "The Authorization header was not accepted. Remove it to submit the server for review.",
          %{error: "unauthorized"}
        )
    end
  end

  defp ok(data) do
    %{
      content: [%{type: "text", text: Jason.encode!(data)}],
      structuredContent: data,
      isError: false
    }
  end

  defp tool_error(message, data \\ %{}) do
    %{
      content: [%{type: "text", text: message}],
      structuredContent: Map.put(data, :message, message),
      isError: true
    }
  end

  defp page_url(server), do: McpRegistryWeb.Endpoint.url() <> server_path(server)

  defp str(args, key) do
    case args[key] do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp int(args, key, default) do
    case args[key] do
      value when is_integer(value) -> value
      _ -> default
    end
  end
end
