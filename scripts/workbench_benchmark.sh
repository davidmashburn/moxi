#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

profile="${MOXI_BENCHMARK_PROFILE:-quick}"
case "$profile" in
  quick)
    default_runs=1
    default_repetitions=1
    ;;
  full)
    default_runs=3
    default_repetitions=100
    ;;
  *)
    echo "MOXI_BENCHMARK_PROFILE must be quick or full" >&2
    exit 2
    ;;
esac
runs="${MOXI_WORKBENCH_RUNS:-$default_runs}"
repetitions="${MOXI_WORKBENCH_REPETITIONS:-$default_repetitions}"
warmup="${MOXI_WORKBENCH_WARMUP:-3}"
lane="${MOXI_WORKBENCH_LANE:-software}"
instrumented="${MOXI_WORKBENCH_INSTRUMENTED:-1}"
for count in "$repetitions" "$warmup"; do
  [[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "Repetitions and warmup must be positive integers" >&2; exit 2; }
done
[[ "$instrumented" == 0 || "$instrumented" == 1 ]] || { echo "Instrumentation must be 0 or 1" >&2; exit 2; }
case "$lane" in
  software) native_lane=0 ;;
  native_offscreen) native_lane=1 ;;
  *) echo "MOXI_WORKBENCH_LANE must be software or native_offscreen" >&2; exit 2 ;;
esac
export MOXI_WORKBENCH_REPETITIONS="$repetitions" MOXI_WORKBENCH_WARMUP="$warmup"
export MOXI_WORKBENCH_INSTRUMENTED="$instrumented" MOXI_WORKBENCH_NATIVE="$native_lane"
if ! [[ "$runs" =~ ^[1-9][0-9]*$ ]]; then
  echo "MOXI_WORKBENCH_RUNS must be a positive integer" >&2
  exit 2
fi

if ! command -v pixi >/dev/null 2>&1; then
  echo "pixi is required to run the workbench benchmark" >&2
  exit 1
fi

git_revision="$(git rev-parse HEAD)"
git_dirty=0
if [[ -n "$(git status --porcelain=v1)" ]]; then
  git_dirty=1
fi
mojo_version="$(pixi run mojo --version | tail -n 1)"
clang_version_all="$(pixi run clang --version)"
clang_version="${clang_version_all%%$'\n'*}"
os_name="$(uname -s)"
architecture="$(uname -m)"
if [[ "$os_name" == "Darwin" ]]; then
  os_version="$(sw_vers -productVersion 2>/dev/null || uname -r)"
  host_model="$(sysctl -n hw.model 2>/dev/null || printf '%s' unknown)"
else
  os_version="$(uname -r)"
  host_model="$(uname -p 2>/dev/null || printf '%s' unknown)"
fi
host_cpu_brand="unknown"
if [[ "$os_name" == "Darwin" ]]; then
  host_cpu_brand="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || printf '%s' unknown)"
fi

result_dir="${MOXI_WORKBENCH_DIR:-$repo_dir/dist/workbench-benchmark/$lane/instrumented-$instrumented}"
mkdir -p "$result_dir/raw"
binary_path="$result_dir/moxi-data-workbench-benchmark"
clock_object_path="$repo_dir/native/benchmark_clock.o"

clock_build_command="pixi run clang -O3 -Wall -Wextra -Werror -c native/benchmark_clock.c -o native/benchmark_clock.o"
mojo_build_command="pixi run mojo build -I src -Xlinker native/benchmark_clock.o -Xlinker native/workbench_benchmark_config.o -Xlinker native/macos_window.o -Xlinker -framework -Xlinker Cocoa benchmarks/data_workbench.mojo -o $binary_path"
time_flags=(-p)
time_command="/usr/bin/time -p"
peak_rss_measured=0
if [[ "$os_name" == "Darwin" ]]; then
  time_flags=(-l -p)
  time_command="/usr/bin/time -lp"
  peak_rss_measured=1
fi
run_command="$time_command $binary_path"

echo "Building data workbench benchmark"
python3 - "$result_dir/source-sha256.json" <<'PY'
import hashlib, json, sys
from pathlib import Path
paths = ["benchmarks/data_workbench.mojo", "scripts/workbench_benchmark.sh",
         "native/workbench_benchmark_config.c", "native/benchmark_clock.c",
         "native/macos_window.m", "src/moxi_demo/data_workbench.mojo",
         "src/moxi_demo/workbench_data.mojo", "src/moxi_plot/plot_data.mojo"]
