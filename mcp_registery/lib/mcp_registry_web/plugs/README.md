# Plugs

This directory holds two Plug modules used in the Phoenix request pipeline.

`ClientIP` runs on every request through the endpoint and rewrites `conn.remote_ip` from nginx's `X-Real-IP` header, but only when the connecting peer is loopback (the app listens on 127.0.0.1 behind nginx in production). That keeps the per-client-IP submission rate limiter keyed on the real caller rather than the proxy, whether a submission arrives via [the JSON API](https://ai.mcpharbor.dev/api/v0) or the MCP endpoint's `submit_server` tool. [The browser submit form](https://ai.mcpharbor.dev/submit) writes directly to the database and isn't rate limited on this path.

`APIAnalytics` runs only in the `/api/v0` router pipeline. It wraps the list, show, create, and review actions and reports each as a `tool_called` event to Seriously Simple Analytics — action name, status, latency, and a coarse client name, never parameters or headers. It does not run on `/mcp`, which has no analytics plug of its own.

Neither module renders markup, so a bug here shows up as skewed analytics or a wrongly applied rate limit, not as a broken page on [the live directory](https://ai.mcpharbor.dev/).
