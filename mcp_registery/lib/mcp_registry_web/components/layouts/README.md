# Layouts

This directory holds the single root HTML layout (`root.html.heex`) that every page in the app renders through — there is no separate inner/app layout, LiveView content is injected straight into `{@inner_content}` here.

It defines the shared `<head>` for the whole site: the CSRF token, the `<link rel="alternate">` pointing agents at the llms.txt file, the compiled CSS/JS bundles, the Seriously Simple Analytics tracking script, the sitewide Google AdSense script, and an inline script that sets the light/dark theme from `localStorage` or the OS preference before first paint.

Because every route is wrapped by this one template, edits here change analytics coverage, ad placement, theming, and SEO/agent discovery signals across the entire live site at once, not just one page — from the [MCP server directory's homepage](https://ai.mcpharbor.dev/) through every individual [server listing page](https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7) and the [server submission form](https://ai.mcpharbor.dev/submit). It has no logic of its own beyond markup and the small inline theme script.
