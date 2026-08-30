#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-package.XXXXXX")"
consumer_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-consumer.XXXXXX")"
cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-pixi-cache.XXXXXX")"

cleanup() {
    rm -rf "$package_dir" "$consumer_dir" "$cache_dir"
}
trap cleanup EXIT

pixi publish --clean --path "$repo_dir/pixi.toml" --target-dir "$package_dir"
archive="$(find "$package_dir" -type f -name 'moxi-*.conda' -print -quit)"
if [[ -z "$archive" ]]; then
    echo "package build did not produce a moxi .conda archive" >&2
    exit 1
fi

pixi init \
    --format pixi \
    --platform osx-arm64 \
    --channel https://conda.modular.com/max-nightly \
    --channel conda-forge \
    "$consumer_dir"

PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
    pixi add --manifest-path "$consumer_dir/pixi.toml" "$archive"
PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
    pixi run --manifest-path "$consumer_dir/pixi.toml" \
    mojo run "$repo_dir/tests/package_consumer.mojo"
