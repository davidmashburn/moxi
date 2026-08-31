#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c native/macos_window.m -o native/macos_window.o
mkdir -p dist
mojo build -I src -I examples \
  -Xlinker native/macos_window.o \
  -Xlinker -framework -Xlinker Cocoa \
  -Xlinker -export_dynamic \
  tests/live_reload.mojo -o dist/moxi-live-reload-check
./dist/moxi-live-reload-check
