defmodule McpRegistry.OfficialRegistryTest do
  use McpRegistry.DataCase, async: true

  import McpRegistry.RegistryFixtures

  alias McpRegistry.OfficialRegistry
  alias McpRegistry.OfficialRegistry.SyncRun
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server
  alias McpRegistry.Repo

  @stub McpRegistry.OfficialRegistry

  defp entry(name, server \\ %{}, meta \\ %{}) do
    short = name |> String.split("/") |> List.last()

    %{
      "server" =>
        Map.merge(
          %{
            "$schema" =>
              "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
            "name" => name,
            "description" => "Official listing for #{short}.",
            "version" => "1.0.0",
            "packages" => [
              %{
                "registryType" => "npm",
                "identifier" => "@official/#{short}",
                "transport" => %{"type" => "stdio"}
              }
            ]
          },
          server
        ),
      "_meta" => %{
        "io.modelcontextprotocol.registry/official" =>
          Map.merge(
            %{"status" => "active", "updatedAt" => "2026-09-01T00:00:00Z", "isLatest" => true},
            meta
          )
      }
    }
  end

  # Serves `pages` (a list of entry lists) with cursors, recording each query.
  defp serve(pages) do
    test_pid = self()

    Req.Test.stub(@stub, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      send(test_pid, {:official_request, conn.request_path, conn.query_params})
      index = String.to_integer(conn.query_params["cursor"] || "0")
      next = if index + 1 < length(pages), do: Integer.to_string(index + 1)

      Req.Test.json(conn, %{
        "servers" => Enum.at(pages, index),
        "metadata" => %{"nextCursor" => next}
      })
    end)
  end

  test "a full sync imports every page and copes with upstream quirks" do
    serve([
      [
        entry("io.github.Acme/Weather", %{
          "title" => "Weather",
          "repository" => %{"url" => "", "source" => ""}
        }),
        entry("com.example/templated", %{
          "packages" => nil,
          "remotes" => [
            %{"type" => "streamable-http", "url" => "https://{tenant}.example.com/mcp"}
          ]
        }),
        entry("com.example/short-desc", %{"description" => "Tiny."}),
        entry("com.example/long-url", %{
          "packages" => nil,
          "remotes" => [
            %{
              "type" => "streamable-http",
              "url" => "https://mcp.example.com/" <> String.duplicate("a", 800)
            }
          ]
        })
      ],
      [
        entry("io.github.acme/weather", %{"description" => "A case-only duplicate."}),
        entry("com.example/nothing-to-install", %{"packages" => [], "remotes" => []}),
        entry("com.example/crate", %{
          "packages" => [
            %{
              "registryType" => "cargo",
              "identifier" => "crate-mcp",
              "transport" => %{"type" => "stdio"}
            }
          ]
        })
      ]
    ])

    assert {:ok, stats} = OfficialRegistry.sync(mode: :full)
    assert %{inserted: 5, duplicate: 1, not_installable: 1, invalid: 0, failed: 0} = stats

    assert_received {:official_request, "/v0.1/servers",
                     %{"version" => "latest", "limit" => "100"} = first}

    refute Map.has_key?(first, "updated_since")
    assert_received {:official_request, "/v0.1/servers", %{"cursor" => "1"}}

    assert {:ok, weather} = Registry.fetch_server("io.github.Acme/Weather")

    assert %Server{
             name: "io.github.acme/weather",
             title: "Weather",
             origin: "official",
             status: "active"
           } = weather

    assert weather.repository_url == nil
    assert %DateTime{} = weather.synced_at

    assert {:ok, %Server{title: "templated", transport: "streamable-http"}} =
             Registry.fetch_server("com.example/templated")

    assert {:ok, %Server{description: "Tiny."}} = Registry.fetch_server("com.example/short-desc")
    assert {:ok, %Server{package_registry: "cargo"}} = Registry.fetch_server("com.example/crate")

    assert %SyncRun{status: "ok", mode: "full", finished_at: %DateTime{}} =
             OfficialRegistry.last_run()
  end

  test "merge rules protect curated and approved listings" do
    seed =
      server_fixture(%{
        name: "io.github.upstash/context7",
        title: "Context7",
        tags: ["documentation"],
        tools: ["get-library-docs"]
      })
      |> Ecto.Changeset.change(origin: "seed")
      |> Repo.update!()

    approved_local =
      server_fixture(%{name: "io.github.local/approved", description: "Approved here, by hand."})

    pending_local = server_fixture(%{name: "io.github.squat/pending", status: "pending"})

    serve([
      [
        entry(seed.name, %{"version" => "4.1.0", "description" => "Docs from upstream."}),
        entry(approved_local.name, %{"description" => "Upstream would overwrite this."}),
        entry(pending_local.name, %{"description" => "The verified owner's listing."}),
        entry("com.example/retired", %{}, %{"status" => "deprecated"})
      ]
    ])

    assert {:ok, stats} = OfficialRegistry.sync(mode: :full)
    assert %{updated: 1, kept_local: 1, replaced_pending: 1, inserted: 1} = stats

    assert {:ok, merged} = Registry.fetch_server(seed.name)

    assert %Server{origin: "seed", version: "4.1.0", description: "Docs from upstream."} =
             merged

    assert %DateTime{} = merged.synced_at
    assert merged.title == "Context7"
    assert merged.tags == ["documentation"]
    assert merged.tools == ["get-library-docs"]

    assert {:ok, %Server{origin: "local", description: "Approved here, by hand."}} =
             Registry.fetch_server(approved_local.name)

    assert {:ok,
            %Server{
              origin: "official",
              status: "active",
              description: "The verified owner's listing."
            }} =
             Registry.fetch_server(pending_local.name)

    assert {:ok, %Server{status: "deprecated"}} = Registry.fetch_server("com.example/retired")
    assert Registry.list_servers(q: "retired") == []
  end

  test "incremental syncs send updated_since, skip unchanged listings and apply deletions" do
    serve([[entry("com.example/keep"), entry("com.example/goes-away")]])
    assert {:ok, %{inserted: 2}} = OfficialRegistry.sync(mode: :full)
    {:ok, before} = Registry.fetch_server("com.example/keep")

    serve([
      [
        entry("com.example/keep"),
        entry("com.example/goes-away", %{}, %{
          "status" => "deleted",
          "updatedAt" => "2026-09-10T00:00:00Z"
        }),
        entry("com.example/never-here", %{}, %{"status" => "deleted"})
      ]
    ])

    assert {:ok, stats} = OfficialRegistry.sync()
    assert %{unchanged: 1, deleted: 1, ignored_deleted: 1} = stats

    assert_received {:official_request, _, %{"updated_since" => since}}
    assert {:ok, _, _} = DateTime.from_iso8601(since)
    assert %SyncRun{mode: "incremental", status: "ok"} = OfficialRegistry.last_run()

    assert {:error, :not_found} = Registry.fetch_server("com.example/goes-away")
    {:ok, after_sync} = Registry.fetch_server("com.example/keep")
    assert after_sync.updated_at == before.updated_at
    assert DateTime.compare(after_sync.synced_at, before.synced_at) == :gt
  end

  test "seed listings are never removed by upstream deletions or sweeps" do
    seed =
      server_fixture(%{name: "io.github.curated/keeper"})
      |> Ecto.Changeset.change(origin: "seed")
      |> Repo.update!()

    serve([[entry(seed.name, %{}, %{"status" => "deleted"}), entry("com.example/other")]])
    assert {:ok, %{ignored_deleted: 1}} = OfficialRegistry.sync(mode: :full)
    assert {:ok, %Server{origin: "seed"}} = Registry.fetch_server(seed.name)
  end

  test "a full sync removes official listings that vanished upstream, but never wipes the catalogue" do
    serve([Enum.map(1..4, &entry("com.example/server-#{&1}"))])
    assert {:ok, %{inserted: 4}} = OfficialRegistry.sync(mode: :full)

    serve([Enum.map(1..3, &entry("com.example/server-#{&1}"))])
    assert {:ok, %{removed_missing: 1}} = OfficialRegistry.sync(mode: :full)
    assert {:error, :not_found} = Registry.fetch_server("com.example/server-4")

    # Upstream suddenly returns one server: treat it as a glitch, not deletions.
    serve([[entry("com.example/server-1")]])
    assert {:ok, %{sweep_skipped: true}} = OfficialRegistry.sync(mode: :full)
    assert {:ok, _} = Registry.fetch_server("com.example/server-3")
  end

  test "transient upstream errors are retried" do
    {:ok, attempts} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(@stub, fn conn ->
      if Agent.get_and_update(attempts, &{&1, &1 + 1}) == 0 do
        Plug.Conn.send_resp(conn, 500, "boom")
      else
        Req.Test.json(conn, %{"servers" => [entry("com.example/after-retry")], "metadata" => %{}})
      end
    end)

    assert {:ok, %{inserted: 1}} = OfficialRegistry.sync(mode: :full)
  end

  test "a persistent failure is recorded and nothing is swept" do
    serve([[entry("com.example/survivor")]])
    assert {:ok, _} = OfficialRegistry.sync(mode: :full)

    Req.Test.stub(@stub, fn conn -> Plug.Conn.send_resp(conn, 503, "down") end)

    assert {:error, "official registry returned HTTP 503", _stats} =
             OfficialRegistry.sync(mode: :full)

    assert %SyncRun{status: "error", error: "official registry returned HTTP 503"} =
             OfficialRegistry.last_run()

    assert {:ok, _} = Registry.fetch_server("com.example/survivor")
  end

  test "runs left marked running by a crash are closed out" do
    stale =
      Repo.insert!(%SyncRun{mode: "full", status: "running", started_at: DateTime.utc_now()})

    serve([[entry("com.example/fresh")]])

    assert {:ok, _} = OfficialRegistry.sync(mode: :full)
    assert %SyncRun{status: "error", error: "interrupted"} = Repo.get!(SyncRun, stale.id)
  end

  test "server_url points at the official API entry" do
    assert OfficialRegistry.server_url("io.github.acme/weather") ==
             "https://registry.modelcontextprotocol.io/v0.1/servers/io.github.acme%2Fweather/versions/latest"
  end
end
