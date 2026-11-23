"""Scientific meaning of contour colors, labels, and exported descriptions."""
from copy import deepcopy
import json
from pathlib import Path
from xml.etree import ElementTree as ET

import pytest

from moxi import PlotSpec, plot
from moxi.specialized import layout

ROOT = Path(__file__).resolve().parents[2]


def figure(family, payload=None):
    if payload is None:
        filename = ROOT/('tests/fixtures/wave_c/cases.json' if family == 'tricontour'
                         else 'tests/fixtures/wave_b/'+family+'.json')
        payload = json.loads(filename.read_text())
        if family == 'tricontour':
            payload = payload[family]
    spec = PlotSpec()
    identity = spec.add_catalog_mark(family, family, payload['x'], payload['y'],
                                     **payload.get('channels', {}))
    spec.specialize(identity, **payload.get('layout', {}))
    return plot(payload['columns'], spec), payload


@pytest.mark.parametrize('family', ['contour', 'contourf', 'tricontour'])
def test_scalar_values_have_consistent_distinct_colors_and_numeric_labels(family):
    f, _ = figure(family)
    glyphs = layout(f.spec.layers[0], f.data).glyphs
    groups = {}
    for glyph in glyphs:
        assert glyph.label.startswith('z ')
        groups.setdefault(glyph.label, set()).add(glyph.color)
    assert len(groups) == {'contour': 7, 'contourf': 8, 'tricontour': 3}[family]
    assert all(len(colors) == 1 for colors in groups.values())
    colors = [next(iter(colors)) for colors in groups.values()]
    assert len(set(colors)) == len(groups)
    # Higher scalar values must be distinguishable by brightness as well as hue.
    brightness = [.2126*r+.7152*g+.0722*b for r,g,b,_ in colors]
    assert brightness == sorted(brightness)
    exported = ET.fromstring(f.to_svg())
    titles = [e.text for e in exported.iter() if e.tag.endswith('}title')]
    assert titles == [g.label for g in glyphs]
    descriptions = [row for row in f.accessibility() if row['role'] == 'glyph']
    assert [row['label'] for row in descriptions] == [g.label for g in glyphs]
    assert all(row['source_rows'] for row in descriptions)


def test_tricontour_color_depends_on_level_not_triangle_vertex_order():
    f, original = figure('tricontour')
    changed = deepcopy(original)
    changed['layout']['triangles'] = [t[1:]+t[:1] for t in changed['layout']['triangles']]
    other, _ = figure('tricontour', changed)
    def colors(fig):
        return {g.label:g.color for g in layout(fig.spec.layers[0], fig.data).glyphs}
    assert colors(f) == colors(other)


def test_filled_band_labels_identify_half_open_ownership_and_final_maximum():
    f, payload = figure('contourf')
    labels = list(dict.fromkeys(g.label for g in layout(f.spec.layers[0], f.data).glyphs))
    assert labels[0].startswith(f'z in [{min(payload["columns"]["z"]):g}, ')
    assert all(label.endswith(')') for label in labels[:-1])
    assert labels[-1].endswith(f', {max(payload["columns"]["z"]):g}]')


def test_scalar_field_label_is_escaped_in_svg():
    _, payload = figure('contour')
    payload = deepcopy(payload)
    field = 'z<&"'
    payload['columns'][field] = payload['columns'].pop('z')
    payload['channels']['y2_field'] = field
    f, _ = figure('contour', payload)
    root = ET.fromstring(f.to_svg())
    assert all(e.text.startswith(field+' = ') for e in root.iter() if e.tag.endswith('}title'))
