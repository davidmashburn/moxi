#!/usr/bin/env bash
# Local, relocatable source-free Mojo/native package; no registry writes.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="${MOXI_D02_BUILD_DIR:-/tmp/moxi-d02}"
hb="${MOXI_HARFBUZZ_PREFIX:-/opt/homebrew/opt/harfbuzz}"
prefix="$work/package"
mkdir -p "$prefix/lib/mojo" "$prefix/share/moxi_math" "$prefix/share/licenses/moxi_math"
cd "$repo"
pixi run --frozen mojo precompile -I src src/moxi -o "$prefix/lib/mojo/moxi.mojoc" > "$work/package-moxi.log" 2>&1
pixi run --frozen mojo precompile -I src src/moxi_math -o "$prefix/lib/mojo/moxi_math.mojoc" > "$work/package-math.log" 2>&1
# Native objects come from the same build, not a checked-in binary.
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_window.m -o "$work/package-window.o"
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -I "$hb/include/harfbuzz" -c native/math/font.m -o "$work/package-font.o"
xcrun libtool -static -o "$prefix/lib/libmoxi_math_native.a" "$work/package-window.o" "$work/package-font.o"
cp assets/math/STIXTwoMath-Regular.otf "$prefix/share/moxi_math/"
cp assets/math/OFL.txt "$prefix/share/licenses/moxi_math/STIX-OFL.txt"
cp LICENSE "$prefix/share/licenses/moxi_math/MOXI-LICENSE"
cat > "$prefix/DEPENDENCIES.txt" <<'TXT'
macOS arm64, Xcode command line tools and SDK; Mojo 1.1.0, canvas_mojo 0.42.0
HarfBuzz with OpenType MATH support (tested 14.5.0; separately installed)
Cocoa and CoreText frameworks supplied by macOS. Link libmoxi_math_native.a once.
Font: STIX Two Math 2.13b171, SIL OFL 1.1, included with license.
Optional computation is separate Python code, not required by this editor package.
This local archive is not a signed app, conda package, or multi-host distribution.
TXT
COPYFILE_DISABLE=1 tar -czf "$work/moxi-math-local.tar.gz" -C "$prefix" .
printf 'Created %s/moxi-math-local.tar.gz\n' "$work"
