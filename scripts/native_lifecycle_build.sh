#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_text.m -o dist/native-lifecycle-text.o
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_window.m -o dist/native-lifecycle-window.o
mojo build -I src -Xlinker dist/native-lifecycle-window.o -Xlinker dist/native-lifecycle-text.o -Xlinker -framework -Xlinker CoreText -Xlinker -framework -Xlinker Cocoa examples/native_lifecycle_workbench.mojo -o dist/moxi-native-lifecycle
app=dist/MoxiLifecycle.app
mkdir -p "$app/Contents/MacOS"
cp dist/moxi-native-lifecycle "$app/Contents/MacOS/MoxiLifecycle"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MoxiLifecycle</string>
<key>CFBundleIdentifier</key><string>org.moxi.lifecycle</string>
<key>CFBundleName</key><string>MoxiLifecycle</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
