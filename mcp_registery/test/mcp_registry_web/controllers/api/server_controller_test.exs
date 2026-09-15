defmodule McpRegistryWeb.API.ServerControllerTest do
  # Not async: these tests change application config (publish token, limits).
  use McpRegistryWeb.ConnCase, async: false

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Registry

  @manifest %{
    "name" => "io.github.acme/published",
    "description" => "Published straight from a manifest.",
    "version" => "2.0.0",
    "packages" => [
      %{
        "registryType" => "pypi",
        "identifier" => "acme-published",
        "environmentVariables" => [%{"name" => "ACME_TOKEN"}]
      }
    ],
    "_meta" => %{"io.mcpregistry/tools" => ["do_thing"]}
  }

  setup do
    registry = Application.get_env(:mcp_registry, :registry)
    submissions = Application.get_env(:mcp_registry, :submissions)
    Application.put_env(:mcp_registry, :registry, publish_token: "test-token")

    on_exit(fn ->
      Application.put_env(:mcp_registry, :registry, registry)
      Application.put_env(:mcp_registry, :submissions, submissions)
    end)

    :ok
  end

  defp admin(conn), do: put_req_header(conn, "authorization", "Bearer test-token")

  # Each test submits from its own address so rate limits never collide.
  defp from_client(conn) do
    n = System.unique_integer([:positive])

    put_req_header(
      conn,
      "x-real-ip",
      "10.#{rem(div(n, 65_536), 256)}.#{rem(div(n, 256), 256)}.#{rem(n, 256)}"
    )
  end

  test "GET /api/v0/servers lists active servers with metadata", %{conn: conn} do
    server = server_fixture()
    _pending = server_fixture(%{status: "pending"})

    body = conn |> get(~p"/api/v0/servers", q: server.title) |> json_response(200)

    assert [
             %{
               "server" => %{"name" => name},
               "_meta" => %{
                 "io.mcpregistry/official" => %{"status" => "active", "origin" => "local"}
               }
             }
           ] = body["servers"]

    assert name == server.name
    assert %{"count" => 1, "total" => 1, "next_offset" => nil} = body["metadata"]
  end

  test "GET /api/v0/servers?status=pending is for maintainers only", %{conn: conn} do
    pending = server_fixture(%{status: "pending"})

    assert %{"error" => %{"code" => "unauthorized"}} =
             conn |> get(~p"/api/v0/servers", status: "pending") |> json_response(401)

    body = conn |> admin() |> get(~p"/api/v0/servers", status: "pending") |> json_response(200)
    assert pending.name in Enum.map(body["servers"], & &1["server"]["name"])

    assert %{"error" => %{"code" => "bad_request"}} =
             conn |> get(~p"/api/v0/servers", status: "bogus") |> json_response(400)
  end

  test "GET /api/v0/servers/:name accepts raw and encoded slashes", %{conn: conn} do
    server = server_fixture()

    assert %{"server" => %{"name" => name}} =
             conn |> get("/api/v0/servers/#{server.name}") |> json_response(200)

    assert name == server.name

    encoded = URI.encode_www_form(server.name)

    assert %{"server" => %{"name" => ^name}} =
             conn |> get("/api/v0/servers/#{encoded}") |> json_response(200)

    assert %{"error" => %{"code" => "not_found"}} =
             conn |> get("/api/v0/servers/io.github.nobody/nothing") |> json_response(404)
  end

  test "anyone can submit without a token; the listing waits for review", %{conn: conn} do
    conn = conn |> from_client() |> post(~p"/api/v0/servers", @manifest)
    body = json_response(conn, 202)

    assert body["server"]["name"] == "io.github.acme/published"
    assert body["_meta"]["io.mcpregistry/official"]["status"] == "pending"
    assert get_resp_header(conn, "location") == ["/api/v0/servers/io.github.acme/published"]
    assert Registry.list_servers(q: "published") == []
  end

  test "flat field submissions work too, and a submitted status is ignored", %{conn: conn} do
    attrs = %{
      "name" => "io.github.acme/flat",
      "title" => "Flat",
      "description" => "Submitted with flat fields.",
      "transport" => "streamable-http",
      "remote_url" => "https://mcp.acme.dev/mcp",
      "tools" => ["one", "two"],
      "status" => "active"
    }

    body = conn |> from_client() |> post(~p"/api/v0/servers", attrs) |> json_response(202)
    assert body["_meta"]["io.mcpregistry/official"]["status"] == "pending"
    assert [%{"type" => "streamable-http"}] = body["server"]["remotes"]
  end

  test "the publish token publishes immediately", %{conn: conn} do
    body = conn |> admin() |> post(~p"/api/v0/servers", @manifest) |> json_response(201)

    assert body["server"]["title"] == "published"
    assert body["_meta"]["io.mcpregistry/official"]["status"] == "active"

    assert [%{"environmentVariables" => [%{"name" => "ACME_TOKEN", "isSecret" => true}]}] =
             body["server"]["packages"]
  end

  test "invalid submissions explain what to fix", %{conn: conn} do
    body =
      conn |> from_client() |> post(~p"/api/v0/servers", %{"name" => "bad"}) |> json_response(422)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"name" => [_], "description" => [_]}
             }
           } = body
  end

  test "a wrong Authorization header is refused, not downgraded", %{conn: conn} do
    conn = put_req_header(conn, "authorization", "Bearer nope")

    assert %{"error" => %{"code" => "unauthorized"}} =
             conn |> post(~p"/api/v0/servers", @manifest) |> json_response(401)

    Application.put_env(:mcp_registry, :registry, publish_token: nil)

    assert %{"error" => %{"code" => "unauthorized"}} =
             conn |> post(~p"/api/v0/servers", @manifest) |> json_response(401)
  end

  test "each client is rate limited", %{conn: conn} do
    Application.put_env(:mcp_registry, :submissions, per_client_per_hour: 2, max_pending: 100)
    client = from_client(conn)

    for i <- 1..2 do
      attrs = Map.put(@manifest, "name", "io.github.acme/limited-#{i}")
      assert client |> post(~p"/api/v0/servers", attrs) |> json_response(202)
    end

    limited =
      post(client, ~p"/api/v0/servers", Map.put(@manifest, "name", "io.github.acme/limited-3"))

    assert %{"error" => %{"code" => "rate_limited"}} = json_response(limited, 429)
    assert [retry_after] = get_resp_header(limited, "retry-after")
    assert String.to_integer(retry_after) in 1..3600

    # Another client, and the maintainer, are unaffected.
    assert conn
           |> from_client()
           |> post(~p"/api/v0/servers", Map.put(@manifest, "name", "io.github.acme/other"))
           |> json_response(202)

    assert client
           |> admin()
           |> post(~p"/api/v0/servers", Map.put(@manifest, "name", "io.github.acme/admin"))
           |> json_response(201)
  end

  test "the review queue is capped", %{conn: conn} do
    Application.put_env(:mcp_registry, :submissions, per_client_per_hour: 100, max_pending: 1)
    _already_waiting = server_fixture(%{status: "pending"})

    assert %{"error" => %{"code" => "queue_full"}} =
             conn |> from_client() |> post(~p"/api/v0/servers", @manifest) |> json_response(503)
  end

  test "maintainers approve or reject pending listings", %{conn: conn} do
    approve = server_fixture(%{status: "pending"})
    reject = server_fixture(%{status: "pending"})

    assert %{"error" => %{"code" => "unauthorized"}} =
             conn
             |> post(~p"/api/v0/review", %{name: approve.name, decision: "approve"})
             |> json_response(401)

    assert %{"_meta" => %{"io.mcpregistry/official" => %{"status" => "active"}}} =
             conn
             |> admin()
             |> post(~p"/api/v0/review", %{name: approve.name, decision: "approve"})
             |> json_response(200)

    assert conn
           |> admin()
           |> post(~p"/api/v0/review", %{name: reject.name, decision: "reject"})
           |> response(204)

    assert {:error, :not_found} = Registry.fetch_server(reject.name)

    assert %{"error" => %{"code" => "not_pending"}} =
             conn
             |> admin()
             |> post(~p"/api/v0/review", %{name: approve.name, decision: "reject"})
             |> json_response(409)

    assert %{"error" => %{"code" => "bad_request"}} =
             conn
             |> admin()
             |> post(~p"/api/v0/review", %{name: approve.name})
             |> json_response(400)
  end

  test "GET /llms.txt tells agents how to connect and submit", %{conn: conn} do
    body = conn |> get(~p"/llms.txt") |> text_response(200)
    assert body =~ "/mcp"
    assert body =~ "submit_server"
    assert body =~ "POST #{McpRegistryWeb.Endpoint.url()}/api/v0/servers"
    assert body =~ "## Analytics"
    assert body =~ "seriouslysimpleanalytics.com/wa.js"
  end
end
