#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode=${1:-check}
log_prefix=${MOXI_CANVAS_LOG_PREFIX:-/tmp/moxi-d03}
mkdir -p dist
case "$mode" in
  check)
    for test in canvas_contract canvas_graph_contract canvas_keyboard_contract canvas_geometry_contract; do
      mojo run -I "$PWD/src" -I "$PWD/examples" "$PWD/tests/$test.mojo" > "${log_prefix}-$test.log" 2>&1
      tail -n 3 "${log_prefix}-$test.log"
    done
    ;;
  consumer)
    clean_dir=$(mktemp -d "${log_prefix}-consumer".XXXXXX)
    mojo precompile -I "$PWD/src" "$PWD/src/moxi" -o "$clean_dir/moxi.mojoc" > "${log_prefix}-package-core.log" 2>&1
    mojo precompile -I "$clean_dir" "$PWD/src/moxi_canvas" -o "$clean_dir/moxi_canvas.mojoc" > "${log_prefix}-package-canvas.log" 2>&1
    cp tests/canvas_consumer.mojo "$clean_dir/main.mojo"
    (cd "$clean_dir" && mojo run -I "$clean_dir" main.mojo) > "${log_prefix}-consumer-clean.log" 2>&1
    cat "${log_prefix}-consumer-clean.log"
    ;;
  layers)
    clang -O1 -Wall -Wextra -Werror -fobjc-arc -fmodules tests/canvas/native_layers.m -framework Cocoa -o dist/moxi-canvas-native-layers > "${log_prefix}-layer-build.log" 2>&1
    ./dist/moxi-canvas-native-layers > "${log_prefix}-layers.log" 2>&1
    cat "${log_prefix}-layers.log"
    ;;
  build|capture)
    clang -c -fobjc-arc native/macos_window.m -o dist/canvas_window.o > "${log_prefix}-clang.log" 2>&1
    clang -c -fobjc-arc tests/canvas/capture.m -o dist/canvas_capture.o >> "${log_prefix}-clang.log" 2>&1
    for demo in probe graph; do
      mojo build -I "$PWD/src" -I "$PWD/examples" -Xlinker "$PWD/dist/canvas_window.o" -Xlinker "$PWD/dist/canvas_capture.o" -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker QuartzCore "$PWD/examples/canvas_$demo.mojo" -o "$PWD/dist/moxi-canvas-$demo" > "${log_prefix}-native-$demo-build.log" 2>&1
      if [[ "$mode" == capture ]]; then
        gallery=canvas-graph
        [[ "$demo" != probe ]] || gallery=canvas-rich-node
        mkdir -p "artifacts/demo-slideshows/$gallery"
        "./dist/moxi-canvas-$demo" --capture "$PWD/artifacts/demo-slideshows/$gallery" > "${log_prefix}-$demo-capture.log" 2>&1
        cat "${log_prefix}-$demo-capture.log"
      fi
    done
    ;;
  benchmark)
    mojo run -I "$PWD/src" -I "$PWD/examples" "$PWD/tests/canvas_benchmark.mojo" > "${log_prefix}-benchmark.log" 2>&1
    cat "${log_prefix}-benchmark.log"
    ;;
  *) echo "Usage: $0 check|consumer|layers|build|capture|benchmark" >&2; exit 2 ;;
esac
