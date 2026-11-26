#!/bin/sh
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
out=${1:?usage: build.sh OUTPUT.html}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
spatial="$here/../../native/spatial"
"${CXX:-c++}" -std=c++20 -O2 -I"$spatial" "$here/project.cpp" "$spatial/core.cpp" -o "$tmp/project"
"$tmp/project" > "$tmp/geometry.json"
python3 - "$here" "$tmp/geometry.json" "$out" <<'PY'
import sys
from pathlib import Path
here, data, out = map(Path, sys.argv[1:])
out.write_text((here / "editor.html").read_text().replace("/* GEOMETRY */", data.read_text()))
PY
