#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
mkdir -p dist
links=(
  -Xlinker native/macos_text.o -Xlinker native/macos_window.o
  -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a -Xlinker -lc++
  -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText
)
mojo build -I src "${links[@]}" tests/layout_workbench.mojo -o dist/moxi-layout-workbench-test
dist/moxi-layout-workbench-test
mojo build -I src "${links[@]}" examples/layout_workbench.mojo -o dist/moxi-layout-workbench

# A signed bundle makes the native acceptance screen available to LaunchServices.
app="dist/Moxi Layout Workbench.app"
mkdir -p "$app/Contents/MacOS"
cp dist/moxi-layout-workbench "$app/Contents/MacOS/moxi-layout-workbench"
python3 - "$app" <<'PYPLIST'
import plistlib
import sys
from pathlib import Path
plist = {"CFBundleExecutable": "moxi-layout-workbench",
         "CFBundleIdentifier": "org.moxi.layout-workbench",
         "CFBundleName": "Moxi Layout Workbench",
         "CFBundlePackageType": "APPL", "CFBundleVersion": "1",
         "NSHighResolutionCapable": True, "NSPrincipalClass": "NSApplication"}
(Path(sys.argv[1]) / "Contents/Info.plist").write_bytes(plistlib.dumps(plist))
PYPLIST
codesign --force --sign - --timestamp=none "$app"
