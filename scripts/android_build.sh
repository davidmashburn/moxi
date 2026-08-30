#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

sdk_root="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
ndk_root="${ANDROID_NDK_HOME:-/opt/homebrew/share/android-ndk}"
if [ -z "${JAVA_HOME:-}" ] && [ -d /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ]; then
  JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
fi
if [ -n "${JAVA_HOME:-}" ]; then
  export JAVA_HOME
  export PATH="$JAVA_HOME/bin:$PATH"
fi
api_level="${MOXI_ANDROID_API:-35}"
abi="${MOXI_ANDROID_ABI:-arm64-v8a}"
build_dir="${MOXI_ANDROID_BUILD_DIR:-output/android}"
cmake_bin="${CMAKE:-cmake}"
android_jar="$sdk_root/platforms/android-$api_level/android.jar"
build_tools="$sdk_root/build-tools/35.0.0"

case "$build_dir" in
  /*) ;;
  *) build_dir="$repo_dir/$build_dir" ;;
esac

if [ ! -f "$android_jar" ]; then
  echo "Android SDK platform missing: $android_jar" >&2
  exit 1
fi
if [ ! -f "$ndk_root/build/cmake/android.toolchain.cmake" ]; then
  echo "Android NDK missing: $ndk_root" >&2
  exit 1
fi

cmake_dir="$build_dir/cmake-$abi"
classes_dir="$build_dir/classes"
dex_dir="$build_dir/dex"
package_dir="$build_dir/package"
unsigned_apk="$build_dir/moxi-host-unsigned.apk"
aligned_apk="$build_dir/moxi-host-aligned.apk"
apk="$build_dir/moxi-host-debug.apk"
keystore="$build_dir/debug.keystore"

mkdir -p "$classes_dir" "$dex_dir" "$package_dir/lib/$abi"

"$cmake_bin" -S native/android -B "$cmake_dir" \
  -DANDROID_ABI="$abi" \
  -DANDROID_PLATFORM="android-$api_level" \
  -DCMAKE_TOOLCHAIN_FILE="$ndk_root/build/cmake/android.toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release
"$cmake_bin" --build "$cmake_dir" --config Release

cp "$cmake_dir/libmoxi_host.so" "$package_dir/lib/$abi/libmoxi_host.so"

javac -source 8 -target 8 -Xlint:-options -encoding UTF-8 \
  -classpath "$android_jar" \
  -d "$classes_dir" \
  native/android/src/main/java/org/moxi/host/MoxiActivity.java

"$build_tools/d8" \
  --lib "$android_jar" \
  --min-api 26 \
  --output "$dex_dir" \
  "$classes_dir/org/moxi/host/MoxiActivity.class" \
  "$classes_dir/org/moxi/host/MoxiActivity\$MoxiSurface.class" \
  "$classes_dir/org/moxi/host/MoxiActivity\$MoxiCanvas.class"

cp "$dex_dir/classes.dex" "$package_dir/classes.dex"
"$build_tools/aapt2" link \
  -o "$unsigned_apk" \
  -I "$android_jar" \
  --manifest native/android/AndroidManifest.xml \
  --min-sdk-version 26 \
  --target-sdk-version "$api_level" \
  --version-code 1 \
  --version-name 0.6.0

(cd "$package_dir" && zip -q -r "$unsigned_apk" classes.dex lib)
"$build_tools/zipalign" -f 4 "$unsigned_apk" "$aligned_apk"

if [ ! -f "$keystore" ]; then
  keytool -genkeypair -v \
    -keystore "$keystore" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -dname "CN=Android Debug,O=Moxi,C=US" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 >/dev/null 2>&1
fi

"$build_tools/apksigner" sign \
  --ks "$keystore" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$apk" \
  "$aligned_apk"
"$build_tools/apksigner" verify --verbose "$apk" | sed -n '1,12p'
"$build_tools/aapt" dump badging "$apk" | sed -n '1,6p'
echo "Moxi Android APK built: $apk"
