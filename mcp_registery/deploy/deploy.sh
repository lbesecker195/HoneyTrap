#!/bin/sh
# Manual deploy, and first-time setup of a new host. Pushes to main deploy
# automatically through .github/workflows/mcp-registry.yml; use this script for
# host setup, config changes in deploy/.env, or when CI is unavailable.
#
#     deploy/deploy.sh root@155.138.220.76
#     SEED=1 deploy/deploy.sh root@HOST                           # new host: also load the catalogue
#     CI_DEPLOY_PUBKEY=key.pub deploy/deploy.sh root@HOST         # also authorize a CI deploy key
#
# Needs Docker Desktop running locally. The server needs nginx, certbot and
# PostgreSQL; it hosts other sites, and nothing here touches them.
set -eu

target="${1:?usage: deploy/deploy.sh user@host}"
here="$(cd "$(dirname "$0")" && pwd)"

[ -f "$here/.env" ] || { echo "deploy/.env is missing. Copy deploy/.env.example and fill it in." >&2; exit 1; }
set -a; . "$here/.env"; set +a
: "${PHX_HOST:?set PHX_HOST in deploy/.env}"
: "${POSTGRES_PASSWORD:?set POSTGRES_PASSWORD in deploy/.env}"
: "${SECRET_KEY_BASE:?set SECRET_KEY_BASE in deploy/.env}"
app_port="${APP_PORT:-4610}"

echo "==> Building release"
tarball=$("$here/build-release.sh")

envfile=$(mktemp)
trap 'rm -f "$envfile"' EXIT
chmod 600 "$envfile"
cat > "$envfile" <<ENV
PHX_HOST=$PHX_HOST
PHX_SERVER=true
PHX_IP=127.0.0.1
PORT=$app_port
DATABASE_URL=ecto://mcp_registry:$POSTGRES_PASSWORD@127.0.0.1/mcp_registry
DB_PASSWORD=$POSTGRES_PASSWORD
POOL_SIZE=5
SECRET_KEY_BASE=$SECRET_KEY_BASE
REGISTRY_PUBLISH_TOKEN=${REGISTRY_PUBLISH_TOKEN:-}
SSA_ACCOUNT_ID=${SSA_ACCOUNT_ID:-}
SSA_PROJECT=${SSA_PROJECT:-mcp-registry}
RELEASE_TMP=/opt/mcp-registry/tmp
ERL_EPMD_ADDRESS=127.0.0.1
LANG=C.UTF-8
ENV

echo "==> Uploading host files to $target"
ssh "$target" "umask 077 && cat > /tmp/mcp-registry.env" < "$envfile"
scp -q "$here/mcp-registry.service" "$target:/tmp/mcp-registry.service"
scp -q "$here/nginx-site.conf" "$target:/tmp/mcp-registry-nginx.conf"
scp -q "$here/receive-release.sh" "$target:/tmp/mcp-registry-receive"
if [ -n "${CI_DEPLOY_PUBKEY:-}" ]; then
  scp -q "$CI_DEPLOY_PUBKEY" "$target:/tmp/mcp-registry-ci.pub"
fi

echo "==> Setting up host"
ssh "$target" "sh -s -- '$PHX_HOST' '$app_port'" < "$here/remote-install.sh"

echo "==> Installing release"
ssh "$target" /usr/local/sbin/mcp-registry-receive < "$tarball"

if [ "${SEED:-0}" = "1" ]; then
  echo "==> Loading starter catalogue"
  ssh "$target" "set -a; . /etc/mcp-registry.env; set +a; runuser -u mcp_registry -- /opt/mcp-registry/current/bin/seed"
fi

echo "==> Checking https://$PHX_HOST from here"
curl -s -o /dev/null -w "https://$PHX_HOST/ -> %{http_code}\n" "https://$PHX_HOST/" || true
curl -s -o /dev/null -w "https://$PHX_HOST/api/v0/servers -> %{http_code}\n" "https://$PHX_HOST/api/v0/servers" || true
