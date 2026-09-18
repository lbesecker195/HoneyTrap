This directory holds shell script overlays that Elixir's `mix release` copies into the compiled release's `bin/` folder alongside the generated `mcp_registry` executable.

- `server` / `server.bat` — set `PHX_SERVER=true` and exec `./mcp_registry start`, the entrypoint the production process manager calls to boot the running app.
- `migrate` / `migrate.bat` — exec `McpRegistry.Release.migrate`, applying pending Ecto migrations against the production Postgres database.
- `seed` — exec `McpRegistry.Release.seed`, running seed data for a freshly deployed release.

These are deploy-time plumbing: they run during the release build and the start/migrate/seed steps of a deploy, not as request-time application code. No single page or endpoint on the live site is tied to this directory, so it has no direct, page-level effect on the site and needs no link.
