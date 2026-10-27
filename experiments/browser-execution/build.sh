#!/usr/bin/env bash
set -euo pipefail
probe_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$probe_dir/../.." && pwd)"
mkdir -p "$probe_dir/dist"
cd "$repo_dir"
pixi run mojo --version
clang --version | head -n 1
pixi run mojo build "$probe_dir/fdg.mojo" -I examples/fdg/src --emit llvm -o "$probe_dir/dist/fdg.ll"
python3 "$probe_dir/retarget.py" "$probe_dir/dist/fdg.ll"
clang -target wasm64-unknown-unknown -c -O2 "$probe_dir/dist/fdg.portable.ll" -o "$probe_dir/dist/fdg.o"
# Undefined imports are intentional and enumerated by the runtime. Error-path
# imports throw rather than pretending that the Modular runtime is implemented.
.pixi/envs/default/bin/lld -flavor wasm -mwasm64 --no-entry --export=fdg_probe --export=__heap_base --allow-undefined "$probe_dir/dist/fdg.o" -o "$probe_dir/dist/fdg.wasm"
pixi run mojo run -I examples/fdg/src "$probe_dir/fdg.mojo" > "$probe_dir/dist/native.txt"
pixi run mojo build "$probe_dir/persistent.mojo" -I examples/fdg/src --emit llvm -o "$probe_dir/dist/persistent.ll"
python3 "$probe_dir/retarget.py" "$probe_dir/dist/persistent.ll"
clang -target wasm64-unknown-unknown -c -O2 "$probe_dir/dist/persistent.portable.ll" -o "$probe_dir/dist/persistent.o"
.pixi/envs/default/bin/lld -flavor wasm -mwasm64 --no-entry --export=fdg_create --export=fdg_destroy --export=fdg_step --export=fdg_pin --export=fdg_release --export=fdg_coordinate --export=__heap_base --allow-undefined "$probe_dir/dist/persistent.o" -o "$probe_dir/dist/persistent.wasm"
pixi run mojo run -I examples/fdg/src "$probe_dir/persistent.mojo" > "$probe_dir/dist/persistent-native.txt"
node "$probe_dir/check.mjs"
node "$probe_dir/persistent-check.mjs"
