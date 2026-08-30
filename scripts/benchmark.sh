#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

benchmark_runs="${MOXI_BENCHMARK_RUNS:-3}"
if ! [[ "$benchmark_runs" =~ ^[1-9][0-9]*$ ]]; then
  echo "MOXI_BENCHMARK_RUNS must be a positive integer" >&2
  exit 2
fi

run_case() {
  local label="$1"
  shift
  echo "==> $label ($benchmark_runs runs)"
  for ((run = 1; run <= benchmark_runs; run++)); do
    echo "-- $label run $run/$benchmark_runs"
    /usr/bin/time -p "$@"
  done
}

echo "Moxi benchmark harness"
echo "Set MOXI_BENCHMARK_RUNS=1 for a quick check or use the default 3 runs for comparisons."

run_case "retained layout/paint/scene" mojo run -I src benchmarks/layout.mojo
run_case "portable plot scene" mojo run -I src benchmarks/plotting.mojo

# Compile once so the Metal measurements focus on the workload rather than
# repeatedly invoking the Mojo compiler.
pixi run metal-benchmark-build
run_case "offscreen Metal scene" ./dist/moxi-metal-benchmark
