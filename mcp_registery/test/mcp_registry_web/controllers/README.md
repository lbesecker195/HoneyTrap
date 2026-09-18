This directory holds ExUnit test suites for the web controllers, not code that runs on the live site.

- `mcp_controller_test.exs` exercises the JSON-RPC `/mcp` endpoint: protocol handshake and version negotiation, `ping`, malformed requests, unknown methods and unknown tools, batched requests, and the `search_servers`, `get_server`, and `submit_server` tools, including validation-error responses.
- `api/server_controller_test.exs` exercises the REST `/api/v0/servers` endpoints: listing and filtering active vs. pending servers, maintainer-only access to pending status, rate limiting per client IP, publishing a manifest with the admin bearer token, maintainer approve/reject decisions via `/api/v0/review`, and the `/llms.txt` agent doc's contents.
- `error_html_test.exs` and `error_json_test.exs` check that Phoenix's default 404/500 error views render the expected HTML and JSON bodies.

These tests only run locally and in CI (via `mix test`); they never execute against production and ship no code to the deployed app. Their value is confidence that the underlying controllers keep behaving correctly before a change reaches the live `/mcp` endpoint and the `/api/v0` JSON API that agents rely on.
