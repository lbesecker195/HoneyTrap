# GitHub MCP Registry onboarding request (draft)

GitHub's MCP registry (github.com/mcp) is curated. Servers must first be in the
official MCP Registry; onboarding is then requested in GitHub's discussion:
https://github.com/github/github-mcp-server/discussions/1257

Post this as a comment there once `io.github.lbesecker195/mcp-registry-search`
is live in the official registry:
https://registry.modelcontextprotocol.io/v0.1/servers/io.github.lbesecker195%2Fmcp-registry-search/versions/latest

---

Hi! Requesting onboarding for a remote server that's published in the
official MCP Registry:

**io.github.lbesecker195/mcp-registry-search**
https://registry.modelcontextprotocol.io/v0.1/servers/io.github.lbesecker195%2Fmcp-registry-search/versions/latest

It's an MCP server for finding other MCP servers. Agents can search more than
31,000 servers by task, tool name or tag, get install configs, and submit new
servers for review, without an account. It mirrors the official registry every
six hours.

- Endpoint (Streamable HTTP, no auth): https://ai.mcpharbor.dev/mcp
- Tools: `search_servers`, `get_server`, `submit_server`
- Website: https://ai.mcpharbor.dev
- Source: https://github.com/lbesecker195/HoneyTrap/tree/main/mcp_registery

Thanks for taking a look.
