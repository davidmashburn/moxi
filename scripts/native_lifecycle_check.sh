#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
clang -O2 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_text.m -o dist/native-lifecycle-text.o
clang -O1 -Wall -Wextra -Werror -fobjc-arc -fmodules tests/native_window_ownership.m -framework Cocoa -o dist/moxi-native-ownership
./dist/moxi-native-ownership
clang -O1 -Wall -Wextra -Werror -fobjc-arc -fmodules -c tests/native_lifecycle_probe.m -o dist/native-lifecycle-probe.o
mojo build -I src -Xlinker dist/native-lifecycle-probe.o -Xlinker dist/native-lifecycle-text.o -Xlinker -framework -Xlinker CoreText -Xlinker -framework -Xlinker Cocoa tests/native_lifecycle.mojo -o dist/moxi-native-lifecycle-test
./dist/moxi-native-lifecycle-test
