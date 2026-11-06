"""Shared deterministic inputs; no screenshots or reference output are synthesized."""
import json
from pathlib import Path
from moxi import PlotSpec, plot

ROOT = Path(__file__).resolve().parents[2]
CASES = json.loads((ROOT / 'tests/fixtures/wave_a/cases.json').read_text())


def figure(case, *, columns=None, width=640, height=480):
    spec = PlotSpec('Wave A: ' + case['id'])
    identity = spec.add_catalog_mark(case['id'], case['id'], 'category', 'value', **case['channels'])
    spec.specialize(identity, **case['layout'])
    spec.add_hover()
    spec.add_click_select()
    spec.add_keyboard()
    return plot(columns or case['columns'], spec, width=width, height=height)
