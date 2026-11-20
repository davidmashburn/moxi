#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-live-editor-check.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c native/macos_window.m -o "$build_dir/macos_window.o"
mojo build -I src \
  -Xlinker "$build_dir/macos_window.o" \
  -Xlinker -framework -Xlinker Cocoa -Xlinker -export_dynamic \
  tests/live_editor.mojo -o "$build_dir/live-editor-check"
"$build_dir/live-editor-check"
