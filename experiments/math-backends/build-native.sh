#!/usr/bin/env bash
# Local task dependencies only. Pin and checksum the upstream source archive.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${MOXI_MATH_BUILD_DIR:-/tmp/moxi-d01}"
manifest="${MOXI_MOJO_MANIFEST:-$here/../../pixi.toml}"
mkdir -p "$work"
archive="$work/symengine-0.14.0.tar.gz"
if [[ ! -f "$archive" ]]; then
  curl -L --fail https://codeload.github.com/symengine/symengine/tar.gz/refs/tags/v0.14.0 -o "$archive"
fi
printf '%s  %s\n' 11c5f64e9eec998152437f288b8429ec001168277d55f3f5f1df78e3cf129707 "$archive" | shasum -a 256 -c -
if [[ ! -d "$work/symengine-0.14.0" ]]; then tar -xzf "$archive" -C "$work"; fi
cmake -S "$work/symengine-0.14.0" -B "$work/build" \
  -DCMAKE_INSTALL_PREFIX="$work/prefix" -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON -DWITH_SYMENGINE_THREAD_SAFE=ON -DINTEGER_CLASS=gmp \
  -DWITH_SYMENGINE_RCP=ON -DBUILD_TESTS=OFF -DBUILD_BENCHMARKS=OFF \
  -DCMAKE_PREFIX_PATH="${MOXI_GMP_PREFIX:-/opt/homebrew}" > "$work/configure.log" 2>&1
cmake --build "$work/build" -j "${MOXI_BUILD_JOBS:-4}" > "$work/build.log" 2>&1
cmake --install "$work/build" > "$work/install.log" 2>&1
clang -Wall -Wextra -Werror -I "$work/prefix/include" -I "${MOXI_GMP_PREFIX:-/opt/homebrew}/include" \
  -c "$here/native/bridge.c" -o "$work/bridge.o"
case "$(uname -s)" in
  Darwin) library="$work/prefix/lib/libsymengine.dylib" ;;
  Linux) library="$work/prefix/lib/libsymengine.so" ;;
  *) echo 'Only macOS/Linux build recipes are defined' >&2; exit 1 ;;
esac
pixi run --manifest-path "$manifest" --frozen mojo build "$here/native/worker.mojo" \
  -Xlinker "$work/bridge.o" -Xlinker "$library" -Xlinker -rpath -Xlinker "$work/prefix/lib" \
  -o "$work/symengine-worker" > "$work/worker-build.log" 2>&1
printf 'Worker: %s\nLogs: %s\n' "$work/symengine-worker" "$work"
