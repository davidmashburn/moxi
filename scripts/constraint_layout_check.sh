#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
# Bootstrap verifies the pinned Kiwi 1.5.0 commit before compiling the bridge.
bash experiments/layout-kiwi/scripts/build.sh
experiments/layout-kiwi/build/bridge_test
mkdir -p dist
mojo build -I src -Xlinker experiments/layout-kiwi/build/liblayout_kiwi.a \
  -Xlinker -lc++ tests/constraint_layout.mojo -o dist/moxi-constraint-layout-test
dist/moxi-constraint-layout-test
