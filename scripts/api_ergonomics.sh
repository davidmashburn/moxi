#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

profile="${MOXI_API_PROFILE:-quick}"
case "$profile" in
  quick)
    fixtures=(
      tests/api_lanes.mojo
      tests/request_adapter.mojo
    )
    ;;
  full)
    fixtures=(
      tests/api_lanes.mojo
      tests/request_adapter.mojo
      tests/composed.mojo
      tests/demo_browser.mojo
    )
    ;;
  *)
    echo "MOXI_API_PROFILE must be quick or full" >&2
    exit 2
    ;;
esac

results_dir="${MOXI_API_ERGONOMICS_DIR:-$repo_dir/dist/api-ergonomics}"
raw_dir="$results_dir/raw"
mkdir -p "$raw_dir"
records_path="$raw_dir/compile.tsv"
: > "$records_path"

git_revision="$(git rev-parse HEAD)"
git_dirty=0
if [[ -n "$(git status --porcelain)" ]]; then
  git_dirty=1
fi
mojo_version="$(mojo --version | tail -n 1)"
operating_system="$(uname -s)"
architecture="$(uname -m)"

echo "Moxi API ergonomics baseline"
echo "Profile: $profile; results: $results_dir"

for fixture in "${fixtures[@]}"; do
  label="${fixture#tests/}"
  id="${label%.mojo}"
  stdout_path="$raw_dir/${id}.stdout"
  timing_path="$raw_dir/${id}.time"
  echo "==> $fixture"
  set +e
  /usr/bin/time -p -o "$timing_path" mojo run -I src "$fixture" >"$stdout_path"
  status=$?
  set -e
  cat "$stdout_path"
  cat "$timing_path"
  real_seconds="$(awk '$1 == "real" {print $2; exit}' "$timing_path")"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$fixture" "$status" "$real_seconds" "$stdout_path" "$timing_path" \
    >> "$records_path"
  if [ "$status" -ne 0 ]; then
    echo "API ergonomics fixture failed: $fixture" >&2
    exit "$status"
  fi
done

diagnostic_path="$raw_dir/diagnostic.stderr"
diagnostic_time_path="$raw_dir/diagnostic.time"
set +e
/usr/bin/time -p -o "$diagnostic_time_path" \
  mojo run -I src tests/fixtures/api_diagnostic_fixture.mojo \
  > /dev/null 2>"$diagnostic_path"
diagnostic_status=$?
set -e
if [ "$diagnostic_status" -eq 0 ]; then
  echo "diagnostic fixture unexpectedly compiled" >&2
  exit 1
fi
diagnostic_bytes="$(wc -c < "$diagnostic_path" | tr -d ' ')"
diagnostic_lines="$(wc -l < "$diagnostic_path" | tr -d ' ')"
diagnostic_seconds="$(awk '$1 == "real" {print $2; exit}' "$diagnostic_time_path")"

export_count="$(awk -F '\t' 'NR > 1 && $1 !~ /^#/ && NF >= 2 {count += 1} END {print count + 0}' docs/api-surface.tsv)"
trait_method_count="$(awk -F '\t' 'NR > 1 && $1 !~ /^#/ && NF >= 3 {count += 1} END {print count + 0}' docs/trait-surface.tsv)"
generic_declaration_count="$(rg -n '^struct [A-Za-z_][A-Za-z0-9_]*\[' src/moxi | wc -l | tr -d ' ' || true)"
component_trait_method_count="$(awk -F '\t' '$1 == "moxi" && $2 == "Component" {count += 1} END {print count + 0}' docs/trait-surface.tsv)"
component_slot_generic_count="$(rg -n '^struct ComponentSlot\[' src/moxi | wc -l | tr -d ' ' || true)"
request_generic_declaration_count="$(rg -n '^struct [A-Za-z_][A-Za-z0-9_]*Request[A-Za-z_0-9]*\[' src/moxi | wc -l | tr -d ' ' || true)"

