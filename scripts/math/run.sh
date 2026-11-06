#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="${MOXI_D02_BUILD_DIR:-/tmp/moxi-d02}"
cd "$repo"
bash scripts/math/build.sh
export PYTHONPATH="$repo/python:$repo/experiments/math-backends${PYTHONPATH:+:$PYTHONPATH}"
export MOXI_SYMPY_PYTHON="${MOXI_SYMPY_PYTHON:-python3}"
if [[ "${1:-}" == --capture ]]; then
  export MOXI_MATH_CAPTURE_DIR="${2:?Provide capture directory}"
fi
"$work/workbench"
