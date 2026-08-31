#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# The Android source retains a non-Android syntax path so host contract changes
# are checked on macOS. When the SDK/NDK are installed, the native APK target
# below also compiles, packages, signs, and inspects the platform artifact.
clang++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
  native/hosts/moxi_android_host.cpp

android_sdk_root="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
android_ndk_root="${ANDROID_NDK_HOME:-/opt/homebrew/share/android-ndk}"
if [ -f "$android_sdk_root/platforms/android-35/android.jar" ] && \
   [ -f "$android_ndk_root/build/cmake/android.toolchain.cmake" ]; then
  java_available=false
  if command -v javac >/dev/null 2>&1 || \
     [ -x "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/javac" ]; then
    java_available=true
  fi
  if [ "$java_available" = true ] && \
     [ -x "$android_sdk_root/build-tools/35.0.0/d8" ]; then
    bash scripts/android_build.sh
  else
    echo "Moxi Android APK build skipped: Java compiler/runtime unavailable"
  fi
else
  echo "Moxi Android host build skipped: Android SDK/NDK unavailable"
fi

rg -q "AccessibilityNodeProvider|ACTION_SET_TEXT" \
  native/android/src/main/java/org/moxi/host/MoxiActivity.java
rg -q "UIAccessibilityElement|moxi_ios_host_set_accessibility_node" \
  native/hosts/moxi_ios_host.m native/hosts/moxi_ios_host.h

ios_developer_dir=""
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  ios_developer_dir=/Applications/Xcode.app/Contents/Developer
fi
if ios_sdk="$(DEVELOPER_DIR="$ios_developer_dir" xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)"; then
  DEVELOPER_DIR="$ios_developer_dir" xcrun --sdk iphonesimulator clang \
    -Wall -Wextra -Werror -fobjc-arc -fmodules -fsyntax-only \
    -isysroot "$ios_sdk" native/hosts/moxi_ios_host.m
  if [ -d native/ios/MoxiHost.xcodeproj ]; then
    bash scripts/ios_build.sh
  fi
else
  echo "Moxi iOS host check skipped: iPhone simulator SDK unavailable"
fi

node tests/web_host.mjs
echo "Moxi host checks passed"
