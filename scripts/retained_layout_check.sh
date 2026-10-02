#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
mojo run -I src tests/retained_engine.mojo
mkdir -p dist
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_text.m -o native/macos_text.o
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_window.m -o native/macos_window.o
mojo build -I src \
  -Xlinker native/macos_text.o -Xlinker native/macos_window.o \
  -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText \
  tests/retained_layout.mojo -o dist/moxi-retained-layout-test
./dist/moxi-retained-layout-test
