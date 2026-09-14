#!/bin/sh
# Installs an MCP Registry release read from stdin, then restarts the service.
#
# Installed on the server as /usr/local/sbin/mcp-registry-receive. It is also
# the forced command for the GitHub Actions deploy key, so that key can install
# a release and do nothing else. Any command the client asks for is ignored.
#
#     ssh root@host /usr/local/sbin/mcp-registry-receive < mcp_registry.tar.gz
set -eu

base=/opt/mcp-registry
max_bytes=209715200 # 200 MB
say() { printf '==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "must run as root"
[ -f /etc/mcp-registry.env ] || fail "this host is not set up yet; run deploy/deploy.sh once first"
port=$(sed -n 's/^PORT=//p' /etc/mcp-registry.env)
host=$(sed -n 's/^PHX_HOST=//p' /etc/mcp-registry.env)

# One deploy at a time.
exec 9>/run/mcp-registry-deploy.lock
flock -n 9 || fail "another deploy is already running"

tmp=$(mktemp /tmp/mcp-registry-release.XXXXXX)
trap 'rm -f "$tmp"' EXIT

say "Receiving release"
head -c "$max_bytes" > "$tmp"
size=$(wc -c < "$tmp")
[ "$size" -gt 0 ] || fail "no release was sent on stdin"
[ "$size" -lt "$max_bytes" ] || fail "release is larger than 200 MB"
if ! tar -tzf "$tmp" 2>/dev/null | grep -qx './bin/server'; then
  fail "input is not an mcp_registry release tarball"
fi

release="$base/releases/$(date -u +%Y%m%d%H%M%S)"
say "Installing $release"
mkdir -p "$release"
tar -xzf "$tmp" -C "$release" --no-same-owner
chown -R mcp_registry:mcp_registry "$release"

previous=$(readlink "$base/current" 2>/dev/null || true)
ln -sfn "$release" "$base/current"
systemctl restart mcp-registry

say "Health check on 127.0.0.1:$port"
ok=0
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $host" -H 'X-Forwarded-Proto: https' "http://127.0.0.1:$port/" || true)
  if [ "$code" = 200 ]; then ok=1; break; fi
  sleep 2
done

if [ "$ok" != 1 ]; then
  journalctl -u mcp-registry -n 30 --no-pager -o cat >&2 || true
  if [ -n "$previous" ] && [ -d "$previous" ]; then
    ln -sfn "$previous" "$base/current"
    systemctl restart mcp-registry || true
    rm -rf "$release"
    fail "new release did not come up; rolled back to $(basename "$previous")"
  fi
  fail "release did not come up"
fi

say "Pruning old releases"
current=$(readlink "$base/current")
ls -1dt "$base"/releases/* | tail -n +4 | while read -r old; do
  [ "$old" = "$current" ] || [ "$old" = "$previous" ] || rm -rf "$old"
done

say "Live: https://$host ($(basename "$release"))"
