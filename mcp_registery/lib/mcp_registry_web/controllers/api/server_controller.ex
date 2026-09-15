defmodule McpRegistryWeb.API.ServerController do
  use McpRegistryWeb, :controller
  import McpRegistryWeb.Routes

  alias McpRegistry.Registry
  alias McpRegistryWeb.Submissions

  action_fallback McpRegistryWeb.API.FallbackController

  @default_limit 30
  @max_limit 100

  def index(conn, params) do
    with {:ok, status} <- listing_status(conn, params["status"]) do
      limit = params["limit"] |> to_int(@default_limit) |> min(@max_limit) |> max(1)
      offset = params["offset"] |> to_int(0) |> max(0)

      opts = [
        q: params["q"] || params["search"],
        transport: params["transport"],
        tag: params["tag"],
        status: status,
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
  end

  def show(conn, %{"name" => segments}) do
    with {:ok, server} <- Registry.fetch_server(Enum.join(segments, "/")) do
      render(conn, :show, server: server)
    end
  end

  @doc """
  Anyone may submit. Without a token the listing is pending review (202);
  with the publish token it goes live at once (201).
  """
  def create(conn, params) do
    with {:ok, server} <- Submissions.submit(conn, params, "api") do
      conn
      |> put_status(if server.status == "active", do: :created, else: :accepted)
      |> put_resp_header("location", api_server_path(server))
      |> render(:show, server: server)
    end
  end

  @doc "Maintainer review of a pending listing. Requires the publish token."
  def review(conn, %{"name" => name, "decision" => decision})
      when is_binary(name) and decision in ["approve", "reject"] do
    with :ok <- Submissions.require_admin(conn) do
      case decision do
        "approve" ->
          with {:ok, server} <- Registry.approve_server(name) do
            render(conn, :show, server: server)
          end

        "reject" ->
          with {:ok, _server} <- Registry.reject_server(name) do
            send_resp(conn, :no_content, "")
          end
      end
    end
  end

  def review(_conn, _params), do: {:error, :bad_review}

  # Only maintainers may list anything other than active servers.
  defp listing_status(_conn, status) when status in [nil, "", "active"], do: {:ok, "active"}

  defp listing_status(conn, status) when status in ["pending", "deprecated"] do
    with :ok <- Submissions.require_admin(conn), do: {:ok, status}
  end

  defp listing_status(_conn, _status), do: {:error, :bad_status}

  defp to_int(nil, default), do: default

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp to_int(_, default), do: default
end
