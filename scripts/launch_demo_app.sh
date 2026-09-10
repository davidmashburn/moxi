#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "the Moxi Playground app bundle requires macOS" >&2
  exit 1
fi

app_bundle="$repo_dir/dist/Moxi Playground.app"
app_contents="$app_bundle/Contents"
app_executable="$app_contents/MacOS/moxi-demo-walkthrough"

mkdir -p "$app_contents/MacOS"
cp native/moxi_demo_Info.plist "$app_contents/Info.plist"
cp dist/moxi-demo-walkthrough "$app_executable"
chmod +x "$app_executable"

# Launch through LaunchServices so the bundle's application identity is
# visible to Accessibility clients. -W keeps the Pixi task attached until
# the walkthrough closes; -n permits a fresh deterministic run.
exec /usr/bin/open -n -W "$app_bundle"
