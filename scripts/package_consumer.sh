#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-package-channel.XXXXXX")"
consumer_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-consumer.XXXXXX")"
cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-pixi-cache.XXXXXX")"
build_cache_dir="$repo_dir/.pixi/bld"

cleanup() {
    rm -rf "$package_dir" "$consumer_dir" "$cache_dir"
}
trap cleanup EXIT

pixi publish --clean --target-channel "$package_dir"
archive="$(find "$package_dir" -type f -name 'moxi-*.conda' -print -quit)"
if [[ -z "$archive" ]]; then
    echo "package build did not produce a moxi .conda archive" >&2
    exit 1
fi
canvas_archive="$(find "$package_dir" -type f -name 'canvas_mojo-*.conda' -print -quit)"
if [[ -z "$canvas_archive" ]]; then
    echo "workspace publish did not produce the canvas_mojo runtime archive" >&2
    exit 1
fi

# The package build can be much larger than the local consumer environment.
# Drop only Pixi's generated build cache before materializing the consumer.
if [[ -d "$build_cache_dir" ]]; then
    find "$build_cache_dir" -mindepth 1 -depth -delete
fi

pixi init \
    --format pixi \
    --platform osx-arm64 \
    --channel "file://$package_dir" \
    --channel https://conda.modular.com/max-nightly \
    --channel conda-forge \
    "$consumer_dir"

PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
    pixi add --manifest-path "$consumer_dir/pixi.toml" "moxi==0.6.0"
PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
    pixi run --manifest-path "$consumer_dir/pixi.toml" \
    mojo run "$repo_dir/tests/package_consumer.mojo"
