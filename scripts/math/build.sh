#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="${MOXI_D02_BUILD_DIR:-/tmp/moxi-d02}"
hb="${MOXI_HARFBUZZ_PREFIX:-/opt/homebrew/opt/harfbuzz}"
mkdir -p "$work"
cd "$repo"
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_window.m -o "$work/window.o" > "$work/window-build.log" 2>&1
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -I "$hb/include/harfbuzz" -c native/math/font.m -o "$work/font.o" > "$work/font-build.log" 2>&1
for name in workbench consumer; do
  pixi run --frozen mojo build -I src "examples/math/$name.mojo" -Xlinker "$work/window.o" -Xlinker "$work/font.o" -Xlinker "$hb/lib/libharfbuzz.dylib" -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText -o "$work/$name" > "$work/$name-build.log" 2>&1
done
printf 'Built native math workbench and public consumer in %s\n' "$work"
