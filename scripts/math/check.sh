#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="${MOXI_D02_BUILD_DIR:-/tmp/moxi-d02}"
hb="${MOXI_HARFBUZZ_PREFIX:-/opt/homebrew/opt/harfbuzz}"
cd "$repo"
bash scripts/math/build.sh
for name in model editor; do
  pixi run --frozen mojo run -I src "tests/math/$name.mojo" > "$work/$name-test.log" 2>&1
done
clang -Wall -Wextra -Werror -fobjc-arc -fmodules -c tests/math/native_probe.m -o "$work/probe.o" > "$work/probe-build.log" 2>&1
for name in geometry performance native_acceptance; do
  pixi run --frozen mojo build -I src "tests/math/$name.mojo" -Xlinker "$work/window.o" -Xlinker "$work/font.o" -Xlinker "$work/probe.o" -Xlinker "$hb/lib/libharfbuzz.dylib" -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText -o "$work/$name" > "$work/$name-build.log" 2>&1
  "$work/$name" > "$work/$name-test.log" 2>&1
done
export PYTHONPATH="$repo/python:$repo/experiments/math-backends${PYTHONPATH:+:$PYTHONPATH}"
"${MOXI_SYMPY_PYTHON:-python3}" tests/math/backend_test.py > "$work/backend-test.log" 2>&1
printf 'PASS math checks; logs in %s\n' "$work"
