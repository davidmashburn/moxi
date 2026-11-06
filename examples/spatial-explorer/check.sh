#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then exec pixi run bash examples/spatial-explorer/check.sh "$@"; fi
bash examples/spatial-explorer/build.sh > /tmp/moxi-d06-build.log 2>&1
clang++ -std=c++20 -O2 -Wall -Wextra -Werror native/spatial/core.cpp tests/spatial/contract.cpp -o dist/spatial-explorer/contract
./dist/spatial-explorer/contract > /tmp/moxi-d06-contract.log 2>&1
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c tests/spatial/native.m -o dist/spatial-explorer/native-test.o
link=(dist/spatial-explorer/core.o dist/spatial-explorer/api.o dist/spatial-explorer/renderer.o dist/spatial-explorer/text.o)
clang++ "${link[@]}" dist/spatial-explorer/native-test.o -framework Cocoa -framework CoreText -framework Metal -framework QuartzCore -o dist/spatial-explorer/native-test
./dist/spatial-explorer/native-test > /tmp/moxi-d06-native.log 2>&1
# No src include: exercise the precompiled public module from a clean directory.
consumer=$(mktemp -d /tmp/moxi-d06-consumer.XXXXXX)
cp tests/spatial/public_consumer.mojo "$consumer/main.mojo"
cp dist/spatial-explorer/moxi_spatial.mojoc "$consumer/"
mojolink=()
for object in dist/spatial-explorer/libmoxi_spatial.a dist/spatial-explorer/window.o dist/spatial-explorer/text.o; do mojolink+=(-Xlinker "$PWD/$object"); done
for framework in Cocoa CoreText Metal QuartzCore; do mojolink+=(-Xlinker -framework -Xlinker "$framework"); done
mojo build -I "$consumer" "${mojolink[@]}" -Xlinker -lc++ "$consumer/main.mojo" -o "$consumer/consumer"
"$consumer/consumer" > /tmp/moxi-d06-consumer.log 2>&1
mojo build -I src "${mojolink[@]}" -Xlinker -lc++ tests/spatial/public_composition.mojo -o dist/spatial-explorer/public-composition
./dist/spatial-explorer/public-composition > /tmp/moxi-d06-public-composition.log 2>&1
printf 'PASS spatial-contract, spatial-interaction, native composition, public consumer; logs /tmp/moxi-d06-{contract,native,consumer}.log\n'
