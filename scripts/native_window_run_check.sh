#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-native-run.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
"${CC:-cc}" -std=c11 -O2 -Wall -Wextra -Werror \
  -c tests/native_window_run_stub.c -o "$tmp_dir/native_window_run_stub.o"
mojo build -I src -Xlinker "$tmp_dir/native_window_run_stub.o" \
  tests/native_window_run.mojo -o "$tmp_dir/native_window_run"
"$tmp_dir/native_window_run"
