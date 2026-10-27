#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
moxi_source="${MOXI_SOURCE_DIR:-$app_dir/../..}"
moxi_dir="$(cd "$moxi_source" && pwd)"
for test in test_layout test_io test_app; do
  pixi run --manifest-path "$moxi_dir/pixi.toml" mojo run -I "$moxi_dir/src" -I "$app_dir/src" "$app_dir/tests/$test.mojo"
done
python3 - <<'PY'
import xml.etree.ElementTree as ET
root = ET.parse('/tmp/moxi-fdg-test.svg').getroot()
assert root.tag == '{http://www.w3.org/2000/svg}svg'
assert len(root.findall('.//{http://www.w3.org/2000/svg}line')) > 0
assert len(root.findall('.//{http://www.w3.org/2000/svg}text')) > 0
print('SVG: XML parses and includes graph edges and labels')
PY
