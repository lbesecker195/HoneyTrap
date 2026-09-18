Shell and `.bat` scripts that `mix release` copies into the compiled Elixir release's `bin/` directory. `rel/overlays` is Mix Release's default overlay path — anything placed here lands in the release automatically, with no extra config in `mix.exs`. They are not application code; they are the commands an operator or deploy pipeline runs against the built release binary.

- `server` / `server.bat` set `PHX_SERVER=true` and exec the release executable's `start` command, which is what actually boots the Phoenix application in production.
- `migrate` / `migrate.bat` run `McpRegistry.Release.migrate` to apply pending Ecto database migrations.
- `seed` runs `McpRegistry.Release.seed` to load seed data into the database.

No direct effect on the live site: these are release-packaging and deploy-time scripts, not page code, so there is no specific page on ai.mcpharbor.dev to link to. Their effect is indirect but foundational — running `server` is how the whole site comes online, and a failed `migrate` would break every page that reads from the database — but no single URL is tied to this directory.
