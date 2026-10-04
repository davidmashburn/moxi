#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

mode=all
case "${1:-}" in
  "") ;;
  --objects) mode=objects ;;
  --app-only) mode=app ;;
  *)
    echo "Usage: bash scripts/linux_native_build.sh [--objects|--app-only]" >&2
    exit 2
    ;;
esac
if [[ $# -gt 1 ]]; then
  echo "Usage: bash scripts/linux_native_build.sh [--objects|--app-only]" >&2
  exit 2
fi

if [[ "$(uname -s)" != Linux ]]; then
  echo "Moxi Linux native build requires Linux; use layout-workbench on macOS." >&2
  exit 1
fi

cc_tool="${CC:-cc}"
cxx_tool="${CXX:-g++}"
ar_tool="${AR:-ar}"
for tool in "$cc_tool" "$cxx_tool" "$ar_tool" pkg-config mojo; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Moxi Linux native build requires $tool." >&2
    echo "Ubuntu system dependencies: build-essential pkg-config libgtk-4-dev fonts-dejavu-core; run this script in the locked Pixi environment." >&2
    exit 1
  fi
done
if ! pkg-config --exists 'gtk4 >= 4.14'; then
  echo "Moxi Linux native build requires GTK 4.14 or newer, including its Pango/Cairo development libraries." >&2
  echo "Ubuntu system dependencies: build-essential pkg-config libgtk-4-dev fonts-dejavu-core." >&2
  exit 1
fi

read -r -a gtk_cflags <<< "$(pkg-config --cflags gtk4)"
read -r -a gtk_libs <<< "$(pkg-config --libs gtk4)"
mkdir -p dist/native

if [[ "$mode" != app ]]; then
  "$cc_tool" -std=c11 -O3 -Wall -Wextra -Werror "${gtk_cflags[@]}" \
    -c native/linux_text.c -o dist/native/linux_text.o
  "$cc_tool" -std=c11 -O3 -Wall -Wextra -Werror "${gtk_cflags[@]}" \
    -c native/linux_window.c -o dist/native/linux_window.o
  # The existing bootstrap verifies the pinned Kiwi revision before compiling.
  CXX="$cxx_tool" AR="$ar_tool" bash experiments/layout-kiwi/scripts/build.sh
fi

if [[ "$mode" != objects ]]; then
  links=(
    -Xlinker dist/native/linux_window.o -Xlinker dist/native/linux_text.o
    -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a -Xlinker -lstdc++
    -Xlinker -lm
  )
  for flag in "${gtk_libs[@]}"; do
    links+=(-Xlinker "$flag")
  done
  mojo build -I src -I examples "${links[@]}" \
    examples/layout_workbench_linux.mojo -o dist/layout-workbench-linux
  echo "Moxi Linux native workbench built: dist/layout-workbench-linux"
fi
