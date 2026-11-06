#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/spatial-world-panel/check.sh "$@"; fi
if [[ ${1:-} != --skip-build ]]; then bash examples/spatial-world-panel/build.sh > /tmp/moxi-d08-build.log 2>&1; fi
for test in panel contract assembly; do
  clang++ -std=c++20 -O2 -Wall -Wextra -Werror native/spatial/core.cpp "tests/spatial/$test.cpp" -o "/tmp/moxi-d08-$test"
  "/tmp/moxi-d08-$test" > "/tmp/moxi-d08-$test.log" 2>&1
  tail -1 "/tmp/moxi-d08-$test.log"
done
for test in panel_native native assembly_native; do
  clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c "tests/spatial/$test.m" -o "/tmp/moxi-d08-$test.o"
  clang++ dist/spatial-explorer/{core,api,renderer,text}.o "/tmp/moxi-d08-$test.o" -framework Cocoa -framework CoreText -framework Metal -framework QuartzCore -o "/tmp/moxi-d08-$test"
  "/tmp/moxi-d08-$test" > "/tmp/moxi-d08-$test.log" 2>&1
  tail -1 "/tmp/moxi-d08-$test.log"
done
consumer=$(mktemp -d /tmp/moxi-d08-consumer.XXXXXX)
cp dist/spatial-explorer/moxi_spatial.mojoc "$consumer/"
mojo precompile -I src src/moxi -o "$consumer/moxi.mojoc" > /tmp/moxi-d08-package.log 2>&1
cp dist/spatial-explorer/{libmoxi_spatial.a,window.o,text.o,host.o} "$consumer/"
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c examples/spatial-assembly/host.m -o "$consumer/assembly-host.o"
cp dist/spatial-world-panel/host.o "$consumer/panel-host.o"
link=(-Xlinker "$consumer/libmoxi_spatial.a" -Xlinker "$consumer/text.o" -Xlinker -lc++)
for framework in Cocoa CoreText Metal QuartzCore; do link+=(-Xlinker -framework -Xlinker "$framework"); done
for test in public_panel public_consumer public_assembly public_composition; do
  cp "tests/spatial/$test.mojo" "$consumer/main.mojo"
  (cd "$consumer"; mojo build -I . "${link[@]}" -Xlinker window.o main.mojo -o "$test") > "/tmp/moxi-d08-$test-build.log" 2>&1
  "$consumer/$test" > "/tmp/moxi-d08-$test.log" 2>&1
  tail -1 "/tmp/moxi-d08-$test.log"
done
for app in spatial-world-panel spatial-explorer spatial-assembly; do
  cp "examples/$app/main.mojo" "$consumer/main.mojo"
  case "$app" in
    spatial-world-panel) host=panel-host.o; cp examples/spatial-world-panel/controls.mojo "$consumer/controls.mojo" ;;
    spatial-explorer) host=host.o ;;
    spatial-assembly) host=assembly-host.o ;;
  esac
  (cd "$consumer"; mojo build -I . "${link[@]}" -Xlinker "$host" main.mojo -o "$app") > "/tmp/moxi-d08-packaged-$app-build.log" 2>&1
  mkdir -p "/tmp/moxi-d08-packaged-$app"
  "$consumer/$app" --replay "/tmp/moxi-d08-packaged-$app" > "/tmp/moxi-d08-packaged-$app.log" 2>&1
  tail -1 "/tmp/moxi-d08-packaged-$app.log"
done
printf 'PASS D08 and focused D06/D07 checks; source-free import directory %s\n' "$consumer"
