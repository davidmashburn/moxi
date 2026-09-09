#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-headless.XXXXXX")"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

# This lane is intentionally independent of the native object files and the
# host demos.  The focused import path and a source precompile are the package
# boundary that Linux and other future headless targets must carry.
mojo run -I src tests/portable_plot.mojo
mojo precompile src/moxi -o "$tmp_dir/moxi.mojoc"
mojo precompile -I src src/moxi_plot -o "$tmp_dir/moxi_plot.mojoc"

echo "Moxi portable headless lane passed"
