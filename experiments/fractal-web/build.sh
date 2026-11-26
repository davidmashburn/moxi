#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
# An existing identical environment can be reused without installing in this checkout.
manifest="${MOXI_PIXI_MANIFEST:-$repo/pixi.toml}"
mkdir -p "$here/dist"
mojo() { pixi run --manifest-path "$manifest" mojo "$@"; }
mojo --version > "$here/dist/toolchain.txt"
clang --version >> "$here/dist/toolchain.txt"
lld_path="$(dirname "$manifest")/.pixi/envs/default/bin/lld"
"$lld_path" -flavor wasm --version >> "$here/dist/toolchain.txt"
grep -q 'Mojo 1.1.0 (8189361e)' "$here/dist/toolchain.txt" || { echo 'Unvalidated Mojo compiler'; exit 2; }
grep -q 'Apple clang version 21.0.0 (clang-2100.3.34.2)' "$here/dist/toolchain.txt" || { echo 'Unvalidated Clang compiler'; exit 2; }
grep -q '^LLD 24.0.0$' "$here/dist/toolchain.txt" || { echo 'Unvalidated Wasm linker'; exit 2; }
mojo build "$here/browser.mojo" -I "$repo/src" -I "$repo/benchmarks" -I "$repo/experiments/shared" --emit llvm -o "$here/dist/fractal.ll"
variant=fractal
case "${1:-}" in
    '') ;;
    --host-math) variant=fractal.host-math ;;
    *) echo "Usage: $0 [--host-math]" >&2; exit 2 ;;
esac
python3 "$here/../browser-moxi/retarget.py" "$here/dist/fractal.ll" "$@"
clang -target wasm64-unknown-unknown -Wno-override-module -c -O2 "$here/dist/fractal.portable.ll" -o "$here/dist/fractal.o"
exports=(create destroy preset preset_count preset_name fixture depth flags reset advance event inspect pixels text widgets widget_event paint)
symbols=()
for name in "${exports[@]}"; do symbols+=("--export=moxi_$name"); done
"$lld_path" -flavor wasm -mwasm64 --no-entry "${symbols[@]}" --export=__heap_base --allow-undefined --max-memory=67108864 "$here/dist/fractal.o" -o "$here/dist/$variant.wasm"
