#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

git diff --check
git diff --cached --check
bash scripts/test.sh
clang -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c native/macos_window.m -o native/macos_window.o
clang -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c native/macos_metal.m -o native/macos_metal.o
clang -Wall -Wextra -Werror -fobjc-arc -fmodules \
  -c native/macos_text.m -o native/macos_text.o
mkdir -p dist
mojo precompile src/moxi -o dist/moxi.mojoc
mojo doc src/moxi -I src -o dist/moxi-api.json
xmllint --noout docs/wx-style-showcase.svg
xmllint --noout docs/wx-style-advanced.svg
xmllint --noout docs/plot-gallery.svg
xmllint --noout docs/plot-analytics.svg
bash scripts/host_check.sh
bash scripts/harfbuzz_check.sh

if rg -q "Use code with caution|I can provide further detail" \
  "Specification High-Performance Agent-Re.md"; then
  echo "agent capability design note contains editor artifacts" >&2
  exit 1
fi

echo "Moxi validation passed"
