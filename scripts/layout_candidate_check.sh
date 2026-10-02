#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
bash scripts/retained_layout_check.sh
bash scripts/constraint_layout_check.sh
bash scripts/composed_layout_check.sh
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules \
  tests/native_retained_presentation.m -framework Cocoa -o dist/moxi-native-retained-presentation
./dist/moxi-native-retained-presentation
mojo run -I src tests/collection_layout.mojo
mojo run -I src tests/overlay_layout.mojo
