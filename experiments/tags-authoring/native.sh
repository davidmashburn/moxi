#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
node experiments/tags-authoring/compile.cjs
pixi run --locked native-object
app='experiments/tags-authoring/generated/Moxi Tags Experiment.app'
mkdir -p "$app/Contents/MacOS"
pixi run --locked mojo build -I src -I experiments/tags-authoring -I experiments/tags-authoring/generated \
  -Xlinker native/macos_window.o -Xlinker -framework -Xlinker Cocoa \
  experiments/tags-authoring/demo.mojo -o "$app/Contents/MacOS/moxi-tags"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>moxi-tags</string>
<key>CFBundleIdentifier</key><string>org.moxi.tags-experiment</string>
<key>CFBundleName</key><string>Moxi Tags Experiment</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ "${1:-}" != '--build-only' ]]; then open "$app"; fi
