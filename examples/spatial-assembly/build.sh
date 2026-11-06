#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/spatial-assembly/build.sh "$@"; fi
# D06 is the shared library build, and remains a required regression consumer.
bash examples/spatial-explorer/build.sh
mkdir -p dist/spatial-assembly
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c examples/spatial-assembly/host.m -o dist/spatial-assembly/host.o
link=(-Xlinker dist/spatial-assembly/host.o)
for name in core api renderer text; do link+=(-Xlinker "dist/spatial-explorer/$name.o"); done
for framework in Cocoa CoreText Metal QuartzCore; do link+=(-Xlinker -framework -Xlinker "$framework"); done
mojo build -I src "${link[@]}" -Xlinker -lc++ examples/spatial-assembly/main.mojo -o dist/spatial-assembly/assembly
printf 'Built dist/spatial-assembly/assembly\n'
