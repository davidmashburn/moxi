#!/usr/bin/env bash
# Run inside the repository's Mojo environment on a macOS GUI/Metal host.
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d "${TMPDIR:-/tmp}/moxi-spatial-sanitizers.XXXXXX")
echo "Build, logs and transient replay captures: $out"
command -v mojo >/dev/null
san=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
objc=(-fobjc-arc -fmodules)
runtime_dir="$(clang -print-resource-dir)/lib/darwin"
asan="$runtime_dir/libclang_rt.asan_osx_dynamic.dylib"
frameworks=(-framework Cocoa -framework CoreText -framework Metal -framework QuartzCore)

for unit in core api; do
  clang++ -std=c++20 "${san[@]}" -c "native/spatial/$unit.cpp" -o "$out/$unit.o"
done
clang "${san[@]}" "${objc[@]}" -c native/spatial/renderer.m -o "$out/renderer.o"
clang "${san[@]}" "${objc[@]}" -c native/macos_text.m -o "$out/text.o"
common=("$out/core.o" "$out/api.o" "$out/renderer.o" "$out/text.o")
# Mojo drives the final link. Apple Clang's combined ASan runtime also
# supplies the UBSan handlers. Preload it before the Mojo runtime starts.
export ASAN_OPTIONS=detect_leaks=0:halt_on_error=1
export UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1
for demo in explorer assembly; do
  src="examples/spatial-$demo"
  clang "${san[@]}" "${objc[@]}" -c "$src/host.m" -o "$out/$demo-host.o"
  link=()
  for arg in "${common[@]}" "$out/$demo-host.o" "$asan" -rpath "$runtime_dir" "${frameworks[@]}" -lc++; do
    link+=(-Xlinker "$arg")
  done
  mojo build -I src "${link[@]}" "$src/main.mojo" -o "$out/$demo"
  mkdir "$out/$demo-frames"
  for round in 1 2 3; do
    log="$out/$demo-$round.log"
    DYLD_INSERT_LIBRARIES="$asan" "$out/$demo" --replay "$out/$demo-frames" >"$log" 2>&1
    grep -E '^PASS (assembly native public|native public Mojo) replay' "$log"
  done
done

clang "${san[@]}" "${objc[@]}" -c tests/spatial/resize_close.m -o "$out/resize-close.o"
clang++ "${san[@]}" "${common[@]}" "$out/resize-close.o" "${frameworks[@]}" -o "$out/resize-close"
"$out/resize-close" >"$out/resize-close.log" 2>&1
cat "$out/resize-close.log"
