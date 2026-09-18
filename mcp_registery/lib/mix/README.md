# lib/mix

Mix tasks that operators run from a terminal to maintain the registry's data — none of them execute inside the running web server.

- `tasks/registry.sync_official.ex` pulls the roughly 31,000 mirrored listings from the official MCP Registry, which is what fills the search results and browsing grid on [the MCP Registry home page](https://ai.mcpharbor.dev/).
- `tasks/mcp.approve.ex` approves a pending listing submitted through [the server submission form](https://ai.mcpharbor.dev/submit), making it visible in search and on its own detail page.
- `tasks/content.generate.ex` generates the long-form technical write-up saved for a server, the body text readers see on that listing's page, for example [the Context7 server entry](https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7).

Together these tasks are how new servers enter the catalog, get approved, and gain the descriptive content shown on their pages — they shape what both human visitors and agents reading `/llms.txt` or querying `/api/v0` ultimately see, without being part of the request-handling code itself.
