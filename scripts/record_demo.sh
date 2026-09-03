#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if [[ $# -gt 1 ]]; then
  echo "usage: pixi run demo-record [output.mov]" >&2
  exit 2
fi

duration="${MOXI_RECORD_SECONDS:-30}"
if [[ ! "$duration" =~ ^[0-9]+$ ]] || (( duration < 1 || duration > 300 )); then
  echo "MOXI_RECORD_SECONDS must be an integer from 1 to 300" >&2
  exit 2
fi

output_path="${1:-output/moxi-capability-bus-walkthrough-30s.mov}"
if [[ "$output_path" != /* ]]; then
  output_path="$repo_dir/$output_path"
fi

if ! command -v pixi >/dev/null 2>&1; then
  echo "pixi is required to build the walkthrough" >&2
  exit 1
fi
for command_name in clang screencapture ffprobe ffmpeg; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required to record the demo" >&2
    exit 1
  fi
done

mkdir -p "$repo_dir/dist" "$(dirname "$output_path")"
pixi run demo-walkthrough-build
clang \
  -O2 -Wall -Wextra -Werror \
  native/macos_window_bounds.c \
  -o "$repo_dir/dist/moxi-window-bounds" \
  -framework CoreGraphics \
  -framework Foundation

window_helper="$repo_dir/dist/moxi-window-bounds"
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-demo-record.XXXXXX")"
record_app="$run_dir/MoxiDemoRecorder.app"
record_log="$run_dir/demo.log"
demo_pid=""

cleanup() {
  local status=$?
  if [[ -n "$demo_pid" ]] && kill -0 "$demo_pid" 2>/dev/null; then
    kill "$demo_pid" 2>/dev/null || true
    for _ in {1..20}; do
      if ! kill -0 "$demo_pid" 2>/dev/null; then
        break
      fi
      sleep 0.1
    done
    kill -KILL "$demo_pid" 2>/dev/null || true
    wait "$demo_pid" 2>/dev/null || true
  fi
  rm -rf -- "$run_dir"
  exit "$status"
}
trap cleanup EXIT INT TERM

mkdir -p "$record_app/Contents/MacOS"
cp native/moxi_demo_recorder_Info.plist "$record_app/Contents/Info.plist"
cp dist/moxi-demo-walkthrough "$record_app/Contents/MacOS/moxi-demo-recorder"
chmod +x "$record_app/Contents/MacOS/moxi-demo-recorder"

rm -f -- "$output_path"
/usr/bin/open -n "$record_app" >"$record_log" 2>&1

window_info=""
deadline=$(( $(date +%s) + 20 ))
while (( $(date +%s) < deadline )); do
  candidate=""
  if candidate="$($window_helper --owner MoxiDemoRecorder --title "Moxi Playground" 2>/dev/null)"; then
    window_info="$candidate"
    break
  fi
  sleep 0.1
done

if [[ -z "$window_info" ]]; then
  echo "Moxi Playground did not become visible" >&2
  sed -n '1,120p' "$record_log" >&2 || true
  exit 1
fi

read -r demo_pid window_id x y width height <<<"$window_info"
if (( width < 100 || height < 100 )); then
  echo "Moxi Playground reported an invalid window size: $window_info" >&2
  exit 1
fi

# Let the first normal frame settle while the newly opened app remains
# frontmost. Region capture preserves the ordinary title bar without the
# black overlay produced by window-id capture.
sleep 0.25
echo "Recording Moxi Playground window $window_id at $x,$y ${width}x${height} for ${duration}s"
screencapture \
  "-R${x},${y},${width},${height}" \
  -o -v "-V${duration}" -C -x "$output_path"

codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$output_path")"
width_px="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$output_path")"
height_px="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$output_path")"
frame_rate="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$output_path")"
actual_duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$output_path")"

if [[ "$codec" != "h264" || "$frame_rate" != "60/1" ]]; then
  echo "Unexpected video stream: codec=$codec frame_rate=$frame_rate" >&2
  exit 1
fi
if (( width_px < 1 || height_px < 1 )); then
  echo "Video has invalid dimensions: ${width_px}x${height_px}" >&2
  exit 1
fi
if ! awk -v actual="$actual_duration" -v expected="$duration" \
  'BEGIN { difference = actual - expected; if (difference < 0) difference = -difference; exit !(difference <= 0.25) }'; then
  echo "Unexpected video duration: $actual_duration (expected about $duration)" >&2
  exit 1
fi

# Decode one frame so a successful capture cannot be a zero-byte or malformed
# container. Semantic visual review remains a separate human check.
ffmpeg -y -loglevel error -i "$output_path" -frames:v 1 "$run_dir/first-frame.png"
echo "Recorded $output_path"
echo "  duration=${actual_duration}s codec=${codec} size=${width_px}x${height_px} fps=${frame_rate}"
