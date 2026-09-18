#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input="${1:-$repo_dir/docs/capability-bus-design.md}"
if [[ ! -f "$input" || ! -r "$input" ]]; then
  echo "required capability design note is missing or unreadable: $input" >&2
  exit 1
fi
if rg -q "Use code with caution|I can provide further detail" "$input"; then
  echo "agent capability design note contains editor artifacts" >&2
  exit 1
else
  status=$?
  if (( status != 1 )); then exit "$status"; fi
fi
