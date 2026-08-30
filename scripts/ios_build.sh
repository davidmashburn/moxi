#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

developer_dir="${DEVELOPER_DIR:-}"
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  developer_dir=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR="$developer_dir"

ios_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
clang_bin="$(xcrun --sdk iphonesimulator --find clang)"
build_dir="${MOXI_IOS_BUILD_DIR:-output/ios-host-sim}"
app_dir="$build_dir/MoxiHost.app"
object_dir="$build_dir/objects"
target="arm64-apple-ios15.0-simulator"

mkdir -p "$object_dir" "$app_dir"

common_flags=(
  -target "$target"
  -isysroot "$ios_sdk"
  -mios-simulator-version-min=15.0
  -fobjc-arc
  -fmodules
  -Wall
  -Wextra
  -Werror
)

"$clang_bin" "${common_flags[@]}" -I native/hosts \
  -c native/hosts/moxi_ios_host.m -o "$object_dir/moxi_ios_host.o"
"$clang_bin" "${common_flags[@]}" -I native/hosts \
  -c native/ios/MoxiDemoViewController.m -o "$object_dir/MoxiDemoViewController.o"
"$clang_bin" "${common_flags[@]}" -I native/hosts \
  -c native/ios/main.m -o "$object_dir/main.o"

"$clang_bin" "${common_flags[@]}" \
  "$object_dir/main.o" \
  "$object_dir/MoxiDemoViewController.o" \
  "$object_dir/moxi_ios_host.o" \
  -framework UIKit \
  -framework Metal \
  -framework MetalKit \
  -o "$app_dir/MoxiHost"

cp native/ios/Info.plist "$app_dir/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$app_dir" >/dev/null

echo "Moxi iOS simulator app built: $app_dir"
file "$app_dir/MoxiHost"
