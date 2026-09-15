#!/bin/sh
# One-time (and idempotent) host setup, run as root over SSH by deploy/deploy.sh.
# Arguments: HOST PORT
#
# Additive only: one system user, one database and role, one systemd service,
# the release receiver, and one nginx site with its certificate. It never stops
# nginx or edits other sites, and reloads nginx only after `nginx -t` passes.
# Installing releases is left to /usr/local/sbin/mcp-registry-receive.
set -eu

host="$1"; port="$2"
base=/opt/mcp-registry
say() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

say "Preflight"
for tool in nginx certbot psql curl systemctl runuser flock; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed on this server"
done
runuser -u postgres -- psql -tAc 'SELECT 1' >/dev/null 2>&1 || fail "PostgreSQL is not running or not reachable as the postgres user"
if ss -ltnH "sport = :$port" | grep -q . && ! systemctl is-active --quiet mcp-registry; then
  fail "port $port is already used by another process; set APP_PORT in deploy/.env"
fi
for f in mcp-registry.env mcp-registry.service mcp-registry-nginx.conf mcp-registry-receive; do
  [ -f "/tmp/$f" ] || fail "/tmp/$f was not uploaded"
done

say "System user and directories"
id mcp_registry >/dev/null 2>&1 ||
  useradd --system --home-dir "$base" --shell /usr/sbin/nologin mcp_registry
mkdir -p "$base/releases" "$base/tmp"
chown mcp_registry:mcp_registry "$base" "$base/releases" "$base/tmp"
install -m 600 -o root -g root /tmp/mcp-registry.env /etc/mcp-registry.env
rm -f /tmp/mcp-registry.env

say "Database"
db_password=$(sed -n 's/^DB_PASSWORD=//p' /etc/mcp-registry.env)
[ -n "$db_password" ] || fail "DB_PASSWORD missing from env file"
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -v pw="$db_password" -q <<'SQL'
SELECT format('CREATE ROLE mcp_registry LOGIN PASSWORD %L', :'pw')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_registry') \gexec
SELECT 'CREATE DATABASE mcp_registry OWNER mcp_registry'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'mcp_registry') \gexec
SQL

say "systemd service and release receiver"
install -m 644 /tmp/mcp-registry.service /etc/systemd/system/mcp-registry.service
install -m 755 /tmp/mcp-registry-receive /usr/local/sbin/mcp-registry-receive
rm -f /tmp/mcp-registry.service /tmp/mcp-registry-receive
systemctl daemon-reload
systemctl enable --quiet mcp-registry

if [ -f /tmp/mcp-registry-ci.pub ]; then
  say "CI deploy key (restricted to the release receiver)"
  key=$(awk '{print $1" "$2" "$3}' /tmp/mcp-registry-ci.pub)
  material=$(awk '{print $2}' /tmp/mcp-registry-ci.pub)
  install -d -m 700 /root/.ssh
  touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
  if grep -q "$material" /root/.ssh/authorized_keys; then
    echo "already authorized"
  else
    printf 'restrict,command="/usr/local/sbin/mcp-registry-receive" %s\n' "$key" >> /root/.ssh/authorized_keys
    echo "authorized"
  fi
  rm -f /tmp/mcp-registry-ci.pub
fi

if [ ! -e "/etc/nginx/sites-available/$host" ]; then
  say "nginx site for $host"
  sed -e "s/__HOST__/$host/g" -e "s/__PORT__/$port/g" /tmp/mcp-registry-nginx.conf > "/etc/nginx/sites-available/$host"
  ln -sfn "/etc/nginx/sites-available/$host" "/etc/nginx/sites-enabled/$host"
  if ! nginx -t; then
    rm -f "/etc/nginx/sites-enabled/$host"
    fail "nginx config test failed; the new site was disabled and nginx was not reloaded"
  fi
  systemctl reload nginx
else
  say "nginx site for $host already exists; leaving it unchanged"
fi
rm -f /tmp/mcp-registry-nginx.conf

if [ ! -d "/etc/letsencrypt/live/$host" ]; then
  say "HTTPS certificate for $host"
  certbot --nginx -d "$host" --non-interactive --redirect ||
    fail "certbot could not issue a certificate for $host"
fi

say "Host setup complete"
