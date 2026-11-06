#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/spatial-assembly/check.sh "$@"; fi
bash examples/spatial-assembly/build.sh > /tmp/moxi-d07-build.log 2>&1
for test in contract assembly; do
  clang++ -std=c++20 -O2 -Wall -Wextra -Werror native/spatial/core.cpp "tests/spatial/$test.cpp" -o "dist/spatial-assembly/$test-test"
  "dist/spatial-assembly/$test-test" > "/tmp/moxi-d07-$test.log" 2>&1
  tail -1 "/tmp/moxi-d07-$test.log"
done
for test in native assembly_native; do
  clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c "tests/spatial/$test.m" -o "dist/spatial-assembly/$test.o"
  clang++ dist/spatial-explorer/{core,api,renderer,text}.o "dist/spatial-assembly/$test.o" -framework Cocoa -framework CoreText -framework Metal -framework QuartzCore -o "dist/spatial-assembly/$test-test"
  "dist/spatial-assembly/$test-test" > "/tmp/moxi-d07-$test.log" 2>&1
  tail -1 "/tmp/moxi-d07-$test.log"
done
consumer=$(mktemp -d /tmp/moxi-d07-consumer.XXXXXX)
cp dist/spatial-explorer/moxi_spatial.mojoc "$consumer/"
mojo precompile -I src src/moxi -o "$consumer/moxi.mojoc" > /tmp/moxi-d07-moxi-package.log 2>&1
mojolink=()
for object in dist/spatial-explorer/libmoxi_spatial.a dist/spatial-explorer/window.o dist/spatial-explorer/text.o; do mojolink+=(-Xlinker "$PWD/$object"); done
for framework in Cocoa CoreText Metal QuartzCore; do mojolink+=(-Xlinker -framework -Xlinker "$framework"); done
for test in public_consumer public_assembly; do
  cp "tests/spatial/$test.mojo" "$consumer/main.mojo"
  mojo build -I "$consumer" "${mojolink[@]}" -Xlinker -lc++ "$consumer/main.mojo" -o "$consumer/$test" > "/tmp/moxi-d07-$test-build.log" 2>&1
  "$consumer/$test" > "/tmp/moxi-d07-$test.log" 2>&1
  tail -1 "/tmp/moxi-d07-$test.log"
done
mojo build -I src "${mojolink[@]}" -Xlinker -lc++ tests/spatial/public_composition.mojo -o dist/spatial-assembly/public-composition > /tmp/moxi-d07-public-composition-build.log 2>&1
./dist/spatial-assembly/public-composition > /tmp/moxi-d07-public-composition.log 2>&1
tail -1 /tmp/moxi-d07-public-composition.log
mkdir -p /tmp/moxi-d07-explorer-replay
# Build both complete apps outside the source tree with only packaged imports.
for app in spatial-explorer spatial-assembly; do
  cp "examples/$app/main.mojo" "$consumer/main.mojo"
  link=(-Xlinker "$PWD/dist/$app/host.o" -Xlinker "$PWD/dist/spatial-explorer/libmoxi_spatial.a" -Xlinker "$PWD/dist/spatial-explorer/text.o")
  for framework in Cocoa CoreText Metal QuartzCore; do link+=(-Xlinker -framework -Xlinker "$framework"); done
  mojo build -I "$consumer" "${link[@]}" -Xlinker -lc++ "$consumer/main.mojo" -o "$consumer/$app" > "/tmp/moxi-d07-packaged-$app-build.log" 2>&1
done
"$consumer/spatial-explorer" --replay /tmp/moxi-d07-explorer-replay > /tmp/moxi-d07-explorer-replay.log 2>&1
tail -1 /tmp/moxi-d07-explorer-replay.log
mkdir -p /tmp/moxi-d07-packaged-assembly-replay
"$consumer/spatial-assembly" --replay /tmp/moxi-d07-packaged-assembly-replay > /tmp/moxi-d07-packaged-assembly-replay.log 2>&1
tail -1 /tmp/moxi-d07-packaged-assembly-replay.log
printf 'PASS D07 focused checks; clean packaged directory %s; full logs /tmp/moxi-d07-*\n' "$consumer"
