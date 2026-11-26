#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
target=${1:?expected target}
object=${2:?expected object file}
dump=${LLVM_OBJDUMP:-$(command -v llvm-objdump || command -v objdump)}
require_line() {
  if ! grep -Eq "$1" <<<"$report"; then
    echo "$target: expected $2 in $object" >&2
    exit 1
  fi
}
case "$target" in
  android)
    report=$(file -b "$object")
    require_line '^ELF 64-bit LSB relocatable, ARM aarch64,' 'an AArch64 ELF relocatable'
    report=$("$dump" -t "$object")
    require_line ' g[[:space:]]+F[[:space:]]+\.text[[:space:]]+[[:xdigit:]]+[[:space:]]+moxi_mobile_increment$' 'the exported counter function'
    ;;
  ios-device|ios-simulator)
    platform=ios
    if [[ "$target" == ios-simulator ]]; then platform=iossimulator; fi
    report=$("$dump" --macho --private-headers --syms "$object")
    require_line '^MH_MAGIC_64[[:space:]]+ARM64[[:space:]].*[[:space:]]OBJECT[[:space:]]' 'an ARM64 Mach-O object'
    require_line "^[[:space:]]*platform[[:space:]]+$platform$" "$platform platform"
    require_line '^[[:space:]]*minos[[:space:]]+17\.0$' 'minimum OS 17.0'
    require_line ' g[[:space:]]+F[[:space:]]+__TEXT,__text[[:space:]]+_moxi_mobile_increment$' 'the exported counter function'
    ;;
  *) echo "unknown mobile target: $target" >&2; exit 2 ;;
esac
echo "$target: target metadata and exported counter verified"
