defmodule McpRegistryWeb.API.ServerController do
  use McpRegistryWeb, :controller
  import McpRegistryWeb.Routes

  alias McpRegistry.Registry
  alias McpRegistry.Registry.Manifest

  action_fallback McpRegistryWeb.API.FallbackController

  @default_limit 30
  @max_limit 100

  def index(conn, params) do
    limit = params["limit"] |> to_int(@default_limit) |> min(@max_limit) |> max(1)
    offset = params["offset"] |> to_int(0) |> max(0)

    opts = [
      q: params["q"] || params["search"],
      transport: params["transport"],
      tag: params["tag"],
      limit: limit,
      offset: offset
    ]

    render(conn, :index,
      servers: Registry.list_servers(opts),
      total: Registry.count_servers(opts),
      limit: limit,
      offset: offset
    )
  end

  def show(conn, %{"name" => segments}) do
    with {:ok, server} <- Registry.fetch_server(Enum.join(segments, "/")) do
      render(conn, :show, server: server)
    end
  end

  def create(conn, params) do
    with :ok <- authorize(conn),
         {:ok, server} <-
           Registry.create_server(attrs_from(params), status: "active", source: "api") do
      conn
      |> put_status(:created)
      |> put_resp_header("location", api_server_path(server))
      |> render(:show, server: server)
    end
  end

  # Accept either a server.json manifest or this registry's flat field names.
  defp attrs_from(params) do
    params = Map.drop(params, ["status"])

    if Enum.any?(["packages", "remotes", "$schema"], &Map.has_key?(params, &1)),
      do: Manifest.from_map(params),
      else: params
  end

  defp authorize(conn) do
    case Application.get_env(:mcp_registry, :registry, [])[:publish_token] do
      token when token in [nil, ""] ->
        {:error, :publishing_disabled}

      token ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> given] ->
            if Plug.Crypto.secure_compare(given, token), do: :ok, else: {:error, :unauthorized}

          _ ->
            {:error, :unauthorized}
        end
    end
  end

  defp to_int(nil, default), do: default

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp to_int(_, default), do: default
end
