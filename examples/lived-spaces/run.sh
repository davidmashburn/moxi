#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/../.."
dest=dist/lived-spaces
mkdir -p "$dest"
if [[ "${1:-}" == "--check-model" && "$#" == 1 ]]; then
  clang++ -std=c++20 -Wall -Wextra -Werror -O2 examples/lived-spaces/preview_check.cpp native/spatial/core.cpp -o "$dest/preview-check"
  exec "$dest/preview-check"
fi
clang++ -std=c++20 -Wall -Wextra -Werror -O2 -fobjc-arc examples/lived-spaces/window.mm native/spatial/core.cpp -framework Cocoa -o "$dest/exhibition"
exec "$dest/exhibition" "$@"
