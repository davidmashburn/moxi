#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="${MOXI_MATH_BUILD_DIR:-/tmp/moxi-d01}"
manifest="${MOXI_MOJO_MANIFEST:-$repo/pixi.toml}"
if [[ "$(uname -s)" != Darwin ]]; then echo 'The native screenshot demo requires macOS' >&2; exit 1; fi
mkdir -p "$work"
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c "$repo/native/macos_window.m" -o "$work/macos_window.o"
clang -Wall -Wextra -Werror -fobjc-arc -fmodules -c "$here/native/window_id.m" -o "$work/window_id.o"
pixi run --manifest-path "$manifest" --frozen mojo build -I "$repo/src" "$here/native/demo.mojo" \
  -Xlinker "$work/macos_window.o" -Xlinker "$work/window_id.o" -Xlinker -framework -Xlinker Cocoa \
  -o "$work/moxi-math-demo" > "$work/demo-build.log" 2>&1
export PYTHONPATH="$here${PYTHONPATH:+:$PYTHONPATH}"
export MOXI_SYMENGINE_WORKER="$work/symengine-worker"
export MOXI_SYMPY_PYTHON="${MOXI_SYMPY_PYTHON:-$work/venv/bin/python}"
export MOXI_MATH_MEASUREMENTS="${MOXI_MATH_MEASUREMENTS:-$here/evidence/measurements.json}"
export MOXI_SOURCE_REVISION="$(git -C "$repo" rev-parse HEAD) + local D01 diff"
if [[ "${1:-}" == --capture ]]; then
  export MOXI_MATH_CAPTURE_DIR="${2:?Provide screenshot output directory}"
fi
"$work/moxi-math-demo"
