This directory holds two vendored front-end scripts compiled into the app's shared `app.js`/`app.css` bundle, not project-specific application code.

`heroicons.js` is a Tailwind plugin that walks the `deps/heroicons` SVG set and generates `hero-*` mask-based icon utility classes, so it drives every icon rendered across the site's UI — search controls, buttons, and navigation chrome.

`topbar.js` is Buu Nguyen's MIT-licensed `topbar` library, wired up to Phoenix LiveView's page-loading events to show the thin colored progress bar at the top of the screen during navigation and live updates.

Because both are compiled into the global bundle rather than scoped to one route, their effect is sitewide rather than tied to a single URL — visible on the searchable directory homepage at https://ai.mcpharbor.dev/ and carried through to every listing page, such as https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7, plus the submission flow.

Neither file is meant to be hand-edited here: icon coverage comes from updating the `heroicons` dependency, and `topbar` is a third-party drop-in, so changes belong upstream or in the app's own JS/CSS entry points.
