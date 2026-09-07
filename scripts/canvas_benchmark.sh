#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-canvas-benchmark.XXXXXX")"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

/usr/bin/time -l pixi run canvas-scene >"$tmp_dir/output" 2>"$tmp_dir/time"
cat "$tmp_dir/output"

commands="$(awk -F':  ' '/Moxi canvas scene commands/ {print $2}' "$tmp_dir/output")"
fallbacks="$(awk -F':  ' '/Moxi canvas scene fallbacks/ {print $2}' "$tmp_dir/output")"
checksum="$(awk -F':  ' '/Moxi canvas scene checksum/ {print $2}' "$tmp_dir/output")"
wall_seconds="$(awk '/real / {print $1}' "$tmp_dir/time" | tail -n 1)"
max_rss_bytes="$(awk '/maximum resident set size/ {print $1}' "$tmp_dir/time" | tail -n 1)"
png_bytes="$(stat -f%z /tmp/moxi-canvas-scene.png)"
expected_checksum="$(awk -F'\t' '$1 == "plot-gallery" {print $7}' tests/canvas_scene_checksums.tsv)"

if [[ "$checksum" != "$expected_checksum" ]]; then
    echo "canvas benchmark checksum drifted: expected $expected_checksum, got $checksum" >&2
    exit 1
fi

echo "canvas_scene_wall_seconds: $wall_seconds"
echo "canvas_scene_peak_rss_bytes: $max_rss_bytes"
echo "canvas_scene_png_bytes: $png_bytes"
echo "canvas_scene_commands: $commands"
echo "canvas_scene_fallbacks: $fallbacks"
echo "canvas_scene_checksum: $checksum"
