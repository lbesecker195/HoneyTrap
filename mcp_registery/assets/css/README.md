This directory holds the site's single CSS entry point, `app.css`, compiled by Tailwind CSS v4 into the stylesheet every page on the live site loads. It imports Tailwind itself, the colocated Phoenix LiveView component CSS, the heroicons plugin that enables `hero-*` icon classes, and the daisyUI plugin with two custom themes — a light theme (default) and a dark theme keyed to `prefers-color-scheme` — which set every color, radius, and border token used across the app's buttons, cards, and form fields. It also defines LiveView-specific variants (`phx-click-loading`, `phx-submit-loading`, `phx-change-loading`) so the interface can style in-flight requests, and makes `data-phx-session` wrapper divs transparent for layout.

Because this stylesheet loads on every page, it directly shapes the visual identity of the whole registry, from browsing and searching servers to viewing a single listing to submitting a new one. Nothing here is a build artifact, test fixture, or local-only config; it is production source shipped on every deploy.

Pages affected:

- Search and browse thousands of MCP servers on the [MCP Registry homepage](https://ai.mcpharbor.dev/).
- Submit a new listing through the [server submission form](https://ai.mcpharbor.dev/submit), styled by these daisyUI themes.
