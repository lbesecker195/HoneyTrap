defmodule McpRegistryWeb.MCP.Server do
  @moduledoc """
  A stateless Model Context Protocol server over Streamable HTTP.

  Each POST carries one JSON-RPC message (or, for 2025-03-26 clients, a
  batch). Requests get a JSON response; notifications and client responses get
  202 Accepted. No sessions are kept and no server-to-client stream is opened.
  """
  alias McpRegistry.Analytics
  alias McpRegistryWeb.MCP.Tools

  @protocol_versions ["2025-11-25", "2025-06-18", "2025-03-26"]

  def protocol_versions, do: @protocol_versions

  @doc "Handles one decoded JSON-RPC message. Returns `{:reply, map}` or `:noreply`."
  def handle(%{"jsonrpc" => "2.0", "method" => method, "id" => id} = message, conn)
      when is_binary(method) and (is_binary(id) or is_integer(id)) do
    params = if is_map(message["params"]), do: message["params"], else: %{}
    {:reply, request(method, params, id, conn)}
  end

  # Notifications, e.g. notifications/initialized: nothing to answer.
  def handle(%{"jsonrpc" => "2.0", "method" => method} = message, _conn)
      when is_binary(method) and not is_map_key(message, "id"),
      do: :noreply

  # Responses to server-initiated requests. This server never sends any.
  def handle(%{"jsonrpc" => "2.0", "id" => _} = message, _conn)
      when is_map_key(message, "result") or is_map_key(message, "error"),
      do: :noreply

  def handle(message, _conn) do
    id = if is_map(message) and not is_struct(message), do: Map.get(message, "id")
    {:reply, error(id, -32600, "Invalid Request: expected a JSON-RPC 2.0 message")}
  end

  def error(id, code, message),
    do: %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}

  defp request("initialize", params, id, _conn) do
    requested = params["protocolVersion"]
    version = if requested in @protocol_versions, do: requested, else: hd(@protocol_versions)

    result(id, %{
      protocolVersion: version,
      capabilities: %{tools: %{listChanged: false}},
      serverInfo: %{
        name: "mcp-registry-search",
        title: "MCP Registry Search",
        version: to_string(Application.spec(:mcp_registry, :vsn))
      },
      instructions:
        "A registry of MCP servers at #{McpRegistryWeb.Endpoint.url()}. " <>
          "Use search_servers to find servers and get_server for install details. " <>
          "To add a server, first confirm with search_servers that it is not listed, then call submit_server. " <>
          "New submissions are reviewed before they appear in search."
    })
  end

  defp request("ping", _params, id, _conn), do: result(id, %{})

  defp request("tools/list", _params, id, _conn), do: result(id, %{tools: Tools.definitions()})

  defp request("tools/call", %{"name" => name} = params, id, conn) when is_binary(name) do
    arguments = if is_map(params["arguments"]), do: params["arguments"], else: %{}
    started = System.monotonic_time()

    case Tools.call(name, arguments, conn) do
      {:ok, tool_result} ->
        Analytics.track(:tool_called, %{
          tool: name,
          channel: "mcp",
          outcome: if(tool_result.isError, do: "error", else: "success"),
          latency_ms:
            System.convert_time_unit(System.monotonic_time() - started, :native, :millisecond),
          name: Analytics.client_name(conn)
        })

        result(id, tool_result)

      {:error, :unknown_tool} ->
        error(
          id,
          -32602,
          "Unknown tool: #{name}. Available tools: #{Enum.join(Tools.names(), ", ")}"
        )
    end
  end

  defp request("tools/call", _params, id, _conn),
    do: error(id, -32602, "Invalid params: tools/call needs a tool name")

  defp request(method, _params, id, _conn), do: error(id, -32601, "Method not found: #{method}")

  defp result(id, result), do: %{jsonrpc: "2.0", id: id, result: result}
end
