#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v mojo >/dev/null; then
  exec pixi run --locked --manifest-path "${MOXI_PIXI_MANIFEST:-$PWD/pixi.toml}" bash "$PWD/examples/application-operations/build.sh"
fi
dir=examples/application-operations
out=dist/application-operations
mkdir -p "$out"
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c "$dir/host.m" -o "$out/host.o"
mojo build -I src -Xlinker "$out/host.o" -Xlinker -framework -Xlinker Cocoa "$dir/main.mojo" -o "$out/notebook"
