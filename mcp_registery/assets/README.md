# Assets

Source for the site's front-end build: Tailwind CSS v4 plus daisyUI theming (`css/app.css`), the Phoenix LiveView client bootstrap (`js/app.js`), and two small vendored scripts (`vendor/heroicons.js`, `vendor/topbar.js`). `tsconfig.json` only enables editor autocompletion for LiveView's JS API and has no effect on the deployed site.

`app.js` sets up the LiveSocket connection, CSRF token handling, and the `topbar` progress bar shown during live navigation and form submits — the mechanism behind every live update on [the MCP server directory](https://ai.mcpharbor.dev/), from search-as-you-type on the homepage to the listing pages under `/servers/*`. `app.css` defines the light and dark daisyUI themes (switching automatically with the browser's color-scheme preference) and the Tailwind content sources, so essentially every button, card, and layout across the site is styled from here.

`mix assets.deploy` compiles these sources into digested files under `priv/static/assets/`, which is what browsers actually load in production. This directory is the build input, not the served output, so nothing here is fetched directly by visitors.
