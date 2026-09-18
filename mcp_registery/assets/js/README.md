# assets/js

Holds `app.js`, the client-side entry point Phoenix's esbuild pipeline bundles for every page. It imports `phoenix_html` (so PUT/DELETE form buttons work), opens the CSRF-protected `LiveSocket` connection (with colocated hooks from the `mcp_registry` app), and mounts `topbar` to show a progress bar during live navigation and form submits. In development it also streams server logs to the browser console and lets you click a rendered element to jump to its LiveView source.

Because this script is what boots the LiveSocket, it is what turns every LiveView page on the site from static HTML into a live one: searching and browsing the [MCP server directory](https://ai.mcpharbor.dev/), scrolling through an individual listing's install snippets, and filling out the [add-a-server form](https://ai.mcpharbor.dev/submit). If this bundle fails to build or load, those pages still render their initial HTML but lose live search, filtering, and submission — buttons and links stop updating the page without a full reload.

There is only one file here right now, `app.js`; no extra vendor imports or additional JS modules have been added to this directory yet.
