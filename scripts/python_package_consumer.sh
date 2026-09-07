#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-python-wheel-stage.XXXXXX")"
wheel_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-python-wheel.XXXXXX")"
venv_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-python-wheel-venv.XXXXXX")"
cleanup() {
    rm -rf "$stage_dir" "$wheel_dir" "$venv_dir"
}
trap cleanup EXIT

cp "$repo_dir/pyproject.toml" "$stage_dir/pyproject.toml"
mkdir -p "$stage_dir/docs"
cp "$repo_dir/docs/python.md" "$stage_dir/docs/python.md"
cp -R "$repo_dir/python" "$stage_dir/python"
python3 -m venv "$venv_dir"
"$venv_dir/bin/python" -m pip wheel --disable-pip-version-check --no-deps --quiet "$stage_dir" --wheel-dir "$wheel_dir"
wheel="$(find "$wheel_dir" -type f -name 'moxi-*.whl' -print -quit)"
if [[ -z "$wheel" ]]; then
    echo "Python wheel build did not produce a moxi wheel" >&2
    exit 1
fi
"$venv_dir/bin/python" -m pip install --disable-pip-version-check --no-deps --quiet "$wheel"
"$venv_dir/bin/python" - <<'PY'
import moxi
from moxi import PlotSpec

spec = PlotSpec("wheel consumer")
spec.add_scatter("points")
figure = moxi.plot({"x": [0.0, 1.0], "y": [1.0, 2.0]}, spec, width=24, height=24)
assert figure.to_svg().startswith(b"<svg")
assert figure.to_png().startswith(b"\x89PNG\r\n\x1a\n")
print("Moxi Python wheel consumer passed")
PY
