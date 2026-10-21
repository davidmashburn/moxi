#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$repo_dir/dist/Moxi Signal Playground.app"
mkdir -p "$app/Contents/MacOS"
cp "$repo_dir/native/signal_playground_Info.plist" "$app/Contents/Info.plist"
cp "$repo_dir/dist/moxi-signal-playground" "$app/Contents/MacOS/moxi-signal-playground"
exec /usr/bin/open -n -W "$app"
