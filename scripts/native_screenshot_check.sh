#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

artifact_dir="${MOXI_NATIVE_SCREENSHOT_DIR:-$repo_dir/dist/native-artifacts}"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$artifact_dir"

./dist/moxi-native-scene-parity > "$temp_dir/native-scene.txt"
if rg -q '^NATIVE_SCREENSHOT_SKIPPED$' "$temp_dir/native-scene.txt"; then
  echo "Moxi native screenshot check skipped: Metal unavailable"
  exit 0
fi

MOXI_NATIVE_SCREENSHOT_OUTPUT="$temp_dir/native-scene.txt" \
MOXI_NATIVE_SCREENSHOT_ACTUAL="$artifact_dir/native-scene.ppm" \
MOXI_NATIVE_SCREENSHOT_POLICY="$repo_dir/tests/native-screenshot-policy.json" \
MOXI_NATIVE_SCREENSHOT_REPORT="$artifact_dir/native-scene-report.json" \
python3 "$repo_dir/scripts/native_screenshot_compare.py"
