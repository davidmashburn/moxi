#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/inspectable-transforms/build.sh "$@"; fi
out=dist/inspectable-transforms
mkdir -p "$out"
cflags=(-O2 -Wall -Wextra -Werror)
clang++ -std=c++20 "${cflags[@]}" -c native/spatial/core.cpp -o "$out/core.o"
clang++ -std=c++20 "${cflags[@]}" -c native/spatial/api.cpp -o "$out/api.o"
clang "${cflags[@]}" -fobjc-arc -fmodules -c native/spatial/renderer.m -o "$out/renderer.o"
clang "${cflags[@]}" -fobjc-arc -fmodules -c examples/inspectable-transforms/host.m -o "$out/host.o"
clang "${cflags[@]}" -fobjc-arc -fmodules -c native/macos_text.m -o "$out/text.o"
link=()
for name in core api renderer host text; do link+=(-Xlinker "$out/$name.o"); done
for framework in Cocoa CoreText Metal QuartzCore; do link+=(-Xlinker -framework -Xlinker "$framework"); done
mojo build -I src "${link[@]}" -Xlinker -lc++ examples/inspectable-transforms/main.mojo -o "$out/transforms"
printf 'Built %s/transforms; run with canvas or spatial\n' "$out"
