#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# The Android source deliberately has a non-Android compile path so host
# contract changes are still checked on macOS. When an NDK is installed, the
# platform-specific input decoder can be checked by the developer's NDK build.
clang++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
  native/hosts/moxi_android_host.cpp

if xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
  ios_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  clang -Wall -Wextra -Werror -fobjc-arc -fmodules -fsyntax-only \
    -isysroot "$ios_sdk" native/hosts/moxi_ios_host.m
else
  echo "Moxi iOS host check skipped: iPhone simulator SDK unavailable"
fi

node tests/web_host.mjs
echo "Moxi host checks passed"
