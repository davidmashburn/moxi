#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
manifest="${MOXI_PIXI_MANIFEST:-$repo/pixi.toml}"
mkdir -p "$here/dist"
mojo() { pixi run --manifest-path "$manifest" mojo "$@"; }
mojo --version > "$here/dist/toolchain.txt"
clang --version >> "$here/dist/toolchain.txt"
lld_path="$(dirname "$manifest")/.pixi/envs/default/bin/lld"
"$lld_path" -flavor wasm --version >> "$here/dist/toolchain.txt"
grep -q 'Mojo 1.1.0 (8189361e)' "$here/dist/toolchain.txt" || exit 2
grep -q 'Apple clang version 21.0.0 (clang-2100.3.34.2)' "$here/dist/toolchain.txt" || exit 2
grep -q '^LLD 24.0.0$' "$here/dist/toolchain.txt" || exit 2
mojo build "$here/density.mojo" -I "$repo/src" --emit llvm -o "$here/dist/density.ll"
python3 "$repo/experiments/browser-moxi/retarget.py" "$here/dist/density.ll"
clang -target wasm64-unknown-unknown -c -O2 "$here/dist/density.portable.ll" -o "$here/dist/density.o"
"$lld_path" -flavor wasm -mwasm64 --no-entry --export=moxi_create --export=moxi_destroy --export=moxi_resize --export=moxi_event --export=moxi_render --export=moxi_inspect --export=moxi_grid --export=moxi_count --export=moxi_status --export=moxi_exact --export=__heap_base --allow-undefined --max-memory=67108864 "$here/dist/density.o" -o "$here/dist/density.wasm"
mojo run -I "$repo/src" "$here/native.mojo" > "$here/dist/native.svg"
node "$here/wasm-check.mjs" > "$here/dist/wasm-check.json"
