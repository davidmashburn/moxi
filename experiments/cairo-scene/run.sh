#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=${1:?supply a new output directory}
mkdir -p "$(dirname "$out")"
mkdir "$out"
cd "$out"
pixi run --manifest-path "${MOXI_PIXI_MANIFEST:-$root/pixi.toml}" mojo build -I "$root/src" "$here/export.mojo" -o export
./export > parity.txt
rm export
if [[ $(uname -s) == Darwin ]]; then
  export DYLD_FALLBACK_LIBRARY_PATH="$(pkg-config --variable=libdir cairo)${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
fi
uv run --script "$here/compare.py"
