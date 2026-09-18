# config

Phoenix runtime configuration for the whole application, not page-specific templates or content.

- `config.exs` sets compile-time defaults: the Endpoint, esbuild/Tailwind asset pipelines, submission rate limits, and the shape of the analytics and official-registry-sync settings (values, not secrets).
- `dev.exs` and `test.exs` are local-only and never reach production.
- `prod.exs` turns on `force_ssl`/HSTS and the digested static-asset manifest.
- `runtime.exs` reads environment variables at boot and is what actually drives the live site: `DATABASE_URL`, `SECRET_KEY_BASE`, and `PHX_HOST` stand up the app behind [the MCP server directory](https://ai.mcpharbor.dev/); `SSA_ACCOUNT_ID`/`SSA_PROJECT` switch on the sitewide Seriously Simple Analytics tag; `OFFICIAL_REGISTRY_SYNC` toggles the background mirror job that keeps roughly 31,000 listings current, including entries like [the Context7 server page](https://ai.mcpharbor.dev/servers/io.github.upstash%2Fcontext7); and `REGISTRY_PUBLISH_TOKEN` gates only the authenticated bearer-token path on the JSON API; without it, anonymous submissions from [the submit-a-server form](https://ai.mcpharbor.dev/submit) and the API still land in the review queue.

No template or view lives here, so this directory doesn't render any page directly, but every request to the live site runs under the settings it produces.
