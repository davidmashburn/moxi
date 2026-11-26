#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then
  exec pixi run --locked --manifest-path "${MOXI_PIXI_MANIFEST:-$PWD/pixi.toml}" bash "$PWD/examples/investigation-tools/build.sh"
fi
dir=examples/investigation-tools
out=dist/investigation-tools
mkdir -p "$out"
mojo --version
clang --version
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c "$dir/host.m" -o "$out/host.o"
mojo build -I src -I examples/application-operations -Xlinker "$out/host.o" -Xlinker -framework -Xlinker Cocoa "$dir/main.mojo" -o "$out/investigation"
mojo build -I src -I examples/application-operations -Xlinker "$out/host.o" -Xlinker -framework -Xlinker Cocoa "$dir/tests.mojo" -o "$out/model-tests"