Path(sys.argv[1]).write_text(json.dumps({p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths}, indent=2) + "\n")
PY
echo "  $clock_build_command"
pixi run clang -O3 -Wall -Wextra -Werror \
  -c native/benchmark_clock.c -o "$clock_object_path"
pixi run clang -O3 -Wall -Wextra -Werror -c native/workbench_benchmark_config.c -o native/workbench_benchmark_config.o
pixi run native-object
echo "  $mojo_build_command"
pixi run mojo build -I src -Xlinker native/benchmark_clock.o -Xlinker native/workbench_benchmark_config.o \
  -Xlinker native/macos_window.o -Xlinker -framework -Xlinker Cocoa \
  benchmarks/data_workbench.mojo -o "$binary_path"

records_path="$result_dir/records.tsv"
: > "$records_path"
for ((run = 1; run <= runs; run++)); do
  stdout_path="$result_dir/raw/run-${run}.stdout"
  timing_path="$result_dir/raw/run-${run}.time"
  echo "Running data workbench benchmark ($run/$runs)"
  set +e
  /usr/bin/time "${time_flags[@]}" "$binary_path" >"$stdout_path" 2>"$timing_path"
  status=$?
  set -e
  echo "  status=$status; raw samples: $stdout_path"
  real_seconds="$(awk '$1 == "real" {print $2; exit}' "$timing_path")"
  user_seconds="$(awk '$1 == "user" {print $2; exit}' "$timing_path")"
  sys_seconds="$(awk '$1 == "sys" {print $2; exit}' "$timing_path")"
  [[ -n "$real_seconds" ]] || real_seconds=0
  [[ -n "$user_seconds" ]] || user_seconds=0
  [[ -n "$sys_seconds" ]] || sys_seconds=0
  peak_rss_bytes="$(awk '/maximum resident set size/ {print $1; exit}' "$timing_path")"
  if ! [[ "$peak_rss_bytes" =~ ^[0-9]+$ ]]; then
    peak_rss_bytes="not_measured"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$run" "$status" "$real_seconds" "$user_seconds" "$sys_seconds" \
    "$peak_rss_bytes" "$stdout_path" "$timing_path" >> "$records_path"
  if (( status != 0 )); then
    exit "$status"
  fi
done

output_path="${MOXI_WORKBENCH_OUTPUT:-$result_dir/${profile}.json}"
MOXI_WORKBENCH_RECORDS="$records_path" \
MOXI_WORKBENCH_OUTPUT="$output_path" \
MOXI_WORKBENCH_PROFILE="$profile" \
MOXI_WORKBENCH_RUNS="$runs" \
MOXI_WORKBENCH_LANE="$lane" \
MOXI_WORKBENCH_GIT_REVISION="$git_revision" \
MOXI_WORKBENCH_GIT_DIRTY="$git_dirty" \
MOXI_WORKBENCH_MOJO_VERSION="$mojo_version" \
MOXI_WORKBENCH_CLANG_VERSION="$clang_version" \
MOXI_WORKBENCH_OS="$os_name" \
MOXI_WORKBENCH_OS_VERSION="$os_version" \
MOXI_WORKBENCH_ARCHITECTURE="$architecture" \
MOXI_WORKBENCH_HOST_MODEL="$host_model" \
MOXI_WORKBENCH_HOST_CPU_BRAND="$host_cpu_brand" \
MOXI_WORKBENCH_PEAK_RSS_MEASURED="$peak_rss_measured" \
MOXI_WORKBENCH_REPO_DIR="$repo_dir" \
MOXI_WORKBENCH_BINARY="$binary_path" \
MOXI_WORKBENCH_CLOCK_OBJECT="$clock_object_path" \
MOXI_WORKBENCH_CLOCK_BUILD_COMMAND="$clock_build_command" \
MOXI_WORKBENCH_BUILD_COMMAND="$mojo_build_command" \
MOXI_WORKBENCH_RUN_COMMAND="$run_command" \
python3 - <<'PY'
import json
import os
import hashlib
from pathlib import Path


def parse_token(token: str):
    key, value = token.split("=", 1)
    if value in {"not_measured", "observed", "reused", "rebuilt"}:
        return key, value
    if value.lower() in {"true", "false"}:
        return key, value.lower() == "true"
    if value.lstrip("+-").isdigit():
        return key, int(value)
    try:
        return key, float(value)
    except ValueError:
        return key, value


def relative_artifact(path: str) -> str:
    repo = Path(os.environ["MOXI_WORKBENCH_REPO_DIR"])
    try:
        return str(Path(path).relative_to(repo))
    except ValueError:
        return path