MOXI_API_PROFILE="$profile" \
MOXI_API_RECORDS="$records_path" \
MOXI_API_DIAGNOSTIC="$diagnostic_path" \
MOXI_API_DIAGNOSTIC_STATUS="$diagnostic_status" \
MOXI_API_DIAGNOSTIC_BYTES="$diagnostic_bytes" \
MOXI_API_DIAGNOSTIC_LINES="$diagnostic_lines" \
MOXI_API_DIAGNOSTIC_SECONDS="$diagnostic_seconds" \
MOXI_API_RESULTS="$results_dir/${profile}.json" \
MOXI_API_GIT_REVISION="$git_revision" \
MOXI_API_GIT_DIRTY="$git_dirty" \
MOXI_API_MOJO_VERSION="$mojo_version" \
MOXI_API_OS="$operating_system" \
MOXI_API_ARCHITECTURE="$architecture" \
MOXI_API_EXPORT_COUNT="$export_count" \
MOXI_API_TRAIT_METHOD_COUNT="$trait_method_count" \
MOXI_API_GENERIC_DECLARATION_COUNT="$generic_declaration_count" \
MOXI_API_COMPONENT_TRAIT_METHOD_COUNT="$component_trait_method_count" \
MOXI_API_COMPONENT_SLOT_GENERIC_COUNT="$component_slot_generic_count" \
MOXI_API_REQUEST_GENERIC_DECLARATION_COUNT="$request_generic_declaration_count" \
python3 - <<'PY'
import json
import os
from pathlib import Path


records = []
records_path = Path(os.environ["MOXI_API_RECORDS"])
for row in records_path.read_text(encoding="utf-8").splitlines():
    if not row:
        continue
    fixture, status, seconds, stdout_path, timing_path = row.split("\t", 4)
    records.append(
        {
            "fixture": fixture,
            "status": int(status),
            "wall_seconds": float(seconds),
            "stdout": stdout_path,
            "timing": timing_path,
        }
    )

result = {
    "schema_version": 1,
    "profile": os.environ["MOXI_API_PROFILE"],
    "environment": {
        "git_revision": os.environ["MOXI_API_GIT_REVISION"],
        "git_dirty": os.environ["MOXI_API_GIT_DIRTY"] == "1",
        "mojo_version": os.environ["MOXI_API_MOJO_VERSION"],
        "os": os.environ["MOXI_API_OS"],
        "architecture": os.environ["MOXI_API_ARCHITECTURE"],
    },
    "compile_fixtures": records,
    "diagnostic": {
        "fixture": "tests/fixtures/api_diagnostic_fixture.mojo",
        "status": int(os.environ["MOXI_API_DIAGNOSTIC_STATUS"]),
        "bytes": int(os.environ["MOXI_API_DIAGNOSTIC_BYTES"]),
        "lines": int(os.environ["MOXI_API_DIAGNOSTIC_LINES"]),
        "wall_seconds": float(os.environ["MOXI_API_DIAGNOSTIC_SECONDS"]),
        "stderr": os.environ["MOXI_API_DIAGNOSTIC"],
    },
    "public_surface": {
        "exports": int(os.environ["MOXI_API_EXPORT_COUNT"]),
        "trait_methods": int(os.environ["MOXI_API_TRAIT_METHOD_COUNT"]),
        "generic_declarations": int(
            os.environ["MOXI_API_GENERIC_DECLARATION_COUNT"]
        ),
        "component_trait_methods": int(
            os.environ["MOXI_API_COMPONENT_TRAIT_METHOD_COUNT"]
        ),
        "component_slot_generic_declarations": int(
            os.environ["MOXI_API_COMPONENT_SLOT_GENERIC_COUNT"]
        ),
        "request_generic_declarations": int(
            os.environ["MOXI_API_REQUEST_GENERIC_DECLARATION_COUNT"]
        ),
    },
}
output_path = Path(os.environ["MOXI_API_RESULTS"])
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"Structured API ergonomics results: {output_path}")
print(
    "Surface: "
    f"{result['public_surface']['exports']} exports, "
    f"{result['public_surface']['trait_methods']} trait methods, "
    f"{result['public_surface']['generic_declarations']} generic declarations"
)
print(
    "Diagnostic: "
    f"{result['diagnostic']['bytes']} bytes, "
    f"{result['diagnostic']['lines']} lines"
)
PY
