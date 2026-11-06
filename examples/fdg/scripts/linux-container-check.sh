#!/usr/bin/env bash
# Run INSIDE a disposable Ubuntu 24.04 x86-64 container with prerequisites.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Requires Linux x86-64'; exit 1; }
pixi install --locked
pixi run --locked bash examples/fdg/scripts/build-linux.sh
bash examples/fdg/scripts/check.sh
bash examples/fdg/scripts/check-export.sh
python3 examples/fdg/tests/test_formats.py examples/fdg/dist/moxi-fdg
mkdir -p artifacts/demo-slideshows/fdg-linux
# Xvfb is a virtual X11 display, not physical Linux hardware acceptance.
GSK_RENDERER=cairo xvfb-run -a -s '-screen 0 1280x1024x24' \
  examples/fdg/dist/moxi-fdg examples/fdg/tests/fixtures/export.json \
  --replay "$repo/artifacts/demo-slideshows/fdg-linux"
