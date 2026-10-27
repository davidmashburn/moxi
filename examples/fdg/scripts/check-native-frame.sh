#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
moxi_source="${MOXI_SOURCE_DIR:-$app_dir/../..}"
moxi_dir="$(cd "$moxi_source" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-fdg-frame.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules -I "$moxi_dir/native" \
  -c "$app_dir/tests/native_frame_probe.m" -o "$work_dir/host.o"
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c "$app_dir/native/save_panel.m" -o "$work_dir/save.o"
pixi run --manifest-path "$moxi_dir/pixi.toml" mojo build \
  -I "$moxi_dir/src" -I "$app_dir/src" "$app_dir/tests/test_native_frame.mojo" \
  -Xlinker "$work_dir/host.o" -Xlinker "$work_dir/save.o" \
  -Xlinker -framework -Xlinker Cocoa \
  -Xlinker -framework -Xlinker UniformTypeIdentifiers \
  -o "$work_dir/test-frame"
"$work_dir/test-frame"
