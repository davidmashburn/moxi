#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
out=dist/visible-proposals
mkdir -p "$out"
case "${1:-run}" in
  run) entry=window; host=native/macos_window.m ;;
  check) entry=check; host=tests/native_lifecycle_probe.m ;;
  *) echo "usage: $0 [run|check]" >&2; exit 2 ;;
esac
clang -O2 -fobjc-arc -fmodules -c "$host" -o "$out/$entry.o"
mojo build -I src -Xlinker "$out/$entry.o" -Xlinker -framework -Xlinker Cocoa \
  "examples/visible-proposals/$entry.mojo" -o "$out/$entry"
exec "$out/$entry"
