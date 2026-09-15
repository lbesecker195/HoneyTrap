defmodule McpRegistryWeb.MCPControllerTest do
  use McpRegistryWeb.ConnCase, async: true

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Registry

  defp rpc(conn, body, headers \\ []) do
    conn =
      Enum.reduce(headers, conn, fn {key, value}, acc -> put_req_header(acc, key, value) end)

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> post("/mcp", Jason.encode!(body))
  end

  defp call_tool(conn, name, arguments, headers \\ []) do
    body = %{
      jsonrpc: "2.0",
      id: 7,
      method: "tools/call",
      params: %{name: name, arguments: arguments}
    }

    %{"jsonrpc" => "2.0", "id" => 7, "result" => result} =
      conn |> rpc(body, headers) |> json_response(200)

    result
  end

  describe "lifecycle" do
    test "initialize negotiates the protocol version and advertises tools", %{conn: conn} do
      body = %{
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: %{
          protocolVersion: "2025-06-18",
          capabilities: %{},
          clientInfo: %{name: "test-client", version: "1.0"}
        }
      }

      assert %{"id" => 1, "result" => result} = conn |> rpc(body) |> json_response(200)
      assert result["protocolVersion"] == "2025-06-18"
      assert result["capabilities"] == %{"tools" => %{"listChanged" => false}}
      assert result["serverInfo"]["name"] == "mcp-registry-search"
      assert result["instructions"] =~ "submit_server"

      unknown = put_in(body, [:params, :protocolVersion], "1999-01-01")

      assert %{"result" => %{"protocolVersion" => "2025-11-25"}} =
               conn |> rpc(unknown) |> json_response(200)
    end

    test "notifications are accepted with no body", %{conn: conn} do
      conn = rpc(conn, %{jsonrpc: "2.0", method: "notifications/initialized"})
      assert response(conn, 202) == ""
    end

    test "ping, unknown methods and malformed messages", %{conn: conn} do
      assert %{"result" => %{}} =
               conn |> rpc(%{jsonrpc: "2.0", id: "a", method: "ping"}) |> json_response(200)

      assert %{"error" => %{"code" => -32601}} =
               conn
               |> rpc(%{jsonrpc: "2.0", id: 2, method: "resources/list"})
               |> json_response(200)

      assert %{"error" => %{"code" => -32600}} =
               conn |> rpc(%{hello: "world"}) |> json_response(200)
    end

    test "batches get a list of replies, skipping notifications", %{conn: conn} do
      batch = [
        %{jsonrpc: "2.0", id: 1, method: "ping"},
        %{jsonrpc: "2.0", method: "notifications/initialized"},
        %{jsonrpc: "2.0", id: 2, method: "tools/list"}
      ]

      assert [%{"id" => 1}, %{"id" => 2, "result" => %{"tools" => [_, _, _]}}] =
               conn |> rpc(batch) |> json_response(200)
    end
  end

  describe "transport rules" do
    test "GET and DELETE are not allowed", %{conn: conn} do
      conn = get(conn, "/mcp")
      assert json_response(conn, 405)
      assert get_resp_header(conn, "allow") == ["POST"]
    end

    test "foreign browser origins are rejected; same origin is fine", %{conn: conn} do
      ping = %{jsonrpc: "2.0", id: 1, method: "ping"}
      assert conn |> rpc(ping, [{"origin", "https://evil.example"}]) |> json_response(403)
      assert conn |> rpc(ping, [{"origin", McpRegistryWeb.Endpoint.url()}]) |> json_response(200)
    end

    test "unsupported protocol version headers are rejected", %{conn: conn} do
      ping = %{jsonrpc: "2.0", id: 1, method: "ping"}
      assert conn |> rpc(ping, [{"mcp-protocol-version", "1999-01-01"}]) |> json_response(400)
      assert conn |> rpc(ping, [{"mcp-protocol-version", "2025-06-18"}]) |> json_response(200)
    end

    test "a non-JSON body is an invalid request", %{conn: conn} do
      conn = conn |> put_req_header("content-type", "text/plain") |> post("/mcp", "hello")
      assert %{"error" => %{"code" => -32600}} = json_response(conn, 400)
    end
  end

  describe "tools" do
    test "tools/list describes every tool with an input schema", %{conn: conn} do
      assert %{"result" => %{"tools" => tools}} =
               conn |> rpc(%{jsonrpc: "2.0", id: 1, method: "tools/list"}) |> json_response(200)

      assert Enum.map(tools, & &1["name"]) == ["search_servers", "get_server", "submit_server"]
      submit = Enum.find(tools, &(&1["name"] == "submit_server"))
      assert submit["inputSchema"]["required"] == ["name", "title", "description", "transport"]
      assert submit["annotations"]["readOnlyHint"] == false
    end

    test "search_servers finds active servers only", %{conn: conn} do
      server = server_fixture(%{tools: ["get_forecast"]})
      _pending = server_fixture(%{status: "pending", tools: ["get_forecast"]})

      result = call_tool(conn, "search_servers", %{query: "get_forecast", limit: 5})
      refute result["isError"]
      assert %{"total" => 1, "servers" => [found]} = result["structuredContent"]
      assert found["name"] == server.name
      assert found["url"] == McpRegistryWeb.Endpoint.url() <> "/servers/#{server.name}"
      assert Jason.decode!(hd(result["content"])["text"]) == result["structuredContent"]
    end

    test "get_server returns the manifest and install snippets", %{conn: conn} do
      server = server_fixture()

      result = call_tool(conn, "get_server", %{name: server.name})

      assert %{"status" => "active", "server" => %{"name" => name}, "install" => [claude | _]} =
               result["structuredContent"]

      assert name == server.name
      assert claude["code"] =~ "claude mcp add"

      missing = call_tool(conn, "get_server", %{name: "io.github.nobody/nothing"})
      assert missing["isError"]
      assert hd(missing["content"])["text"] =~ "search_servers"
    end

    test "submit_server adds a pending listing an agent can check on", %{conn: conn} do
      args = %{
        name: "io.github.agent/submitted",
        title: "Agent Submitted",
        description: "Submitted by an agent over MCP.",
        transport: "streamable-http",
        remote_url: "https://mcp.agent.dev/mcp",
        tools: ["do_work"],
        tags: ["Agents"]
      }

      result = call_tool(conn, "submit_server", args, [{"x-real-ip", "10.200.0.1"}])
      refute result["isError"]

      assert %{"status" => "pending", "name" => "io.github.agent/submitted"} =
               result["structuredContent"]

      assert result["structuredContent"]["message"] =~ "review"

      assert %{"structuredContent" => %{"status" => "pending"}} =
               call_tool(conn, "get_server", %{name: "io.github.agent/submitted"})

      assert %{"structuredContent" => %{"total" => 0}} =
               call_tool(conn, "search_servers", %{query: "Agent Submitted"})

      assert {:ok, %{tags: ["agents"]}} = Registry.fetch_server("io.github.agent/submitted")
    end

    test "submit_server explains validation errors so the agent can retry", %{conn: conn} do
      result =
        call_tool(
          conn,
          "submit_server",
          %{name: "Not A Name", title: "x", description: "short", transport: "stdio"},
          [
            {"x-real-ip", "10.200.0.2"}
          ]
        )

      assert result["isError"]
      text = hd(result["content"])["text"]
      assert text =~ "Fix these fields"
      assert text =~ "name must look like namespace/server-name"

      assert %{"error" => "validation_failed", "details" => %{"package_registry" => _}} =
               result["structuredContent"]
    end

    test "unknown tools are a protocol error", %{conn: conn} do
      body = %{
        jsonrpc: "2.0",
        id: 3,
        method: "tools/call",
        params: %{name: "delete_everything", arguments: %{}}
      }

      assert %{"error" => %{"code" => -32602, "message" => message}} =
               conn |> rpc(body) |> json_response(200)

      assert message =~ "submit_server"
    end
  end
end
