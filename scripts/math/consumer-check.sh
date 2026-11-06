#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="${MOXI_D02_BUILD_DIR:-/tmp/moxi-d02}"
hb="${MOXI_HARFBUZZ_PREFIX:-/opt/homebrew/opt/harfbuzz}"
mkdir -p "$work"
bash "$repo/scripts/math/package.sh" > "$work/package-build.log" 2>&1
consumer="$(mktemp -d /tmp/moxi-math-consumer.XXXXXX)"
mkdir "$consumer/install"
tar -xzf "$work/moxi-math-local.tar.gz" -C "$consumer/install"
cp "$repo/tests/math/consumer.mojo" "$consumer/main.mojo"
# Resolve the compiler environment, then leave the checkout. No -I src or private imports.
/usr/bin/time -p pixi run --manifest-path "$repo/pixi.toml" --frozen bash -c '
  cd "$1"
  mojo build -I install/lib/mojo main.mojo -Xlinker install/lib/libmoxi_math_native.a -Xlinker "$2/lib/libharfbuzz.dylib" -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText -o consumer
' _ "$consumer" "$hb" > "$work/installed-consumer-build.log" 2>&1
cd "$consumer"
./consumer > "$work/installed-consumer-test.log" 2>&1
printf 'PASS source-free archive installation and native consumer in %s\n' "$consumer"
