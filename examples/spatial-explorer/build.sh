#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/spatial-explorer/build.sh "$@"; fi
mkdir -p dist/spatial-explorer
cflags=(-O2 -Wall -Wextra -Werror)
clang++ -std=c++20 "${cflags[@]}" -c native/spatial/core.cpp -o dist/spatial-explorer/core.o
clang++ -std=c++20 "${cflags[@]}" -c native/spatial/api.cpp -o dist/spatial-explorer/api.o
clang "${cflags[@]}" -fobjc-arc -fmodules -c native/spatial/renderer.m -o dist/spatial-explorer/renderer.o
clang "${cflags[@]}" -fobjc-arc -fmodules -c examples/spatial-explorer/host.m -o dist/spatial-explorer/host.o
clang "${cflags[@]}" -fobjc-arc -fmodules -c native/macos_text.m -o dist/spatial-explorer/text.o
clang "${cflags[@]}" -fobjc-arc -fmodules -c native/macos_window.m -o dist/spatial-explorer/window.o
ar rcs dist/spatial-explorer/libmoxi_spatial.a dist/spatial-explorer/core.o dist/spatial-explorer/api.o dist/spatial-explorer/renderer.o
mojo precompile -I src src/moxi_spatial -o dist/spatial-explorer/moxi_spatial.mojoc
link=()
for name in core api renderer host text; do link+=(-Xlinker "dist/spatial-explorer/$name.o"); done
for framework in Cocoa CoreText Metal QuartzCore; do link+=(-Xlinker -framework -Xlinker "$framework"); done
mojo build -I src "${link[@]}" -Xlinker -lc++ examples/spatial-explorer/main.mojo -o dist/spatial-explorer/explorer
mkdir -p dist/MoxiSpatial.app/Contents/MacOS
cp dist/spatial-explorer/explorer dist/MoxiSpatial.app/Contents/MacOS/MoxiSpatial
cat > dist/MoxiSpatial.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>MoxiSpatial</string><key>CFBundleIdentifier</key><string>org.moxi.spatial.experiment</string><key>CFBundleName</key><string>MoxiSpatial</string><key>CFBundlePackageType</key><string>APPL</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
printf 'Built dist/spatial-explorer/explorer and dist/MoxiSpatial.app\n'
