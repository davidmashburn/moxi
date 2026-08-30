#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if ! pkg-config --exists harfbuzz freetype2 fontconfig; then
  echo "Moxi HarfBuzz check skipped: pkg-config dependencies unavailable"
  exit 0
fi

read -r -a cflags <<< "$(pkg-config --cflags harfbuzz freetype2 fontconfig)"
read -r -a libs <<< "$(pkg-config --libs harfbuzz freetype2 fontconfig)"
mkdir -p output
clang++ -std=c++17 -Wall -Wextra -Werror "${cflags[@]}" \
  -c native/harfbuzz_text.cpp -o output/harfbuzz_text.o

link_flags=(-Xlinker output/harfbuzz_text.o)
for flag in "${libs[@]}"; do
  link_flags+=(-Xlinker "$flag")
done

mkdir -p dist
if command -v mojo >/dev/null 2>&1; then
  mojo_bin=(mojo)
elif command -v pixi >/dev/null 2>&1; then
  mojo_bin=(pixi run mojo)
else
  echo "Moxi HarfBuzz check skipped: Mojo compiler unavailable"
  exit 0
fi
"${mojo_bin[@]}" build -I src "${link_flags[@]}" examples/harfbuzz.mojo -o dist/moxi-harfbuzz-demo
./dist/moxi-harfbuzz-demo
