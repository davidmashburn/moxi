#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export LC_ALL=C SOURCE_DATE_EPOCH=0

[[ "$(uname -sm)" == 'Linux x86_64' ]] || {
  echo 'FAIL: the locked crossbuild requires Linux x86_64' >&2
  exit 1
}
# shellcheck source=/dev/null
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || {
  echo 'FAIL: the crossbuild requires Ubuntu 24.04' >&2
  exit 1
}

out=dist/windows-host
dll_name=moxi-counter
mojo --version
lld -flavor link --version
echo 'CONTROL: existing mobile counter, native Linux C caller'
bash experiments/mobile-runtime/probe.sh host

for architecture in AMD64 ARM64; do
  case "$architecture" in
    AMD64) triple=x86_64-pc-windows-msvc; machine=x64 ;;
    ARM64) triple=aarch64-pc-windows-msvc; machine=arm64 ;;
  esac
  target_out="$out/$architecture"
  mkdir -p "$target_out"
  # Remove only this probe's outputs so a failed build cannot reuse an old result.
  rm -f "$target_out/counter.obj" "$target_out/$dll_name.dll" "$target_out/$dll_name.lib"
  echo "TARGET: $architecture $triple"
  mojo build -I src --target-triple "$triple" --emit object \
    experiments/mobile-runtime/counter.mojo -o "$target_out/counter.obj"
  lld -flavor link /dll /noentry /nodefaultlib /timestamp:0 \
    "/machine:$machine" /export:moxi_mobile_increment \
    "/out:$target_out/$dll_name.dll" "/implib:$target_out/$dll_name.lib" \
    "$target_out/counter.obj"
  file "$target_out/counter.obj" "$target_out/$dll_name.dll" "$target_out/$dll_name.lib"
  python3 experiments/windows-host/inspect_artifacts.py "$architecture" "$target_out" --object
  sha256sum "$target_out/$dll_name.dll" "$target_out/$dll_name.lib"
done
