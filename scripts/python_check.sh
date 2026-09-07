#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
venv_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-python-check.XXXXXX")"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-python-stage.XXXXXX")"
cleanup() {
    rm -rf "$venv_dir" "$stage_dir"
}
trap cleanup EXIT

cp "$repo_dir/pyproject.toml" "$stage_dir/pyproject.toml"
mkdir -p "$stage_dir/docs"
cp "$repo_dir/docs/python.md" "$stage_dir/docs/python.md"
cp -R "$repo_dir/python" "$stage_dir/python"
python3 -m venv "$venv_dir"
"$venv_dir/bin/python" -m pip install --disable-pip-version-check --no-deps --quiet "$stage_dir"
"$venv_dir/bin/python" - <<'PY'
import moxi
from moxi import PlotSpec

spec = PlotSpec("wheel")
spec.add_line("series")
figure = moxi.plot({"x": [0.0, 1.0], "y": [1.0, 2.0]}, spec, width=32, height=24)
assert figure.to_png().startswith(b"\x89PNG\r\n\x1a\n")
assert len(figure.to_rgba()) == 32 * 24 * 4
print("Moxi clean-wheel Python import passed")
PY
