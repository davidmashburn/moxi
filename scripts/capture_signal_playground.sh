#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required to convert native frames to PNG" >&2; exit 1; }
output="artifacts/signal-playground"
mkdir -p "$output"
./dist/moxi-signal-playground-capture
python3 scripts/check_signal_playground.py
for frame in 01-sine 02-drag 03-triangle 04-pulse; do
  ffmpeg -v error -y -i "$output/$frame.ppm" -frames:v 1 "$output/$frame.png"
  ffmpeg -v error -y -loop 1 -framerate 10 -i "$output/$frame.png" -i "$output/$frame.wav" -c:v libx264 -pix_fmt yuv420p -c:a aac -af apad -t 4 "$output/$frame.mp4"
done
ffmpeg -v error -y -f concat -safe 0 -i "$output/sequence.txt" -c copy -movflags +faststart "$output/walkthrough.mp4"
echo "Native frames and matching audio: $repo_dir/$output/index.html"
