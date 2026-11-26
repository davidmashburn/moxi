#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/../.."
dest=dist/lived-spaces
mkdir -p "$dest"
clang++ -std=c++20 -Wall -Wextra -Werror -O2 -fobjc-arc examples/lived-spaces/window.mm native/spatial/core.cpp -framework Cocoa -o "$dest/exhibition"
exec "$dest/exhibition" "$@"
