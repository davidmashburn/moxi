#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "$app_dir/../.." && pwd)"
mkdir -p "$app_dir/dist"
cc -O3 -Wall -Wextra -Werror -c "$app_dir/native/export.c" -o "$app_dir/dist/export.o"
pixi run --manifest-path "$repo/pixi.toml" mojo build -I "$repo/src" -I "$app_dir/src" \
  -Xlinker "$app_dir/dist/export.o" "$app_dir/tests/test_export.mojo" -o "$app_dir/dist/test-export"
"$app_dir/dist/test-export"
