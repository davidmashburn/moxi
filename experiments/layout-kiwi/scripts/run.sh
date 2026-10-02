#!/usr/bin/env bash
# Run from any directory. Artifacts and fetched headers stay inside the experiment.
set -euo pipefail
experiment_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(cd "$experiment_dir/../.." && pwd)"
cd "$repo_dir"
bash "$experiment_dir/scripts/build.sh"
build_dir="${LAYOUT_KIWI_BUILD_DIR:-$experiment_dir/build}"
"$build_dir/bridge_test"
cc -std=c11 -O3 -Wall -Wextra -Werror -I "$experiment_dir/include" \
  "$experiment_dir/tests/c_smoke.c" "$build_dir/liblayout_kiwi.a" -lc++ -o "$build_dir/c_smoke"
"$build_dir/c_smoke"
"${CXX:-clang++}" -std=c++17 -O3 -Wall -Wextra -Wpedantic -Werror \
  -I "$experiment_dir/vendor/kiwi/include" "$experiment_dir/src/fixtures.cpp" \
  -o "$build_dir/fixtures"
"$build_dir/fixtures" > "$build_dir/fixtures.json"
python3 "$experiment_dir/tests/fixtures_test.py" "$build_dir/fixtures.json"
cc -std=c11 -O3 -Wall -Wextra -Werror -c "$experiment_dir/src/clock.c" -o "$build_dir/clock.o"
pixi run mojo build -I src -Xlinker "$build_dir/liblayout_kiwi.a" \
  -Xlinker "$build_dir/clock.o" -Xlinker -lc++ \
  "$experiment_dir/mojo/comparison.mojo" -o "$build_dir/comparison"
"$build_dir/comparison" > "$build_dir/comparison.txt"
python3 "$experiment_dir/scripts/summarize.py" "$build_dir/comparison.txt" > "$build_dir/comparison.json"
printf 'Verified results: %s\n' "$build_dir/fixtures.json" "$build_dir/comparison.json"
