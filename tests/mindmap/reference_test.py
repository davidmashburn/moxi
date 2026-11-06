"""Inventory completeness, provenance and reserved host-chord checks (not live parity)."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = (root / 'src/moxi_mindmap/commands.mojo').read_text()
inventory = json.loads((Path(__file__).with_name('freeplane-reference.json')).read_text())
commands = {name: int(value) for name, value in re.findall(r'comptime (\w+) = Self\((\d+)\)', source) if name != 'NONE'}
assert {row['command']: row['id'] for row in inventory['commands']} == commands
assert len(commands) == len(inventory['commands'])
assert inventory['reference']['version'] == '1.13.3'
assert len(inventory['reference']['dmg_sha256']) == 64
for row in inventory['commands']:
    assert row['target_definition'] and row['context'] and row['expected'] and row['status']
    assert row['evidence']
assert 'CanvasBinding(100, M.PRIMARY' not in source, 'Primary+D belongs to excluded clone'
assert 'if host != HostPlatform.MACOS:\n        b.append(CanvasBinding(KEY_SPACE, M.PRIMARY' in source
print(f'PASS {len(commands)} command inventory entries, pinned primary provenance, Cmd+D and Cmd+Space reservations; live reference parity NOT VERIFIED')
