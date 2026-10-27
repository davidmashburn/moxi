#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
moxi_source="${MOXI_SOURCE_DIR:-$app_dir/../..}"
moxi_dir="$(cd "$moxi_source" && pwd)"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'Native build requires macOS ARM64' >&2; exit 1; }
mkdir -p "$app_dir/dist"
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c "$moxi_dir/native/macos_window.m" -o "$app_dir/dist/macos_window.o"
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c "$app_dir/native/save_panel.m" -o "$app_dir/dist/save_panel.o"
pixi run --manifest-path "$moxi_dir/pixi.toml" mojo build \
  -I "$moxi_dir/src" -I "$app_dir/src" "$app_dir/src/main.mojo" \
  -Xlinker "$app_dir/dist/macos_window.o" -Xlinker "$app_dir/dist/save_panel.o" \
  -Xlinker -framework -Xlinker Cocoa \
  -Xlinker -framework -Xlinker UniformTypeIdentifiers \
  -o "$app_dir/dist/moxi-fdg"
bundle="$app_dir/dist/Moxi Force Graph.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$app_dir/dist/moxi-fdg" "$bundle/Contents/MacOS/moxi-fdg"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>moxi-fdg</string>
<key>CFBundleIdentifier</key><string>org.moxi.fdg</string>
<key>CFBundleName</key><string>Moxi Force Graph</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
git -C "$moxi_dir" rev-parse HEAD > "$app_dir/dist/moxi-revision.txt"
printf 'Built %s\n' "$bundle"
