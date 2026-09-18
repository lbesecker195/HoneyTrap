This directory holds the registry's LiveViews, all under `server_live/`, and together they are the entire human-facing UI of the site.

`index.ex` powers the homepage search and browse experience at https://ai.mcpharbor.dev/ — the live-filtered list of MCP servers by keyword, tag, and transport, with the tag cloud, result counts, and pagination.

`show.ex` renders each server's own listing page, such as https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7, including ready-made install snippets, the raw server.json manifest, exposed tool names, and a background-loaded preview of the upstream README and website.

`new.ex` drives the submission form at https://ai.mcpharbor.dev/submit, where a person (or an agent, via the API or MCP endpoint) adds a new server for review before it appears in search.

A change to any file here changes what visitors and agents see immediately: search behavior on the homepage, the layout of every server page, or the fields available when submitting a listing.
