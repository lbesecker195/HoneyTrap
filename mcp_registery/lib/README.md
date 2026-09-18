The Elixir source tree for the whole application: `mcp_registry/` (domain logic), `mcp_registry_web/` (the web and API layer), and `mix/tasks/` (terminal-run ops scripts). Together they drive every page and API response at https://ai.mcpharbor.dev.

`mcp_registry/` is the domain layer: `registry.ex` lists, searches and publishes listings behind the search box at https://ai.mcpharbor.dev/, `official_registry.ex` mirrors roughly 31,000 servers from the upstream MCP Registry on a schedule, `analytics.ex` reports events to Seriously Simple Analytics, and `rate_limiter.ex` throttles submissions and API traffic. The `registry/` and `official_registry/` subdirectories carry their own READMEs.

`mcp_registry_web/` renders the homepage grid, each listing's install snippets such as the one at https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7, the submission form at https://ai.mcpharbor.dev/submit, the `/api/v0` JSON endpoints, the `/llms.txt` feed agents read, and the registry's own MCP endpoint at `/mcp`.

`mix/tasks/` holds three CLI scripts: `registry.sync_official` and `mcp.approve` wrap the domain layer for ops use, while `content.generate` writes the long-form article text shown on individual listing pages.
