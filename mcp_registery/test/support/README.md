# Test Support

Shared ExUnit scaffolding used by the test suite, not by the running application.

- `conn_case.ex` — `McpRegistryWeb.ConnCase`, the case template for controller/LiveView tests. It builds a `Phoenix.ConnTest` connection and starts an Ecto SQL sandbox transaction per test so database writes roll back afterward.
- `data_case.ex` — `McpRegistry.DataCase`, the case template for context/data-layer tests. It provides the same sandbox setup plus `errors_on/1`, a helper that turns an `Ecto.Changeset`'s errors into a plain map for assertions.
- `fixtures/registry_fixtures.ex` — `McpRegistry.RegistryFixtures`, generating valid, uniquely-named sample MCP server attributes (name, transport, package info, tools, etc.) and a `server_fixture/1` helper that inserts one via `McpRegistry.Registry.create_server/2`.

None of this code ships to production or runs against the live site; it only exercises the registry, controllers, and LiveViews locally via `mix test`, so regressions are caught before a change reaches ai.mcpharbor.dev.
