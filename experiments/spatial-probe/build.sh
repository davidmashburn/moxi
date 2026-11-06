#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p dist/spatial-probe
candidate=${1:-comparison}
frameworks=(-framework Cocoa -framework CoreText -framework Metal -framework QuartzCore)
defines=()
case "$candidate" in
  comparison) defines=(-DSP_SCENEKIT=1); frameworks+=(-framework SceneKit) ;;
  bridge) defines=(-DSP_SCENEKIT=0) ;;
  *) echo 'Usage: build.sh [comparison|bridge]' >&2; exit 2 ;;
esac
clang -O2 -Wall -Wextra -Werror -Wno-deprecated-declarations -fobjc-arc -fmodules "${defines[@]}" \
  experiments/spatial-probe/renderer.m experiments/spatial-probe/probe.m \
  "${frameworks[@]}" -o "dist/spatial-probe/$candidate"
