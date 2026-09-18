This directory holds the project's Mix tasks: command-line jobs run manually or on a schedule from the terminal, not code that executes on a web request.

- `registry.sync_official.ex` pulls down the roughly 31,000 mirrored listings from the official MCP Registry, populating the catalog visitors search and browse on the [MCP server directory](https://ai.mcpharbor.dev/).
- `mcp.approve.ex` flips a pending submission to approved, which is what makes a newly submitted entry actually show up in search results and listings.
- `content.generate.ex` drives `McpRegistry.ContentGenerator` to write the technical article shown on an individual listing page, such as the [Context7 server page](https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7).

None of these tasks run automatically per request, so they have no direct effect on request latency or uptime. Their impact shows up indirectly: a stale sync means missing or outdated servers on the site, a server stuck unapproved never appears publicly, and a failed content run leaves a listing without its article text. Together they're the mechanism that keeps the live directory's data and per-server writeups current.
