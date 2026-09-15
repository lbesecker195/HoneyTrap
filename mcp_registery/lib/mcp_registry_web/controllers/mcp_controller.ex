defmodule McpRegistryWeb.MCPController do
  @moduledoc "HTTP side of the MCP endpoint at /mcp (Streamable HTTP, stateless)."
  use McpRegistryWeb, :controller

  alias McpRegistryWeb.MCP.Server

  def post(conn, _params) do
    with :ok <- check_origin(conn),
         :ok <- check_protocol_version(conn) do
      case conn.body_params do
        %Plug.Conn.Unfetched{} ->
          invalid(
            conn,
            "Send a JSON-RPC 2.0 message as the body, with Content-Type: application/json"
          )

        %{"_json" => messages} when is_list(messages) and messages != [] ->
          messages
          |> Enum.map(&Server.handle(&1, conn))
          |> Enum.flat_map(fn
            {:reply, body} -> [body]
            :noreply -> []
          end)
          |> case do
            [] -> accepted(conn)
            replies -> json(conn, replies)
          end

        %{"_json" => _} ->
          invalid(conn, "Invalid Request: expected a JSON-RPC 2.0 object")

        message when is_map(message) and map_size(message) > 0 ->
          case Server.handle(message, conn) do
            {:reply, body} -> json(conn, body)
            :noreply -> accepted(conn)
          end

        _ ->
          invalid(
            conn,
            "Send a JSON-RPC 2.0 message as the body, with Content-Type: application/json"
          )
      end
    else
      {:error, status, message} ->
        conn |> put_status(status) |> json(Server.error(nil, -32600, message))
    end
  end

  # No server-to-client stream and no sessions to end.
  def method_not_allowed(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> put_status(:method_not_allowed)
    |> json(Server.error(nil, -32600, "This MCP endpoint only accepts POST"))
  end

  # The MCP spec requires validating Origin to stop DNS rebinding attacks.
  # Non-browser clients send no Origin and are allowed.
  defp check_origin(conn) do
    case get_req_header(conn, "origin") do
      [] ->
        :ok

      [origin | _] ->
        if URI.parse(origin).host == McpRegistryWeb.Endpoint.config(:url)[:host],
          do: :ok,
          else: {:error, 403, "Origin not allowed"}
    end
  end

  defp check_protocol_version(conn) do
    case get_req_header(conn, "mcp-protocol-version") do
      [] ->
        :ok

      [version | _] ->
        if version in Server.protocol_versions(),
          do: :ok,
          else: {:error, 400, "Unsupported MCP-Protocol-Version: #{version}"}
    end
  end

  defp accepted(conn), do: send_resp(conn, :accepted, "")

  defp invalid(conn, message) do
    conn |> put_status(:bad_request) |> json(Server.error(nil, -32600, message))
  end
end
