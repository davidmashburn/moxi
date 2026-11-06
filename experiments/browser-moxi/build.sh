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
mojo build --print-supported-targets > "$here/dist/targets.txt" 2>&1
set +e
mojo build "$here/target.mojo" --target-triple wasm64-unknown-unknown -o "$here/dist/direct.wasm" > "$here/dist/direct-target.log" 2>&1
direct_status=$?
set -e
printf '%s\n' "$direct_status" > "$here/dist/direct-target.status"
mojo build "$here/browser.mojo" -I "$repo/src" -I "$repo/examples/fdg/src" --emit llvm -o "$here/dist/browser.ll"
python3 "$here/retarget.py" "$here/dist/browser.ll"
clang -target wasm64-unknown-unknown -c -O2 "$here/dist/browser.portable.ll" -o "$here/dist/browser.o"
"$lld_path" -flavor wasm -mwasm64 --no-entry --export=moxi_create --export=moxi_destroy --export=moxi_event --export=moxi_resize --export=moxi_render --export=moxi_inspect --export=__heap_base --allow-undefined --max-memory=67108864 "$here/dist/browser.o" -o "$here/dist/browser.wasm"
mojo run -I "$repo/src" -I "$repo/examples/fdg/src" "$here/native.mojo" "$here/dist" > "$here/dist/native.txt"
python3 "$here/test_retarget.py"
clang -target wasm64-unknown-unknown -c -O2 "$here/dist/runtime-test.ll" -o "$here/dist/runtime-test.o"
"$lld_path" -flavor wasm -mwasm64 --no-entry --export=moxi_table --export=moxi_float32 --export=moxi_multiply --export=moxi_fail --export=__heap_base --allow-undefined --max-memory=67108864 "$here/dist/runtime-test.o" -o "$here/dist/runtime-test.wasm"
node "$here/runtime-check.mjs" > "$here/dist/runtime-check.json"
node "$here/check.mjs" > "$here/dist/check.json"
cat "$here/dist/check.json"
