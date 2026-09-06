#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

benchmark_profile="${MOXI_BENCHMARK_PROFILE:-full}"
case "$benchmark_profile" in
  quick)
    benchmark_runs="${MOXI_BENCHMARK_RUNS:-1}"
    ;;
  full)
    benchmark_runs="${MOXI_BENCHMARK_RUNS:-3}"
    ;;
  *)
    echo "MOXI_BENCHMARK_PROFILE must be quick or full" >&2
    exit 2
    ;;
esac
if ! [[ "$benchmark_runs" =~ ^[1-9][0-9]*$ ]]; then
  echo "MOXI_BENCHMARK_RUNS must be a positive integer" >&2
  exit 2
fi

benchmark_dir="${MOXI_BENCHMARK_DIR:-$repo_dir/dist/benchmark-results}"
mkdir -p "$benchmark_dir/raw"
records_path="$benchmark_dir/records.tsv"
: > "$records_path"

case_id() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '_' \
    | sed 's/^_*//; s/_*$//'
}

run_case() {
  local label="$1"
  shift
  local id
  id="$(case_id "$label")"
  echo "==> $label ($benchmark_runs runs)"
  for ((run = 1; run <= benchmark_runs; run++)); do
    echo "-- $label run $run/$benchmark_runs"
    local output_path="$benchmark_dir/raw/${id}-${run}.stdout"
    local timing_path="$benchmark_dir/raw/${id}-${run}.time"
    set +e
    /usr/bin/time -p "$@" >"$output_path" 2>"$timing_path"
    local status=$?
    set -e
    cat "$output_path"
    cat "$timing_path"
    local real_seconds
    real_seconds="$(awk '$1 == "real" {print $2; exit}' "$timing_path")"
    if [ -z "$real_seconds" ]; then
      real_seconds="0"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$label" "$run" "$status" "$real_seconds" "$output_path" "$*" \
      >> "$records_path"
    if [ "$status" -ne 0 ]; then
      return "$status"
    fi
  done
}

echo "Moxi benchmark harness"
echo "Profile: $benchmark_profile; results: $benchmark_dir"
echo "Use MOXI_BENCHMARK_PROFILE=quick for the portable smoke workload or full for the complete matrix."

run_case "typed localized execution" pixi run mojo run -I src benchmarks/localized_execution.mojo
run_case "retained layout/paint/scene" pixi run mojo run -I src benchmarks/layout.mojo
run_case "portable plot scene" pixi run mojo run -I src benchmarks/plotting.mojo

if [ "$benchmark_profile" = "full" ]; then
  run_case "statistical and linked plot scene" pixi run mojo run -I src benchmarks/plotting_analytics.mojo
  run_case "large plot scene generation" pixi run mojo run -I src benchmarks/plotting_large.mojo
  run_case "collection interaction foundation" pixi run mojo run -I src benchmarks/interaction_foundation.mojo
  pixi run plot-interaction-benchmark-build
  run_case "indexed plot interactions" ./dist/moxi-plot-interaction-benchmark
  pixi run plot-metal-benchmark-build
  run_case "Metal plot render packet" ./dist/moxi-plot-metal-benchmark

  pixi run fractal-benchmark-build
  run_case "interactive fractal component and canvas commands" ./dist/moxi-fractal-benchmark

  # Compile once so the Metal measurements focus on the workload rather than
  # repeatedly invoking the Mojo compiler.
  pixi run metal-benchmark-build
  run_case "offscreen Metal scene" ./dist/moxi-metal-benchmark
fi

MOXI_BENCHMARK_RECORDS="$records_path" \
MOXI_BENCHMARK_PROFILE="$benchmark_profile" \
MOXI_BENCHMARK_RUNS="$benchmark_runs" \
MOXI_BENCHMARK_OUTPUT="${MOXI_BENCHMARK_OUTPUT:-$benchmark_dir/${benchmark_profile}.json}" \
python3 - <<'PY'
import json
import os
import re
from pathlib import Path


records_path = Path(os.environ["MOXI_BENCHMARK_RECORDS"])
output_path = Path(os.environ["MOXI_BENCHMARK_OUTPUT"])
profile = os.environ["MOXI_BENCHMARK_PROFILE"]
runs = int(os.environ["MOXI_BENCHMARK_RUNS"])

metric_pattern = re.compile(
    r"(checksum|commands|rows|passes|work|build|invalidat|dependency|"
    r"selected|pixels|segments|vertices|operations|visible|slots|fallback|"
    r"reconciled|paint|dirty|count)",
    re.IGNORECASE,
)
cases = []
by_name = {}
for row in records_path.read_text(encoding="utf-8").splitlines():
    if not row:
        continue
    name, run, status, wall, stdout_path, command = row.split("\t", 5)
    stdout = Path(stdout_path).read_text(encoding="utf-8", errors="replace")
    metrics = [
        line.strip()
        for line in stdout.splitlines()
        if metric_pattern.search(line)
    ]
    case = by_name.setdefault(
        name,
        {"name": name, "command": command, "runs": []},
    )
    case["runs"].append(
        {
            "run": int(run),
            "status": int(status),
            "wall_seconds": float(wall),
            "metric_lines": metrics,
        }
    )
for case in by_name.values():
    cases.append(case)

result = {
    "schema_version": 1,
    "profile": profile,
    "requested_runs": runs,
    "cases": cases,
}
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"Structured benchmark results: {output_path}")
print(f"Recorded {len(cases)} cases with {sum(len(c['runs']) for c in cases)} runs")
PY
