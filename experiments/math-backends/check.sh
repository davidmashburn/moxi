#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${MOXI_MATH_BUILD_DIR:-/tmp/moxi-d01}"
export PYTHONPATH="$here${PYTHONPATH:+:$PYTHONPATH}"
export MOXI_SYMENGINE_WORKER="$work/symengine-worker"
[[ -x "$MOXI_SYMENGINE_WORKER" ]] || { echo 'Build the native worker first; this check does not silently skip it.' >&2; exit 1; }
"$work/venv/bin/python" -m pytest "$here/tests" -q
