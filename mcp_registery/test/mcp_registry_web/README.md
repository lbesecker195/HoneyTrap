This directory holds the ExUnit test suite for the web layer: HTTP controllers, LiveViews, and plugs.

`controllers/api/server_controller_test.exs` exercises the JSON API's list, show, publish, and review actions, its per-client rate limiting, and the llms.txt endpoint's contents.

`controllers/mcp_controller_test.exs` exercises the JSON-RPC `/mcp` endpoint end to end: the initialize handshake, ping, batched requests, origin and protocol-version checks, and the `search_servers`, `get_server`, and `submit_server` tools.

`controllers/error_html_test.exs` and `error_json_test.exs` check the generic 404/500 renderers shared by every route.

`live/server_live_test.exs` exercises the homepage search and pagination, a server's own show page, and the submission form's validation and redirect.

`plugs/client_ip_test.exs` checks that the `ClientIP` plug only trusts the `X-Real-IP` header from a loopback peer.

These tests run against the same modules that serve the live homepage, server pages, submission form, JSON API, and MCP endpoint, so a failure here usually points at a real bug in one of those. But the tests themselves only run in CI and local `mix test`, never in production, so this directory has no direct, standalone effect on the live site.
