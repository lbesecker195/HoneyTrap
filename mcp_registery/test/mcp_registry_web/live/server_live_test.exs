defmodule McpRegistryWeb.ServerLiveTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  test "index lists and searches servers", %{conn: conn} do
    weather = server_fixture(%{title: "Acme Weather"})

    notes =
      server_fixture(%{
        name: "io.github.acme/notes",
        title: "Acme Notes",
        description: "Keeps notes.",
        tags: ["notes"],
        tools: ["add_note"]
      })

    {:ok, view, html} = live(conn, ~p"/")
    assert html =~ weather.title
    assert html =~ notes.title
    assert html =~ "Seriously Simple Analytics"

    assert html =~
             "claude mcp add --transport http mcp-registry-search #{McpRegistryWeb.Endpoint.url()}/mcp"

    html = view |> element("form") |> render_change(%{q: "notes", transport: ""})
    assert html =~ notes.title
    refute html =~ weather.title
    assert_patch(view, ~p"/?q=notes")
  end

  test "show renders install snippets and the manifest", %{conn: conn} do
    server = server_fixture()
    {:ok, _view, html} = live(conn, "/servers/#{server.name}")

    assert html =~ "claude mcp add"
    assert html =~ "@acme/weather-mcp"
    assert html =~ "server.json manifest"
    assert html =~ "get_forecast"
  end

  test "pending listings are kept out of search engines", %{conn: conn} do
    active = server_fixture()
    pending = server_fixture(%{status: "pending"})

    refute conn |> get("/servers/#{active.name}") |> html_response(200) =~ ~s(content="noindex")
    html = conn |> get("/servers/#{pending.name}") |> html_response(200)
    assert html =~ ~s(<meta name="robots" content="noindex">)
    assert html =~ ~s(rel="nofollow ugc noopener")
  end

  test "index paginates large catalogues", %{conn: conn} do
    for i <- 1..50 do
      server_fixture(%{
        name: "com.example/bulk-#{String.pad_leading("#{i}", 2, "0")}",
        title: "Bulk #{String.pad_leading("#{i}", 2, "0")}"
      })
    end

    {:ok, view, html} = live(conn, ~p"/")
    assert html =~ "Showing 1–48 of 50 servers"
    assert html =~ "Bulk 48"
    refute html =~ "Bulk 49"

    html = view |> element("#pagination a[rel=next]") |> render_click()
    assert_patch(view, ~p"/?page=2")
    assert html =~ "Showing 49–50 of 50 servers"
    assert html =~ "Bulk 50"

    {:ok, _view, html} = live(conn, ~p"/?page=999")
    assert html =~ "Showing 49–50 of 50 servers"
  end

  test "imported listings credit the official registry", %{conn: conn} do
    server =
      server_fixture()
      |> Ecto.Changeset.change(origin: "official", synced_at: DateTime.utc_now())
      |> McpRegistry.Repo.update!()

    {:ok, _view, html} = live(conn, "/servers/#{server.name}")
    assert html =~ "official MCP Registry"
    assert html =~ "synced just now"
    assert html =~ McpRegistry.OfficialRegistry.server_url(server.name)
  end

  test "show 404s for unknown servers", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn -> live(conn, "/servers/io.github.nobody/nothing") end
  end

  test "submit form validates and creates a pending listing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/submit")

    html = view |> form("#server-form", server: %{name: "bad name"}) |> render_change()
    assert html =~ "must look like namespace/server-name"

    attrs = %{
      name: "io.github.acme/submitted",
      title: "Submitted",
      description: "Came in through the web form.",
      version: "0.1.0",
      transport: "stdio",
      package_registry: "npm",
      package_identifier: "@acme/submitted",
      tags: "forms, web",
      tools: "submit_thing"
    }

    {:ok, _show, html} =
      view
      |> form("#server-form", server: attrs)
      |> render_submit()
      |> follow_redirect(conn, "/servers/io.github.acme/submitted")

    assert html =~ "pending review"
    assert html =~ "submit_thing"

    assert {:ok, %{status: "pending", tags: ["forms", "web"]}} =
             McpRegistry.Registry.fetch_server("io.github.acme/submitted")
  end
end
