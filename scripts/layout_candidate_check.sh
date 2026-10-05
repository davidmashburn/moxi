#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
bash scripts/retained_layout_check.sh
bash scripts/constraint_layout_check.sh
bash scripts/composed_layout_check.sh
bash scripts/native_window_run_check.sh
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  native/tests/macos_clipboard_test.m native/macos_window.o native/macos_text.o \
  -framework Cocoa -framework CoreText -o dist/moxi-macos-clipboard-test
./dist/moxi-macos-clipboard-test
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  native/tests/macos_frame_test.m -framework Cocoa -o dist/moxi-macos-frame-test
./dist/moxi-macos-frame-test
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  native/tests/macos_wait_test.m -framework Cocoa -o dist/moxi-macos-wait-test
./dist/moxi-macos-wait-test
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  tests/native_retained_presentation.m -framework Cocoa -o dist/moxi-native-retained-presentation
./dist/moxi-native-retained-presentation
mojo run -I src tests/collection_layout.mojo
mojo run -I src tests/overlay_layout.mojo

bash scripts/layout_consumer_check.sh