def percentile(values, fraction: float):
    """Return an interpolated percentile without requiring numpy."""
    if not values:
        return None
    ordered = sorted(float(value) for value in values)
    position = (len(ordered) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    amount = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * amount


def sample_statistics(samples, field: str):
    values = [
        sample[field]
        for sample in samples
        if field in sample and sample[field] is not None
    ]
    if not values:
        return None
    return {
        "count": len(values),
        "min": min(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "max": max(values),
    }


records = Path(os.environ["MOXI_WORKBENCH_RECORDS"])
cases = {}
process_runs = []
for record in records.read_text(encoding="utf-8").splitlines():
    if not record:
        continue
    run, status, wall, user, system, peak_rss, stdout_path, timing_path = record.split("\t", 7)
    run = int(run)
    status = int(status)
    lines = Path(stdout_path).read_text(encoding="utf-8").splitlines()
    process_id = next((int(line.split("=", 1)[1]) for line in lines if line.startswith("process_id=")), None)
    process_runs.append(
        {
            "run": run,
            "process_id": process_id,
            "status": status,
            "process_wall_seconds": float(wall),
            "process_user_seconds": float(user),
            "process_system_seconds": float(system),
            "process_peak_resident_bytes": (
                int(peak_rss) if peak_rss != "not_measured" else None
            ),
            "stdout_artifact": relative_artifact(stdout_path),
            "timing_artifact": relative_artifact(timing_path),
        }
    )
    for line in lines:
        if not line.startswith("WORKBENCH "):
            continue
        fields = dict(parse_token(token) for token in line.split()[1:])
        case_key = (int(fields.pop("rows")), fields.pop("operation"))
        fields["run"] = run
        fields["sample"] = len(cases.get(case_key, [])) % int(os.environ["MOXI_WORKBENCH_REPETITIONS"])
        fields["status"] = status
        fields["process_wall_seconds"] = float(wall)
        fields["process_user_seconds"] = float(user)
        fields["process_system_seconds"] = float(system)
        fields["process_peak_resident_bytes"] = (
            int(peak_rss) if peak_rss != "not_measured" else None
        )
        cases.setdefault(case_key, []).append(fields)

expected_count = int(os.environ["MOXI_WORKBENCH_RUNS"]) * int(os.environ["MOXI_WORKBENCH_REPETITIONS"])
assert len(cases) == 12, f"Expected 12 cases, received {len(cases)}"
for key, samples in cases.items():
    assert len(samples) == expected_count, (key, len(samples), expected_count)
    assert all(sample.get("command_overflows", 0) == 0 for sample in samples), key
    assert all(sample["source_rows"] == key[0] for sample in samples), key

repo = Path(os.environ["MOXI_WORKBENCH_REPO_DIR"])

result = {
    "schema_version": 1,
    "report_schema": "data_workbench_exploratory",
    "benchmark": "data_workbench",
    "profile": os.environ["MOXI_WORKBENCH_PROFILE"],
    "requested_runs": int(os.environ["MOXI_WORKBENCH_RUNS"]),
    "repetitions_per_case_per_process": int(os.environ["MOXI_WORKBENCH_REPETITIONS"]),
    "warmup_cycles": int(os.environ["MOXI_WORKBENCH_WARMUP"]),
    "instrumented": os.environ["MOXI_WORKBENCH_INSTRUMENTED"] == "1",
    "lane": os.environ["MOXI_WORKBENCH_LANE"],
    "source_sha256": json.loads((records.parent / "source-sha256.json").read_text()),
    "binary_sha256": hashlib.sha256(Path(os.environ["MOXI_WORKBENCH_BINARY"]).read_bytes()).hexdigest(),
    "baseline_status": "exploratory_unreviewed",
    "measurement": {
        "boundary": (
            "cold DataWorkbench/App construction and steady-state App.dispatch "
            "plus retained paint and combined scatter/histogram scene "
            "rasterization measured inside the benchmark executable; software "
            "or offscreen AppKit custom-command drawing as specified by lane. "
            "Native widgets, queue latency and presentation are not measured"
        ),
        "in_process_elapsed": "monotonic elapsed time for the composed application operation",
        "process_wall": "process wall time from /usr/bin/time, including startup",
        "process_cpu": "user/system process samples from /usr/bin/time -p",
        "visible_latency": None,
        "visible_latency_status": "not_measured",
        "visible_completion_observed": False,
        "memory": (
            "process-level peak resident set size from /usr/bin/time -l; "
            "not an operation-level allocation or leak measurement"
            if os.environ["MOXI_WORKBENCH_PEAK_RSS_MEASURED"] == "1"
            else None
        ),
        "memory_status": (
            "process_peak_observed"
            if os.environ["MOXI_WORKBENCH_PEAK_RSS_MEASURED"] == "1"
            else "not_measured"
        ),
    },
    "workload": {
        "row_counts": [10000, 100000],
        "operations": ["cold_load", "filter", "hover", "selection", "scroll", "resize"],
        "fixture": "public parameterized WorkbenchData fixture consumed by DataWorkbench",
        "app_path": "App[DataWorkbench] with public dispatch and scene/render path",
        "cold_load_boundary": "DataWorkbench/App construction plus initial retained view and scene work",
        "steady_state_boundary": "one public input dispatch followed by retained paint and combined plot scene rasterization",
        "render_backend": os.environ["MOXI_WORKBENCH_LANE"],
        "window_dimensions": [1180, 820],
        "resize_dimensions": [1280, 900],
        "native_bitmap_dimensions": [1280, 900],
        "native_bitmap_scale": 1,
        "native_composition": "sum of two independent fresh bitmap paints; retained scene conversion, not native widgets; host plot_bounds clip absent",
        "key_distribution": "monotone generated keys",
        "selection_density": "single hit-tested observation after selection",
        "cycle_reset": "fresh fixture/App each cycle; cold_load means object construction, not new process",
        "phase_boundary": "dispatch includes state mutation, plot replacement, reconciliation/layout; retained is paint+scene conversion; scene is combined plot scene construction; native submission excludes drawing; raster is software or offscreen AppKit CPU drawing",
        "native_presentation": "not_measured",
    },
    "environment": {
        "git_revision": os.environ["MOXI_WORKBENCH_GIT_REVISION"],
        "git_dirty": os.environ["MOXI_WORKBENCH_GIT_DIRTY"] == "1",
        "mojo_version": os.environ["MOXI_WORKBENCH_MOJO_VERSION"],
        "clang_version": os.environ["MOXI_WORKBENCH_CLANG_VERSION"],
        "os": os.environ["MOXI_WORKBENCH_OS"],
        "os_version": os.environ["MOXI_WORKBENCH_OS_VERSION"],
        "architecture": os.environ["MOXI_WORKBENCH_ARCHITECTURE"],
        "host_model": os.environ["MOXI_WORKBENCH_HOST_MODEL"],
        "cpu_brand": os.environ["MOXI_WORKBENCH_HOST_CPU_BRAND"],
        "host_isolation": "not guaranteed; development tasks may overlap; retain raw tails and compare per-process medians",
    },
    "commands": {
        "clock_build": os.environ["MOXI_WORKBENCH_CLOCK_BUILD_COMMAND"],
        "benchmark_build": os.environ["MOXI_WORKBENCH_BUILD_COMMAND"],
        "benchmark_run": os.environ["MOXI_WORKBENCH_RUN_COMMAND"],
        "binary": relative_artifact(os.environ["MOXI_WORKBENCH_BINARY"]),
        "clock_object": relative_artifact(os.environ["MOXI_WORKBENCH_CLOCK_OBJECT"]),
    },
    "artifacts": {
        "records": relative_artifact(str(records)),
        "raw_directory": relative_artifact(str(records.parent / "raw")),
    },
    "process_runs": process_runs,
    "cases": [
        {"rows": rows, "operation": operation, "samples": samples}
        for (rows, operation), samples in sorted(cases.items())
    ],
    "summary": [
        {
            "rows": rows,
            "operation": operation,
            "in_process_elapsed_ms": sample_statistics(
                samples, "in_process_elapsed_ms"
            ),
            "phases": {field: sample_statistics(samples, field) for field in
                       ("dispatch_ms", "retained_ms", "scene_ms", "submission_ms", "raster_ms", "validation_ms")},
            "per_process_elapsed_ms": {str(run): sample_statistics([sample for sample in samples if sample["run"] == run], "in_process_elapsed_ms") for run in range(1, int(os.environ["MOXI_WORKBENCH_RUNS"]) + 1)},
            "process_wall_seconds": sample_statistics(
                samples, "process_wall_seconds"
            ),
            "process_user_seconds": sample_statistics(
                samples, "process_user_seconds"
            ),
            "process_system_seconds": sample_statistics(
                samples, "process_system_seconds"
            ),
            "process_peak_resident_bytes": sample_statistics(
                samples, "process_peak_resident_bytes"
            ),
        }
        for (rows, operation), samples in sorted(cases.items())
    ],
}
output = Path(os.environ["MOXI_WORKBENCH_OUTPUT"])
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"Structured workbench benchmark results: {output}")
print(f"Recorded {len(cases)} cases with {sum(len(v) for v in cases.values())} samples")
PY
