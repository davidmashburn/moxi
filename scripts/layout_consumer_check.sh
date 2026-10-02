#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
consumer_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-layout-consumer.XXXXXX")"
trap 'rm -rf "$consumer_dir"' EXIT
mojo precompile src/moxi -o "$consumer_dir/moxi.mojoc"
cp tests/layout_consumer.mojo "$consumer_dir/main.mojo"
# No source-tree include path: optional modules must survive package compilation.
cd "$consumer_dir"
mojo build -I "$consumer_dir" \
  -Xlinker "$repo_dir/native/retained_layout/target/release/libmoxi_retained_layout.a" \
  -Xlinker "$repo_dir/native/macos_text.o" -Xlinker "$repo_dir/native/macos_window.o" \
  -Xlinker "$repo_dir/experiments/layout-kiwi/build/liblayout_kiwi.a" -Xlinker -lc++ \
  -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText \
  main.mojo -o consumer
./consumer
