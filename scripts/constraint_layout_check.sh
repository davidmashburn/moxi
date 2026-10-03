#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
system_name="$(uname -s)"
case "$system_name" in
  Darwin) cpp_stdlib=-lc++ ;;
  Linux) cpp_stdlib=-lstdc++ ;;
  *)
    echo "Moxi constraint layout check: unsupported system $system_name (expected Darwin or Linux)" >&2
    exit 1
    ;;
esac
# Bootstrap verifies the pinned Kiwi 1.5.0 commit before compiling the bridge.
bash experiments/layout-kiwi/scripts/build.sh
experiments/layout-kiwi/build/bridge_test
mkdir -p dist
mojo build -I src -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a \
  -Xlinker "$cpp_stdlib" tests/constraint_layout.mojo -o dist/moxi-constraint-layout-test
dist/moxi-constraint-layout-test
