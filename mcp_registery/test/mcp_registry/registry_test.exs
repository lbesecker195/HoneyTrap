defmodule McpRegistry.RegistryTest do
  use McpRegistry.DataCase, async: true

  import McpRegistry.RegistryFixtures

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Install, Manifest, Server}

  describe "create_server/2" do
    test "stores a valid stdio listing and normalises lists" do
      attrs =
        valid_server_attrs(%{name: "  IO.GitHub.Acme/Weather ", tags: "Weather, data,, weather"})

      assert {:ok, %Server{} = server} = Registry.create_server(attrs, status: "active")
      assert server.name == "io.github.acme/weather"
      assert server.tags == ["weather", "data"]
      assert server.status == "active"
    end

    test "defaults to pending and ignores a submitted status" do
      assert {:ok, server} = Registry.create_server(valid_server_attrs(%{status: "active"}))
      assert server.status == "pending"
    end

    test "requires a package for stdio and a URL for remote transports" do
      assert {:error, changeset} =
               Registry.create_server(
                 valid_server_attrs(%{package_registry: nil, package_identifier: nil})
               )

      assert %{package_registry: [_], package_identifier: [_]} = errors_on(changeset)

      assert {:error, changeset} =
               Registry.create_server(
                 valid_server_attrs(%{transport: "sse", remote_url: "not a url"})
               )

      assert %{remote_url: ["must be an http(s) URL"]} = errors_on(changeset)
    end

    test "rejects malformed names and duplicates" do
      assert {:error, changeset} = Registry.create_server(valid_server_attrs(%{name: "weather"}))
      assert %{name: [_]} = errors_on(changeset)

      server = server_fixture()

      assert {:error, changeset} =
               Registry.create_server(valid_server_attrs(%{name: server.name}))

      assert %{name: ["is already published"]} = errors_on(changeset)
    end
  end

  describe "list_servers/1" do
    test "searches name, description, tags and tools, and hides pending listings" do
      weather = server_fixture(%{tags: ["weather"], tools: ["get_forecast"]})
      _pending = server_fixture(%{title: "Weather pending", status: "pending"})

      other =
        server_fixture(%{
          name: "io.github.acme/notes",
          title: "Notes",
          description: "Keeps notes.",
          tags: ["notes"],
          tools: ["add_note"]
        })

      names = fn opts -> opts |> Registry.list_servers() |> Enum.map(& &1.name) end

      assert names.(q: "forecast") == [weather.name]
      assert names.(tag: "notes") == [other.name]
      assert names.(q: "%") == []
      assert weather.name in names.([]) and other.name in names.([])
      refute Enum.any?(names.([]), &String.contains?(&1, "pending"))
    end

    test "curated listings come first, then the most recently updated imports" do
      imported = fn name, title, updated ->
        server_fixture(%{name: name, title: title})
        |> Ecto.Changeset.change(origin: "official", source_updated_at: updated)
        |> McpRegistry.Repo.update!()
      end

      older = imported.("com.example/older", "Aaa older", ~U[2026-01-01 00:00:00.000000Z])
      newer = imported.("com.example/newer", "Zzz newer", ~U[2026-09-01 00:00:00.000000Z])
      curated = server_fixture(%{name: "io.github.acme/curated", title: "Mmm curated"})

      names = Registry.list_servers(limit: 100) |> Enum.map(& &1.name)

      assert Enum.filter(names, &(&1 in [older.name, newer.name, curated.name])) ==
               [curated.name, newer.name, older.name]
    end

    test "approve_server/1 makes a pending listing visible" do
      pending = server_fixture(%{status: "pending"})
      assert Registry.list_servers(q: pending.name) == []
      assert {:ok, %Server{status: "active"}} = Registry.approve_server(pending.name)
      assert [%Server{name: name}] = Registry.list_servers(q: pending.name)
      assert name == pending.name
    end
  end

  describe "Manifest" do
    test "round-trips a listing through server.json" do
      server =
        server_fixture(%{transport: "streamable-http", remote_url: "https://mcp.acme.dev/mcp"})

      json = server |> Manifest.to_map() |> Jason.encode!() |> Jason.decode!()

      assert json["name"] == server.name
      assert [%{"registryType" => "npm", "identifier" => "@acme/weather-mcp"}] = json["packages"]

      assert [%{"type" => "streamable-http", "url" => "https://mcp.acme.dev/mcp"}] =
               json["remotes"]

      assert json["_meta"]["io.mcpregistry/tools"] == ["get_forecast", "get_alerts"]

      attrs = Manifest.from_map(json)
      assert attrs["transport"] == "streamable-http"
      assert attrs["package_identifier"] == "@acme/weather-mcp"
      assert attrs["env_vars"] == ["WEATHER_API_KEY"]
      assert {:ok, _} = Registry.create_server(Map.put(attrs, "name", "io.github.acme/copy"))
    end
  end

  describe "Manifest.from_map/1 with official registry data" do
    test "treats blank strings as missing and reads the older snake_case registry key" do
      attrs =
        Manifest.from_map(%{
          "name" => "io.github.acme/legacy-server",
          "title" => "  ",
          "description" => "Legacy format.",
          "version" => "1.0.0",
          "repository" => %{"url" => ""},
          "websiteUrl" => "",
          "packages" => [%{"registry_type" => "pypi", "identifier" => "legacy-server"}]
        })

      assert attrs["title"] == "legacy server"
      assert attrs["repository_url"] == nil
      assert attrs["website_url"] == nil
      assert attrs["package_registry"] == "pypi"
    end

    test "imported listings may have short descriptions and placeholder URLs; local ones may not" do
      attrs = %{
        name: "com.example/tenant",
        title: "Tenant",
        description: "Short.",
        transport: "streamable-http",
        remote_url: "https://{tenant}.example.com/mcp"
      }

      assert Server.changeset(%Server{}, attrs, imported: true).valid?
      assert %{description: [_]} = errors_on(Server.changeset(%Server{}, attrs))

      for url <- ["https://{HOST}:{PORT}/mcp", "https://support.example.com/api/mcp/[YOUR_TOKEN]"] do
        assert Server.changeset(%Server{}, %{attrs | remote_url: url}, imported: true).valid?, url
      end

      for url <- ["ftp://example.com", "https:///no-host", "javascript:alert(1)"] do
        refute Server.changeset(%Server{}, %{attrs | remote_url: url}, imported: true).valid?, url
      end

      assert %{remote_url: [_]} =
               errors_on(
                 Server.changeset(%Server{}, %{attrs | remote_url: "https://example.com/[TOKEN]"})
               )
    end
  end

  describe "Install" do
    test "builds Claude Code and mcpServers snippets" do
      server = server_fixture()
      [claude, json] = Install.snippets(server)

      assert claude.code ==
               "claude mcp add #{Server.short_name(server)} -e WEATHER_API_KEY=<WEATHER_API_KEY> -- npx -y @acme/weather-mcp"

      assert json.code =~ ~s("command": "npx")
      assert json.code =~ ~s("WEATHER_API_KEY")

      remote =
        server_fixture(%{
          transport: "sse",
          remote_url: "https://mcp.acme.dev/sse",
          package_registry: nil,
          package_identifier: nil
        })

      assert [%{code: "claude mcp add --transport sse " <> _}, %{code: json_code}] =
               Install.snippets(remote)

      assert json_code =~ ~s("type": "sse")
    end
  end
end
