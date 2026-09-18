This is the core Elixir backend for the MCP directory: the Ecto schema and
query logic for every listing (`Registry`, `Registry.Server`), the sync
engine that mirrors roughly 31,000 servers from the official MCP Registry
(`OfficialRegistry` and its `Scheduler`), install-snippet and `server.json`
generation (`Registry.Install`, `Registry.Manifest`), live README/meta
enrichment for show pages (`Registry.RemoteContent`), plus rate limiting
(`RateLimiter`), Seriously Simple Analytics reporting (`Analytics`), saved
article text (`ContentGenerator`), and OTP startup/release plumbing
(`Application`, `Release`, `Repo`).

Nearly every request touches this code. Browsing and searching the
[MCP server directory](https://ai.mcpharbor.dev/) runs through
`Registry.list_servers/1`; a
[server's install and manifest page](https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7)
is assembled from `Server`, `Manifest`, `Install`, and `RemoteContent`
together; listings from the
[server submission form](https://ai.mcpharbor.dev/submit) are validated and
queued by `Registry.create_server/2`; and agent tool calls on the
[registry's own MCP endpoint](https://ai.mcpharbor.dev/mcp) reach the same
`Registry` functions under the hood. The background sync keeps the catalogue
current against the official registry without disturbing a maintainer-
approved local listing.
