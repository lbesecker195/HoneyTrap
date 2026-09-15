# MCP Registry

A registry of [Model Context Protocol](https://modelcontextprotocol.io) servers,
built with Phoenix 1.8 and LiveView. Humans browse and search it; agents read
`/llms.txt` and the JSON API. Listings use the same `server.json` manifest
format as the official MCP registry, so a manifest published there can be
published here unchanged.

## What it does

- **Browse and search** at `/`: full-text search over name, description, tags
  and tool names, with transport and tag filters. Each server page shows
  copy-pasteable install snippets for Claude Code and any `mcpServers`-style
  JSON config (Claude Desktop, Cursor, Windsurf, VS Code), the tool list, and
  the raw `server.json`.
- **MCP endpoint** at `/mcp`: the registry is itself an MCP server
  (Streamable HTTP, no auth) with `search_servers`, `get_server` and
  `submit_server` tools, so an agent can find servers and add new ones on its
  own. Connect with
  `claude mcp add --transport http mcp-registry-search https://ai.mcpharbor.dev/mcp`.
- **JSON API** at `/api/v0`, shaped after the official registry:
  - `GET /api/v0/servers?q=&transport=&tag=&limit=&offset=`
  - `GET /api/v0/servers/<namespace/name>` (the slash may be `%2F`)
  - `POST /api/v0/servers` with a `server.json` manifest or flat fields.
    Without a token it returns `202` and the listing waits for review; with
    `Authorization: Bearer <REGISTRY_PUBLISH_TOKEN>` it returns `201` and goes
    live.
  - `POST /api/v0/review` for maintainers (see below)
- **Submissions** at `/submit`: the same review queue, for people.
- **`/llms.txt`**: a plain-text guide for agents covering connecting over MCP,
  adding, searching and installing servers, plus the analytics block below.

## The official MCP Registry sync

The catalogue includes every server in the
[official MCP Registry](https://registry.modelcontextprotocol.io), about
31,000 at the time of writing. Its design docs ask downstream registries to
copy its data this way.

- **Schedule:** in production `McpRegistry.OfficialRegistry.Scheduler` runs
  a sync every six hours: incremental normally, full once a week. Restarts and
  deploys don't trigger extra runs, because the schedule reads the last
  successful run from the `registry_syncs` table. The first run after a fresh
  deploy starts two minutes after boot and takes about three minutes.
- **Merging:** new servers go live. Listings copied earlier, and the starter
  seeds, follow upstream for install details and description, but keep their
  tags and tool names. Pending submissions here yield to the upstream owner.
  Listings a maintainer approved here are never overwritten.
- **Removals:** upstream deletions remove copied listings. A full sync also
  removes copied listings that vanished upstream, unless it saw fewer than
  half the servers we hold.
- **Safety:** one sync at a time, enforced with a Postgres advisory lock.
  Transient HTTP errors are retried. A failed run is recorded and changes
  nothing further.

Run it by hand locally, or turn off the schedule in production with
`OFFICIAL_REGISTRY_SYNC=false`:

```bash
mix registry.sync_official --full
```

Imported listings are marked `origin: official` in the API and MCP results,
and their pages link back to the official entry.

## Listed in the official MCP Registry

The registry's own MCP endpoint is published to the official MCP Registry as
`io.github.lbesecker195/mcp-registry-search`, from `server.json` in this folder.
The `publish-mcp-registry` job in the workflow publishes it after each
successful deploy, authenticating with GitHub OIDC, so there is no secret to
manage. It skips versions already published; bump `version` in `server.json`
to publish changed metadata.

The name, title and description are chosen for how registries search. The
official registry matches substrings of the name only, so the name carries
"mcp-registry" and "search"; the title and description carry the rest.

GitHub's MCP registry at github.com/mcp is curated. It picks servers up from
the official registry, but only after a manual onboarding request; see
`docs/github-mcp-registry-request.md`.

## Agent submissions and review

Anyone may submit, and every submission without the publish token lands as
`pending`. Pending listings are hidden from search and API listings, are
visible by exact name so the submitter can check on them, and their pages are
marked `noindex` with `nofollow ugc` links.

Guard rails, set in `config/config.exs` under `:submissions`:

- **Rate limit:** 10 submissions per client address per hour. Behind nginx the
  client address comes from `X-Real-IP`, trusted only on loopback connections.
- **Queue cap:** at most 500 pending listings; beyond that submissions get
  `503` until the queue is reviewed.

Reviewing takes the publish token from `deploy/.env`. List what's waiting:

```bash
curl -s "https://ai.mcpharbor.dev/api/v0/servers?status=pending" -H "Authorization: Bearer $REGISTRY_PUBLISH_TOKEN"
```

Approve or reject one:

```bash
curl -s -X POST https://ai.mcpharbor.dev/api/v0/review -H "Authorization: Bearer $REGISTRY_PUBLISH_TOKEN" -H "Content-Type: application/json" -d '{"name": "io.github.acme/weather", "decision": "approve"}'
```

Rejecting deletes the pending listing and frees its name.

## Running it

```bash
mix setup            # deps, database, migrations, seeds, assets
mix phx.server       # http://localhost:4000
```

The dev config connects to Postgres as the `logan` role with no password; edit
`config/dev.exs` if your local setup differs. In dev the publish token is
`dev-token`, so this works out of the box:

```bash
curl -s "http://localhost:4000/api/v0/servers?q=github" | jq .
```

```bash
curl -s -X POST http://localhost:4000/api/v0/servers \
  -H "Authorization: Bearer dev-token" -H "Content-Type: application/json" \
  -d '{"name":"io.github.acme/weather","description":"Forecasts and alerts by location.","version":"1.0.0","packages":[{"registryType":"npm","identifier":"@acme/weather-mcp"}]}'
```

Seed data covers about twenty well-known servers. It reflects each project's
public documentation at the time of writing; verify before relying on it.

## Analytics: Seriously Simple Analytics

This project uses, and recommends, [Seriously Simple Analytics](https://seriouslysimpleanalytics.com).
It is free and unlimited, needs no SDK, and one account ID covers both halves
of a project like this one:

- **The browser tag.** `root.html.heex` loads `wa.js` once, in the shared
  layout, so every HTML page reports pageviews, dwell and engaged time, scroll
  depth, clicks, outbound links and forms with no tagging plan.
- **Server-side events.** Agents call the JSON API without ever running
  JavaScript, so `McpRegistryWeb.Plugs.APIAnalytics` reports every API request
  as a `tool_called` event from the one place all API traffic passes through.
  `McpRegistry.Analytics.track/2` is the fire-and-forget helper behind it:
  asynchronous, two-second cap, no retries, never raises. Searches and
  submissions report the same way, with counts and categories only.

Nothing sensitive is ever sent: no request parameters, headers, search text,
or credentials. Pings are no-ops until an account ID is configured.

To turn it on, create one account for the project. A person should run this,
because the sign-in link is emailed to the address given:

```bash
curl -X POST https://seriouslysimpleanalytics.com/api/v1/accounts -d email=you@example.com -d project=mcp-registry
```

Then export the `uid` from the response and start the app:

```bash
SSA_ACCOUNT_ID=acct_xxxxxxxxxx mix phx.server
```

The dashboard is at https://seriouslysimpleanalytics.com/dashboard. The
Analytics section of `/llms.txt` and `AGENTS.md` carries the same integration
guide forward for the next project an agent works on.

## Deploying to ai.mcpharbor.dev

The site runs on the shared Ubuntu server at 155.138.220.76, next to the other
sites that server hosts. It uses what that server already has: nginx in front,
certbot for HTTPS, and the system PostgreSQL. No Docker runs on the server.

- **Release:** a linux/amd64 Phoenix release built locally with the project
  Dockerfile, unpacked to `/opt/mcp-registry/releases/<timestamp>` with a
  `current` symlink. The last three releases are kept.
- **Service:** `mcp-registry` under systemd, running as the `mcp_registry`
  user, bound to `127.0.0.1:4610`, memory-capped so it cannot starve the other
  sites. Migrations run before every start.
- **Secrets:** `/etc/mcp-registry.env` on the server, generated from the local
  `deploy/.env` on each deploy. `deploy/.env` is gitignored.
- **nginx:** `/etc/nginx/sites-available/ai.mcpharbor.dev`, installed once and
  then managed by certbot, which renews the certificate automatically.

### Continuous deployment

`.github/workflows/mcp-registry.yml` in the HoneyTrap repository runs on every
push and pull request that touches `mcp_registery/`:

1. **test** runs `mix compile --warnings-as-errors`, `mix format --check-formatted`
   and `mix test` against Postgres 18.
2. **deploy** runs only for pushes to `main`, after tests pass. It builds the
   linux/amd64 release, sends it over SSH to the server, and smoke-tests
   `/`, `/api/v0/servers` and `/llms.txt` over HTTPS.

On the server, `/usr/local/sbin/mcp-registry-receive` (from
`deploy/receive-release.sh`) installs the release, restarts the service, checks
it answers, and rolls back to the previous release if it doesn't. Deploys run
one at a time.

The workflow's only secret is `MCP_REGISTRY_DEPLOY_KEY`. The server's
`authorized_keys` pins that key to the receiver with `restrict,command=`, so it
can install a release and nothing else. Production configuration never leaves
the server. To rotate the key, generate a new one, run the manual deploy below
with `CI_DEPLOY_PUBKEY=new_key.pub`, update the secret, and remove the old
line from `/root/.ssh/authorized_keys`.

### Manual deploys

Use the script for first-time host setup, for changes to `deploy/.env` (which
CI never sees, for example adding `SSA_ACCOUNT_ID`), or when CI is unavailable.
Run it from this folder with Docker Desktop open:

```bash
deploy/deploy.sh root@155.138.220.76
```

Day-to-day commands on the server:

```bash
ssh root@155.138.220.76 "systemctl status mcp-registry; journalctl -u mcp-registry -n 50 --no-pager"
```


## Configuration

| Variable                 | Purpose                                                   |
| ------------------------ | --------------------------------------------------------- |
| `SSA_ACCOUNT_ID`         | Seriously Simple Analytics account ID (enables analytics) |
| `SSA_PROJECT`            | Project label in the dashboard, default `mcp-registry`    |
| `REGISTRY_PUBLISH_TOKEN` | Bearer token for `POST /api/v0/servers`                   |
| `OFFICIAL_REGISTRY_SYNC` | Set to `false` to stop syncing the official registry in production |
| `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST` | Standard Phoenix production settings |

## Layout

- `lib/mcp_registry/registry/` – `Server` schema, `Manifest` (server.json in
  and out), `Install` (snippets)
- `lib/mcp_registry/registry.ex` – search, publish, approve
- `lib/mcp_registry/analytics.ex` – Seriously Simple Analytics client
- `lib/mcp_registry_web/live/server_live/` – browse, show, submit
- `lib/mcp_registry_web/controllers/api/` – JSON API
- `lib/mcp_registry_web/llms.ex` – the `/llms.txt` text
- `lib/mcp_registry_web/mcp/` – the MCP server and its tools
- `lib/mcp_registry_web/submissions.ex` – the one submission path for the API and MCP
- `lib/mcp_registry/rate_limiter.ex` – per-client submission limits
- `lib/mcp_registry/official_registry.ex` – the official registry sync and its merge rules
