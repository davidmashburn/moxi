#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/spatial-world-panel/build.sh "$@"; fi
bash examples/spatial-explorer/build.sh
mkdir -p dist/spatial-world-panel
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c examples/spatial-world-panel/host.m -o dist/spatial-world-panel/host.o
link=(-Xlinker dist/spatial-world-panel/host.o -Xlinker dist/spatial-explorer/libmoxi_spatial.a -Xlinker dist/spatial-explorer/text.o)
for framework in Cocoa CoreText Metal QuartzCore; do link+=(-Xlinker -framework -Xlinker "$framework"); done
mojo build -I src "${link[@]}" -Xlinker -lc++ examples/spatial-world-panel/main.mojo -o dist/spatial-world-panel/panel
