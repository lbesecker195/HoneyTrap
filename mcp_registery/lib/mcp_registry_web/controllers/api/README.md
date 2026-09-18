This directory implements the site's JSON API under `/api/v0` — the machine-readable counterpart to the HTML pages, for scripts and other non-MCP clients.

- `server_controller.ex` — lists and searches active listings, fetches one listing by name, accepts new submissions (queued for review, or live immediately with the publish token), and lets a maintainer approve or reject a pending one.
- `fallback_controller.ex` — turns validation errors, missing servers, bad auth, rate limits, and a full review queue into the consistent JSON error shape API clients rely on.
- `server_json.ex` — renders each listing as its `server.json` manifest plus registry metadata (status, origin, sync time), for both the list and single-server responses.

Every call to [the registry's public JSON API](https://ai.mcpharbor.dev/api/v0/servers) and to a single listing's manifest, such as [the Context7 server entry](https://ai.mcpharbor.dev/api/v0/servers/io.github.upstash%2Fcontext7), is served by this code. Submitting here shares its underlying create logic with [the server submission page](https://ai.mcpharbor.dev/submit) and, through the same review queue, with the registry's MCP endpoint. No HTML template lives here; this is the data layer agents and scripts talk to directly.
