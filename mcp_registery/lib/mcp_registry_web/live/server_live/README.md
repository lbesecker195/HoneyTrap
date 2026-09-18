This directory holds the three LiveViews that render the registry's main visitor- and agent-facing pages.

`index.ex` backs the homepage search and browse experience at https://ai.mcpharbor.dev/, where humans and agents filter the mirrored MCP servers by keyword, transport, or tag.

`show.ex` renders each individual server listing, such as https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7, displaying install snippets, the raw server.json manifest, and README content fetched live from the server's own repository.

`new.ex` powers the submission form at https://ai.mcpharbor.dev/submit, where new listings enter as "pending" until reviewed; AI agents can also submit programmatically through the MCP endpoint or the JSON API instead of using this form.

Together these three modules are the entire public directory experience: any change here directly changes what visitors and agents see and can do on the live site.
