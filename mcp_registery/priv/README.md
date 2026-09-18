This directory holds three unrelated pieces of the app: compiled static assets, the database schema, and i18n scaffolding.

`static/` is what browsers load directly: the compiled Tailwind CSS and JS bundles, favicon, and `robots.txt` (currently open to all crawlers, helping [the live registry](https://ai.mcpharbor.dev/) get indexed). It also holds a logo and sponsor/book images sitting in `images/` that aren't yet referenced by any page template. Nothing here is hand-authored; `mix assets.deploy` rebuilds and digests the CSS/JS from the `assets/` source tree on each production build.

`repo/` holds the Ecto migrations defining the `servers` table (name, description, tools, tags, transport) that stores every entry the site displays, from the homepage grid to install snippets like [the Context7 manifest page](https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7), plus `seeds.exs`, which only loads example listings into a local dev database and never touches production.

`gettext/` is stock Phoenix i18n scaffolding: an `errors.pot` template and one untranslated `en` catalog for Ecto validation messages. No locale is wired into any page's UI, so this subdirectory has no direct effect on the live site today.
