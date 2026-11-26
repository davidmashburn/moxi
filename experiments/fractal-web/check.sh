#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
# Match scalar Wasm rounding in the native image oracle.
pixi run --manifest-path "${MOXI_PIXI_MANIFEST:-$repo/pixi.toml}" bash "$repo/scripts/build_native_demo.sh" \
    -I "$repo/src" -I "$repo/benchmarks" --fp-mode contract=off "$here/native.mojo" -o "$here/dist/native-check"
"$here/dist/native-check" "$here/dist"
node "$here/check.mjs"
