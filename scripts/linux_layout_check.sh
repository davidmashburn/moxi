#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# Build first so dependency and platform failures are reported consistently.
bash scripts/linux_native_build.sh --objects

cc_tool="${CC:-cc}"
read -r -a gtk_cflags <<< "$(pkg-config --cflags gtk4)"
read -r -a gtk_libs <<< "$(pkg-config --libs gtk4)"
"$cc_tool" -std=c11 -O3 -Wall -Wextra -Werror "${gtk_cflags[@]}" \
  native/tests/linux_text_test.c dist/native/linux_text.o "${gtk_libs[@]}" -lm \
  -o dist/moxi-linux-text-test
dist/moxi-linux-text-test

# A host ABI test can run without opening a display; interactive release checks
# remain separate from this build and contract check.
"$cc_tool" -std=c11 -O3 -Wall -Wextra -Werror -DMOXI_LINUX_TEST=1 \
  "${gtk_cflags[@]}" -c native/linux_window.c \
  -o dist/native/linux_window_test.o
"$cc_tool" -std=c11 -O3 -Wall -Wextra -Werror "${gtk_cflags[@]}" \
  -DMOXI_LINUX_TEST=1 native/tests/linux_window_test.c \
  dist/native/linux_window_test.o \
  dist/native/linux_text.o "${gtk_libs[@]}" -lm \
  -o dist/moxi-linux-window-test
dist/moxi-linux-window-test

experiments/layout-kiwi/build/bridge_test
mojo run -I src tests/retained_engine.mojo
mojo run -I src tests/box_layout.mojo

links=(
  -Xlinker dist/native/linux_window.o -Xlinker dist/native/linux_text.o
  -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a -Xlinker -lstdc++
  -Xlinker -lm
)
for flag in "${gtk_libs[@]}"; do
  links+=(-Xlinker "$flag")
done
for test_name in retained_layout constraint_layout layout_workbench; do
  mojo build -I src "${links[@]}" "tests/$test_name.mojo" \
    -o "dist/moxi-linux-$test_name-test"
  "dist/moxi-linux-$test_name-test"
done

bash scripts/linux_native_build.sh --app-only
echo "Moxi Linux native layout contracts passed; UI checks require a desktop session."
