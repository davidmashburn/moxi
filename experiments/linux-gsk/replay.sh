#!/usr/bin/env bash
set -euo pipefail
# Run in a fresh Xvfb session; this window manager belongs only to the replay.
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?supply a new output directory}
mkdir "$out"
openbox --config-file "$here/../../scripts/linux_ui_openbox.xml" >"$out/openbox.log" 2>&1 &
wm=$!
trap 'kill "$wm" 2>/dev/null || true' EXIT
for mode in oracle ngl fallback scale2; do
    python3 "$here/capture.py" "$out" "$mode"
done
