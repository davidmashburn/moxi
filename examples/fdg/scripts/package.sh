#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Local binary wheel only; no editable installs or public publishing.
uv build --wheel --out-dir "$app_dir/dist/wheels" "$app_dir"
