#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

echo "Moxi retained layout/paint/scene benchmark (local comparison harness)"
/usr/bin/time -p mojo run -I src benchmarks/layout.mojo
