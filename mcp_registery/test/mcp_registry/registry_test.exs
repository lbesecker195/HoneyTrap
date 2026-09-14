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
