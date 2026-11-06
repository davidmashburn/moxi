#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
manifest="${MOXI_E04_MANIFEST:-$root/pixi.toml}"
python="${MOXI_E04_PYTHON:-python3}"
export MACOSX_DEPLOYMENT_TARGET=15.0
pixi run --manifest-path "$manifest" python3 "$here/build_native.py"
"$python" -m venv "$here/dist/build-venv"
stage="$(mktemp -d /tmp/moxi-e04-facade-stage.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
cp "$root/pyproject.toml" "$stage/"
mkdir "$stage/docs"
cp "$root/docs/python.md" "$stage/docs/"
cp -R "$root/python" "$stage/"
"$here/dist/build-venv/bin/python" -m pip wheel --no-deps "$stage" --wheel-dir "$here/dist/wheels"
"$here/dist/build-venv/bin/python" -m pip wheel --no-deps "$here" --wheel-dir "$here/dist/wheels"
printf 'Local experimental wheels: %s/dist/wheels\n' "$here"
