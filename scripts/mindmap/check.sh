#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mode=${1:-contract}
mkdir -p dist
case "$mode" in
  contract)
    for part in model layout application failures reflow reflow_exact; do
      mojo run -I "$PWD/src" "tests/mindmap/$part.mojo" > "/tmp/moxi-d04-$part.log" 2>&1
      tail -n 1 "/tmp/moxi-d04-$part.log"
    done
    python3 tests/mindmap/reference_test.py > /tmp/moxi-d04-reference-inventory.log 2>&1
    cat /tmp/moxi-d04-reference-inventory.log ;;
  import)
    clang -shared -fobjc-arc -Wall -Wextra -Werror native/mindmap/storage.m -framework Cocoa -o dist/moxi-mindmap-storage.dylib > /tmp/moxi-d04-storage-build.log 2>&1
    python3 tests/mindmap/storage_test.py "$PWD/dist/moxi-mindmap-storage.dylib" > /tmp/moxi-d04-storage-test.log 2>&1
    cat /tmp/moxi-d04-storage-test.log
    clang -c -fobjc-arc -Wall -Wextra -Werror native/mindmap/storage.m -o dist/mindmap-storage.o > /tmp/moxi-d04-save-session-build.log 2>&1
    mojo build -I src -Xlinker "$PWD/dist/mindmap-storage.o" -Xlinker -framework -Xlinker Cocoa tests/mindmap/save_session.mojo -o dist/moxi-mindmap-save-session >> /tmp/moxi-d04-save-session-build.log 2>&1
    session_dir=$(mktemp -d /tmp/moxi-d04-save-session.XXXXXX)
    trap 'rm -rf "$session_dir"' EXIT
    ./dist/moxi-mindmap-save-session "$session_dir" > /tmp/moxi-d04-save-session.log 2>&1
    cat /tmp/moxi-d04-save-session.log ;;
  build|capture|app)
    if [[ "$mode" == capture ]]; then
      capture_snapshot=$(mktemp /tmp/moxi-d04-capture-sources.XXXXXX)
      python3 scripts/mindmap/manifest.py --snapshot "$capture_snapshot"
    fi
    clang -c -fobjc-arc native/macos_text.m -o dist/mindmap-text.o > /tmp/moxi-d04-text-clang.log 2>&1
    clang -c -fobjc-arc native/macos_window.m -o dist/mindmap-window.o > /tmp/moxi-d04-native-clang.log 2>&1
    clang -c -fobjc-arc -Wall -Wextra -Werror native/mindmap/storage.m -o dist/mindmap-storage.o >> /tmp/moxi-d04-native-clang.log 2>&1
    clang -c -fobjc-arc -Wall -Wextra -Werror native/mindmap/capture.m -o dist/mindmap-capture.o >> /tmp/moxi-d04-native-clang.log 2>&1
    mojo build -I "$PWD/src" -Xlinker "$PWD/dist/mindmap-window.o" -Xlinker "$PWD/dist/mindmap-text.o" -Xlinker -framework -Xlinker CoreText -Xlinker "$PWD/dist/mindmap-storage.o" -Xlinker "$PWD/dist/mindmap-capture.o" -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker QuartzCore examples/mindmap_native_app.mojo -o dist/moxi-mindmap > /tmp/moxi-d04-native-build.log 2>&1
    if [[ "$mode" == capture ]]; then
      gallery="$PWD/artifacts/demo-slideshows/mindmap"
      mkdir -p "$gallery"
      ./dist/moxi-mindmap --capture "$gallery" > /tmp/moxi-d04-native-replay.log 2>&1
      python3 scripts/mindmap/manifest.py --from-snapshot "$capture_snapshot" > /tmp/moxi-d04-manifest.log 2>&1
      python3 - <<'BUILD' >> /tmp/moxi-d04-manifest.log 2>&1
import sys
from pathlib import Path
sys.path.insert(0, 'scripts')
from demo_slideshows import load_manifest, render
root = Path('artifacts/demo-slideshows/mindmap')
(root / 'index.html').write_text(render(load_manifest(root / 'manifest.json')))
print('Validated and rendered mindmap schema v1')
BUILD
      tail -n 2 /tmp/moxi-d04-native-replay.log
    elif [[ "$mode" == app ]]; then
      ./dist/moxi-mindmap
    fi ;;
  consumer)
    clean=$(mktemp -d /tmp/moxi-d04-consumer.XXXXXX)
    mojo precompile -I src src/moxi -o "$clean/moxi.mojoc" > /tmp/moxi-d04-package-core.log 2>&1
    mojo precompile -I "$clean" src/moxi_canvas -o "$clean/moxi_canvas.mojoc" > /tmp/moxi-d04-package-canvas.log 2>&1
    mojo precompile -I "$clean" src/moxi_mindmap -o "$clean/moxi_mindmap.mojoc" > /tmp/moxi-d04-package-mindmap.log 2>&1
    cp tests/mindmap/consumer.mojo "$clean/main.mojo"
    (cd "$clean" && mojo run -I "$clean" main.mojo) > /tmp/moxi-d04-consumer.log 2>&1
    cat /tmp/moxi-d04-consumer.log ;;
  benchmark)
    mojo run -I src tests/mindmap/benchmark.mojo > /tmp/moxi-d04-benchmark.log 2>&1
    mojo run -I src tests/mindmap/app_benchmark.mojo > /tmp/moxi-d04-app-benchmark.log 2>&1
    cat /tmp/moxi-d04-benchmark.log /tmp/moxi-d04-app-benchmark.log ;;
  *) echo 'contract|import|build|capture|app|consumer|benchmark'; exit 2 ;;
esac
