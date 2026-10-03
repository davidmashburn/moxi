#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

require_wasm=0
if [ "${1:-}" = "--require-wasm" ]; then
  require_wasm=1
elif [ "${1:-}" != "" ]; then
  echo "usage: $0 [--require-wasm]" >&2
  exit 2
fi

target_report="$(mktemp "${TMPDIR:-/tmp}/moxi-web-targets.XXXXXX")"
cleanup() {
  rm -f "$target_report"
}
trap cleanup EXIT

set +e
mojo build --print-supported-targets >"$target_report" 2>&1
target_status=$?
set -e
if [ "$target_status" -ne 0 ]; then
  echo "could not query Mojo target support" >&2
  cat "$target_report" >&2
  exit "$target_status"
fi

wasm_available=0
if rg -qi 'wasm|webassembly' "$target_report"; then
  wasm_available=1
fi

if [ "$require_wasm" -eq 1 ] && [ "$wasm_available" -eq 0 ]; then
  echo "Mojo compiler has no WebAssembly target; packaged web runtime is unavailable" >&2
  cat "$target_report" >&2
  exit 2
fi

node tests/web_browser_harness.mjs

status="planned"
if [ "$wasm_available" -eq 1 ]; then
  status="target-reported-package-wiring-required"
fi

mkdir -p dist/web-package
MOXI_WEB_WASM_AVAILABLE="$wasm_available" \
MOXI_WEB_STATUS="$status" \
MOXI_WEB_TARGET_REPORT="$target_report" \
python3 - <<'PY'
import json
import os
from pathlib import Path

target_report = Path(os.environ["MOXI_WEB_TARGET_REPORT"])
result = {
    "schema_version": 1,
    "status": os.environ["MOXI_WEB_STATUS"],
    "wasm_target_available": os.environ["MOXI_WEB_WASM_AVAILABLE"] == "1",
    "host_harness": "tests/web_browser_harness.mjs",
    "supported_targets": target_report.read_text(encoding="utf-8"),
}
output = Path("dist/web-package/status.json")
output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"Web package status: {output}")
print(f"Mojo/WASM target available: {result['wasm_target_available']}")
if not result["wasm_target_available"]:
    print("Mojo WebAssembly package remains blocked by the pinned compiler target set")
PY
