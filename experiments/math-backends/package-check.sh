#!/usr/bin/env bash
# Clean wheel consumers outside the source checkout. Nothing is published.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${MOXI_MATH_BUILD_DIR:-/tmp/moxi-d01}"
python="${MOXI_MATH_PYTHON:-python3}"
consumer="$(mktemp -d /tmp/moxi-d01-consumer.XXXXXX)"
"$python" -m venv "$consumer/venv"
"$consumer/venv/bin/pip" wheel --no-deps "$here" -w "$consumer/wheels" > "$consumer/wheel.log" 2>&1
"$consumer/venv/bin/pip" install "$consumer"/wheels/*.whl > "$consumer/install-base.log" 2>&1
# A base package install must not silently import or require a symbolic engine.
(cd "$consumer" && env -u PYTHONPATH "$consumer/venv/bin/python" -c 'from moxi_math_probe.model import rational; assert rational(1,2).values == ("1", "2")')
"$consumer/venv/bin/pip" install 'sympy==1.14.0' 'mpmath==1.3.0' > "$consumer/install-sympy.log" 2>&1
"$consumer/venv/bin/pip" check > "$consumer/pip-check.log" 2>&1
site="$("$consumer/venv/bin/python" -c 'import sysconfig; print(sysconfig.get_path("purelib"))')"
cp "$here/tests/package_consumer.py" "$consumer/check.py"
(cd "$consumer" && PYTHONPATH="$site" MOXI_SYMENGINE_WORKER="$work/symengine-worker" "$consumer/venv/bin/python" check.py) > "$consumer/check.log" 2>&1
printf 'Clean installed consumers passed. Logs: %s\n' "$consumer"
