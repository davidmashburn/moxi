#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

manifest_path="$repo_dir/tests/goldens/manifest.json"
pixi_manifest="$repo_dir/pixi.toml"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

pixi run mojo run -I src scripts/scenario_manifest.mojo > "$temp_dir/scenarios.txt"

MOXI_SCENARIO_OUTPUT="$temp_dir/scenarios.txt" \
MOXI_SCENARIO_MANIFEST="$manifest_path" \
MOXI_SCENARIO_PIXI="$pixi_manifest" \
MOXI_SCENARIO_REPO="$repo_dir" \
python3 - <<'PY'
import json
import os
import re
from pathlib import Path


repo = Path(os.environ["MOXI_SCENARIO_REPO"])
pixi = Path(os.environ["MOXI_SCENARIO_PIXI"]).read_text(encoding="utf-8")
manifest = json.loads(
    Path(os.environ["MOXI_SCENARIO_MANIFEST"]).read_text(encoding="utf-8")
)
goldens = {entry["name"]: entry for entry in manifest.get("entries", [])}

records = []
for line in Path(os.environ["MOXI_SCENARIO_OUTPUT"]).read_text(
    encoding="utf-8"
).splitlines():
    if not line.startswith("SCENARIO|"):
        continue
    fields = [field.strip() for field in line.split("|")]
    if len(fields) != 8:
        raise SystemExit(f"invalid scenario record: {line!r}")
    _, scenario_id, fixture, source, task, test_source, benchmark_source, golden_names = fields
    records.append(
        {
            "id": int(scenario_id),
            "fixture": fixture,
            "source": source,
            "task": task,
            "test": test_source,
            "benchmark": benchmark_source,
            "goldens": [name for name in golden_names.split(",") if name],
        }
    )

if len(records) != 7:
    raise SystemExit(f"expected seven canonical scenarios, got {len(records)}")
if len({record["id"] for record in records}) != len(records):
    raise SystemExit("canonical scenario ids are not unique")
if len({record["fixture"] for record in records}) != len(records):
    raise SystemExit("canonical scenario fixtures are not unique")

for record in records:
    for key in ("source", "test"):
        path = repo / record[key]
        if not path.is_file():
            raise SystemExit(
                f"{record['fixture']}: missing {key} consumer {record[key]}"
            )
    if not re.search(
        rf"^\s*{re.escape(record['task'])}\s*=", pixi, re.MULTILINE
    ):
        raise SystemExit(
            f"{record['fixture']}: missing Pixi task {record['task']}"
        )
    if record["benchmark"] and not (repo / record["benchmark"]).is_file():
        raise SystemExit(
            f"{record['fixture']}: missing benchmark {record['benchmark']}"
        )
    demo_source = (repo / "src/moxi/demo_browser.mojo").read_text(encoding="utf-8")
    if record["source"] not in demo_source or record["task"] not in demo_source:
        raise SystemExit(
            f"{record['fixture']}: demo catalog is missing source/task mapping"
        )
    for golden_name in record["goldens"]:
        entry = goldens.get(golden_name)
        if entry is None:
            raise SystemExit(
                f"{record['fixture']}: missing golden manifest entry {golden_name}"
            )
        if entry["scenario"] != record["fixture"]:
            raise SystemExit(
                f"{golden_name}: scenario {entry['scenario']} != {record['fixture']}"
            )

registered = {record["fixture"] for record in records}
for entry in manifest.get("entries", []):
    if entry.get("scenario") not in registered:
        raise SystemExit(
            f"golden {entry.get('name')} references unknown scenario "
            f"{entry.get('scenario')}"
        )

print(
    "Moxi scenario consumer check passed "
    f"({len(records)} scenarios, {len(goldens)} golden entries)"
)
PY
