"""Fixture payloads for Wave C descriptors in the shared Mojo scenario registry."""
import csv
import json
import re
from pathlib import Path
from moxi import PlotSpec, plot

ROOT=Path(__file__).resolve().parents[2]
PAYLOADS=json.loads((ROOT/'tests/fixtures/wave_c/cases.json').read_text())
# The registry owns membership and order; JSON owns only the input payloads.
NAMES=re.findall(r'"Specialized [^"]+", "wave-c-([a-z_]+)"', (ROOT/'src/moxi/scenarios.mojo').read_text())
CASES=[dict(id=name,**PAYLOADS[name]) for name in NAMES]
assert set(NAMES)==set(PAYLOADS), 'registry and fixture payloads differ'
INVENTORY={row['upstream_mark']:row for row in csv.DictReader((ROOT/'docs/dataviz-capabilities.tsv').open(),delimiter='\t')}
for name in NAMES:
    row=INVENTORY[name]
    assert row['schema_status']=='compatible-layout-v1'
    assert row['parity_fixture']==('wave-c-reference-unavailable' if name=='tricontour' else 'wave-c-real-pinned')


def figure(case,columns=None):
    spec=PlotSpec('Wave C: '+case['id'])
    layer=spec.add_catalog_mark(case['id'],case['id'],case['x'],case['y'],**case.get('channels',{}))
    spec.specialize(layer,**case.get('layout',{}))
    spec.add_hover();spec.add_click_select();spec.add_keyboard()
    return plot(case['columns'] if columns is None else columns,spec,width=640,height=480)
