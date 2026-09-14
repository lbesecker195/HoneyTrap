defmodule McpRegistryWeb.API.ServerControllerTest do
  # Not async: these tests toggle the application-level publish token.
  use McpRegistryWeb.ConnCase, async: false

  import McpRegistry.RegistryFixtures

  setup do
    Application.put_env(:mcp_registry, :registry, publish_token: "test-token")
    on_exit(fn -> Application.put_env(:mcp_registry, :registry, publish_token: nil) end)
    :ok
  end

  test "GET /api/v0/servers lists active servers with metadata", %{conn: conn} do
    server = server_fixture()
    _pending = server_fixture(%{status: "pending"})

    body = conn |> get(~p"/api/v0/servers", q: server.title) |> json_response(200)

    assert [
             %{
               "server" => %{"name" => name},
               "_meta" => %{"io.mcpregistry/official" => %{"status" => "active"}}
             }
           ] = body["servers"]

    assert name == server.name
    assert %{"count" => 1, "total" => 1, "next_offset" => nil} = body["metadata"]
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

  test "POST /api/v0/servers publishes a server.json manifest with a token", %{conn: conn} do
    manifest = %{
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

    conn = put_req_header(conn, "authorization", "Bearer test-token")
    body = conn |> post(~p"/api/v0/servers", manifest) |> json_response(201)

    assert body["server"]["name"] == "io.github.acme/published"
    assert body["server"]["title"] == "published"
    assert body["_meta"]["io.mcpregistry/official"]["status"] == "active"

    assert [%{"environmentVariables" => [%{"name" => "ACME_TOKEN", "isSecret" => true}]}] =
             body["server"]["packages"]
  end

  test "POST /api/v0/servers validates and authorises", %{conn: conn} do
    assert %{"error" => %{"code" => "unauthorized"}} =
             conn |> post(~p"/api/v0/servers", %{}) |> json_response(401)

    conn = put_req_header(conn, "authorization", "Bearer test-token")
    body = conn |> post(~p"/api/v0/servers", %{"name" => "bad"}) |> json_response(422)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"name" => [_], "description" => [_]}
             }
           } = body

    Application.put_env(:mcp_registry, :registry, publish_token: nil)

    assert %{"error" => %{"code" => "publishing_disabled"}} =
             conn |> post(~p"/api/v0/servers", %{}) |> json_response(403)
  end

  test "GET /llms.txt describes the API and carries the analytics block", %{conn: conn} do
    body = conn |> get(~p"/llms.txt") |> text_response(200)
    assert body =~ "/api/v0/servers?q="
    assert body =~ "## Analytics"
    assert body =~ "seriouslysimpleanalytics.com/wa.js"
  end
end
