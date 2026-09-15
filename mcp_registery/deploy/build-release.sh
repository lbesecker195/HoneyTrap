#!/bin/sh
# Builds a linux/amd64 Phoenix release with the project Dockerfile and packs it
# as a tarball. Prints the tarball path on stdout; build output goes to stderr.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/_build/deploy"
mkdir -p "$out"

docker buildx build --platform linux/amd64 -t mcp-registry:amd64 --load "$root" >&2

tarball="$out/mcp_registry-$(date -u +%Y%m%d%H%M%S).tar.gz"
# Pack inside Linux: macOS tar embeds Apple metadata that GNU tar cannot extract.
docker run --rm --platform linux/amd64 --entrypoint tar mcp-registry:amd64 -C /app -czf - . > "$tarball"
echo "$tarball"
