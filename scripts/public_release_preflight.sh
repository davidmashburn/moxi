#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if [[ -z "${MOXI_PUBLIC_CHANNEL:-}" ]]; then
    echo "MOXI_PUBLIC_CHANNEL is required (for example https://prefix.dev/<channel>)" >&2
    exit 2
fi
if [[ "$MOXI_PUBLIC_CHANNEL" == file://* || "$MOXI_PUBLIC_CHANNEL" != *://* ]]; then
    echo "MOXI_PUBLIC_CHANNEL must be a remote channel URL, not a local filesystem target" >&2
    exit 2
fi
if [[ -z "${PIXI_AUTH_FILE:-}" ]]; then
    echo "PIXI_AUTH_FILE is required; no credentials are read from the repository" >&2
    exit 2
fi
if [[ ! -f "$PIXI_AUTH_FILE" ]]; then
    echo "PIXI_AUTH_FILE does not exist: $PIXI_AUTH_FILE" >&2
    exit 2
fi

echo "Public release preflight for $MOXI_PUBLIC_CHANNEL"
for target in osx-arm64 linux-64; do
    echo "==> $target"
    pixi publish \
        --dry-run \
        --target-platform "$target" \
        --target-channel "$MOXI_PUBLIC_CHANNEL" \
        --auth-file "$PIXI_AUTH_FILE"
    pixi publish \
        --dry-run \
        --path packages/moxi_plot/pixi.toml \
        --target-platform "$target" \
        --target-channel "$MOXI_PUBLIC_CHANNEL" \
        --auth-file "$PIXI_AUTH_FILE"
done
echo "Preflight passed; no package was uploaded"
