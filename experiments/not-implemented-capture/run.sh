#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
[[ "$(uname -s)" == Darwin ]] || { echo 'AppKit capture requires macOS' >&2; exit 1; }
output="${1:-$repo/artifacts/demo-slideshows/not-implemented}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
build="$(mktemp -d /tmp/moxi-n01-capture.XXXXXX)"
trap 'rm -rf "$build"' EXIT
clang -O2 -fobjc-arc -fmodules -c "$here/capture.m" -o "$build/capture.o"
pixi run --manifest-path "$repo/pixi.toml" --frozen mojo build -I "$repo/src" \
  -Xlinker "$build/capture.o" -Xlinker -framework -Xlinker Cocoa \
  "$here/capture.mojo" -o "$build/capture"
"$build/capture" "$output"
python3 "$here/manifest.py" "$output"
