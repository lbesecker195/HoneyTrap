Core domain logic for a single MCP server listing, used everywhere a listing is stored, validated, or rendered.

- `server.ex` — the Ecto schema and changeset for the `servers` table: name format, transport (`stdio`/`streamable-http`/`sse`), package registry, and the validation rules that accept or reject a submission.
- `manifest.ex` — converts a listing to and from the official `server.json` shape, so imported records from the upstream MCP Registry map cleanly onto this schema and back.
- `install.ex` — builds the copy-pasteable Claude Code command and `mcpServers` JSON snippet shown for each listing.
- `remote_content.ex` — fetches a GitHub README excerpt and website title/description to enrich a listing's page, failing soft if the fetch errors.

Together these modules generate the install instructions and manifest data on each listing page at https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7 (and every other server slug), and they enforce the validation that accepts or rejects new submissions from https://ai.mcpharbor.dev/submit. They have no template of their own; `show.ex` in the web layer calls into this directory to render.
