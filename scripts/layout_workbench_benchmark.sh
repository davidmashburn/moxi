#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
mkdir -p dist
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules -c benchmarks/layout_workbench_host.m -o dist/layout_workbench_host.o
clang -O3 -Wall -Wextra -Werror -c native/benchmark_clock.c -o native/benchmark_clock.o
mojo build -I src \
  -Xlinker native/macos_text.o -Xlinker dist/layout_workbench_host.o -Xlinker native/benchmark_clock.o \
  -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a -Xlinker -lc++ \
  -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText \
  benchmarks/layout_workbench.mojo -o dist/moxi-layout-workbench-benchmark
./dist/moxi-layout-workbench-benchmark > dist/layout-workbench-timings.txt
python3 scripts/layout_workbench_benchmark.py dist/layout-workbench-timings.txt dist/layout-workbench-timings.json
