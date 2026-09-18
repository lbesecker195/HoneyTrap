# Fixtures

Test-data helpers for the ExUnit suite. `registry_fixtures.ex` defines `McpRegistry.RegistryFixtures`, which builds valid attribute maps for a registry server entry (`valid_server_attrs/1`, with a unique name/title per call) and inserts one via `McpRegistry.Registry.create_server/2` (`server_fixture/1`), defaulting its status to `"active"`.

These helpers exist only so tests can quickly create realistic `Server` records without duplicating attribute maps in every test file. They run against the test database and are never loaded in production.

This directory has no direct effect on the live site.
