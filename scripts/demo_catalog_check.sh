#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

catalog_file="src/moxi/demo_browser.mojo"

while IFS= read -r source; do
  if [[ ! -f "$source" ]]; then
    echo "demo catalog references missing source: $source" >&2
    exit 1
  fi
done < <(rg -o 'examples/[A-Za-z0-9_]+\.mojo' "$catalog_file" | sort -u)

for task in \
  demo \
  live-script-demo \
  hello-window-demo \
  component-demo \
  counter-demo \
  form-demo \
  nested-demo \
  composed-demo \
  wx-style-demo \
  row-demo \
  alignment-demo \
  wrapped-text-demo \
  animation-demo \
  plot-demo \
  plot-gallery \
  plot-svg \
  interactive-fractal-demo \
  metal-demo \
  metal-window-demo \
  text-demo \
  harfbuzz-demo
do
  if ! rg -q "^[[:space:]]*${task}[[:space:]]*=" pixi.toml; then
    echo "demo catalog task is missing from pixi.toml: $task" >&2
    exit 1
  fi
done

echo "Moxi demo catalog check passed"
