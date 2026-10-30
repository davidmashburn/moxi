#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
pixi run --locked native-object
app='experiments/child-routing/generated/Moxi Shared Child Experiment.app'
mkdir -p "$app/Contents/MacOS"
pixi run --locked mojo build -I src -I experiments/handler-api -I experiments/child-routing \
  -Xlinker native/macos_window.o -Xlinker -framework -Xlinker Cocoa \
  experiments/child-routing/demo.mojo -o "$app/Contents/MacOS/moxi-child-routing"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>moxi-child-routing</string>
<key>CFBundleIdentifier</key><string>org.moxi.child-routing-experiment</string>
<key>CFBundleName</key><string>Moxi Shared Child Experiment</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ "${1:-}" != '--build-only' ]]; then open "$app"; fi
