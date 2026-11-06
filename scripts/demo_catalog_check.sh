#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# Inspect the actual registry, including nested/shared model source paths.
python3 - <<'PY'
from pathlib import Path
import re

catalog = Path("src/moxi_demo/demo_entry.mojo").read_text()
entries = re.findall(r'^\s*"([^"\n]+\.mojo)",\n\s*"([^"\n]+)",', catalog, re.MULTILINE)
assert len(entries) == catalog.count("self.entries.append(DemoEntry("), "unrecognized catalog entry"
manifest = Path("pixi.toml").read_text()
for source, task in entries:
    assert Path(source).is_file(), f"demo catalog references missing source: {source}"
    assert re.search(rf"^{re.escape(task)}\s*=", manifest, re.MULTILINE), f"missing catalog task: {task}"
print(f"Moxi demo catalog check passed ({len(entries)} sources and tasks)")
PY
