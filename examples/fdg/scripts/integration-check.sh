#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-fdg-check.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
python3 - "$work_dir" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
graph = {
    'nodes': [{'id': str(i), 'group': i % 6} for i in range(256)],
    'links': [{'source': str(i % 256), 'target': str((i * 7 + 1) % 256), 'value': 1}
              for i in range(1024)]
}
(p / 'capacity.json').write_text(json.dumps(graph))
(p / 'oversized.json').write_text(' ' * 1048577)
PY
"$app_dir/dist/moxi-fdg" "$work_dir/capacity.json" --export "$work_dir/one.svg"
"$app_dir/dist/moxi-fdg" "$work_dir/capacity.json" --export "$work_dir/two.svg"
cmp "$work_dir/one.svg" "$work_dir/two.svg"
python3 - "$work_dir/one.svg" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
assert len(root.findall('.//{http://www.w3.org/2000/svg}text')) == 256
assert len(root.findall('.//{http://www.w3.org/2000/svg}line')) == 1024
print('CLI capacity export: 256 labels, 1024 edges, deterministic XML')
PY
if "$app_dir/dist/moxi-fdg" "$work_dir/oversized.json" --export "$work_dir/bad.svg" > "$work_dir/error.log" 2>&1; then
  echo 'Oversized file unexpectedly accepted' >&2
  exit 1
fi
rg -q 'Graph file exceeds 1 MiB' "$work_dir/error.log"
if [[ "${1:-}" == --native ]]; then
  "$app_dir/dist/moxi-fdg" "$work_dir/capacity.json" --smoke
fi
echo 'Integration checks passed'
