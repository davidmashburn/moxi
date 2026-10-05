#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
mkdir -p dist/native
profile="${MOXI_LAYOUT_BENCHMARK_PROFILE:-full}"
case "$profile" in
  full) samples=120; warmup=10; profile_id=0; suffix="" ;;
  smoke) samples=8; warmup=2; profile_id=1; suffix="-smoke" ;;
  *) echo "Unknown MOXI_LAYOUT_BENCHMARK_PROFILE: $profile (expected full or smoke)" >&2; exit 2 ;;
esac

case "$(uname -s)" in
  Darwin)
    backend=2
    cc_tool="${CC:-clang}"
    "$cc_tool" -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
      -c native/macos_text.m -o dist/native/layout_benchmark_text.o
    "$cc_tool" -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
      -c benchmarks/layout_workbench_host.m -o dist/layout_workbench_host.o
    bash experiments/layout-kiwi/scripts/build.sh
    text_object=dist/native/layout_benchmark_text.o
    links=(-Xlinker -lc++
      -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText)
    ;;
  Linux)
    backend=5
    cc_tool="${CC:-cc}"
    bash scripts/linux_native_build.sh --objects
    read -r -a gtk_cflags <<< "$(pkg-config --cflags gtk4)"
    read -r -a gtk_libs <<< "$(pkg-config --libs gtk4)"
    "$cc_tool" -std=c11 -O3 -Wall -Wextra -Werror "${gtk_cflags[@]}" \
      -c benchmarks/layout_workbench_host.c -o dist/layout_workbench_host.o
    text_object=dist/native/linux_text.o
    links=(-Xlinker -lstdc++ -Xlinker -lm)
    for flag in "${gtk_libs[@]}"; do links+=(-Xlinker "$flag"); done
    ;;
  *) echo "Moxi layout benchmark requires Darwin or Linux." >&2; exit 1 ;;
esac
"$cc_tool" -O3 -Wall -Wextra -Werror -c native/benchmark_clock.c -o dist/native/layout_benchmark_clock.o
mojo build -I src \
  -D "MOXI_BENCHMARK_BACKEND=$backend" -D "MOXI_BENCHMARK_SAMPLES=$samples" \
  -D "MOXI_BENCHMARK_WARMUP=$warmup" -D "MOXI_BENCHMARK_PROFILE=$profile_id" \
  -Xlinker "$text_object" -Xlinker dist/layout_workbench_host.o -Xlinker dist/native/layout_benchmark_clock.o \
  -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a "${links[@]}" \
  benchmarks/layout_workbench.mojo -o dist/moxi-layout-workbench-benchmark
./dist/moxi-layout-workbench-benchmark > "dist/layout-workbench-timings${suffix}.txt"
python3 scripts/layout_workbench_benchmark.py \
  "dist/layout-workbench-timings${suffix}.txt" "dist/layout-workbench-timings${suffix}.json"
