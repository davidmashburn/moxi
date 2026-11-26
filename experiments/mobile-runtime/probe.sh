#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
out=dist/mobile-runtime
mkdir -p "$out"
source_path=experiments/mobile-runtime/counter.mojo
case "${1:-host}" in
  host)
    mojo build -I src --emit object "$source_path" -o "$out/host.o"
    "${CC:-cc}" experiments/mobile-runtime/check.c "$out/host.o" -o "$out/check"
    "$out/check"
    exit 0
    ;;
  ios-simulator) triple=arm64-apple-ios17.0-simulator ;;
  ios-device) triple=arm64-apple-ios17.0 ;;
  android) triple=aarch64-linux-android26 ;;
  *) echo "usage: $0 [host|ios-simulator|ios-device|android]" >&2; exit 2 ;;
esac
mojo build -I src --target-triple "$triple" --emit object "$source_path" -o "$out/$triple.o"
bash experiments/mobile-runtime/check-object.sh "$1" "$out/$triple.o"
