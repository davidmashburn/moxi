from moxi import PlotSpec, plot
from moxi.specialized import layout

import math
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest


def test_parallel_normalizes_each_dimension_and_keeps_constant_in_middle():
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("parallel", "Teams", "team", "A"),
                    series_fields=["B"])
    chart = plot({"team": ["East", "West"], "A": [3, 8], "B": [4, 4]}, spec)
    result = layout(chart.spec.layers[0], chart.data)
    records = [g for g in result.glyphs if g.interactive]
    assert [g.bounds for g in records] == [(0, 0, 1, .5), (0, 1, 1, .5)]
    assert [g.source_rows for g in records] == [(0,), (1,)]
    assert chart.table()[1]["team"] == "West"


def test_bump_ties_keep_source_order_and_rank_one_is_at_top():
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("bump", "Teams", "team", "A"), series_fields=["B"])
    chart = plot({"team": ["East", "West"], "A": [2**53, 2**53+1], "B": [4,4]}, spec)
    records = [g for g in layout(chart.spec.layers[0], chart.data).glyphs if g.interactive]
    assert [g.bounds for g in records] == [(.25, 0, .75, 1), (.25, 1, .75, 0)]


def test_arc_self_loop_remains_a_source_row_and_zero_weights_are_visible():
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("arc_diagram", "Edges", "source","weight",x2_field="target"))
    chart = plot({"source":["A","B"],"target":["A","C"],"weight":[0,0],"note":["loop","edge"]},spec)
    result = layout(chart.spec.layers[0],chart.data)
    edges = [g for g in result.glyphs if g.interactive]
    assert len(edges) == 1 and edges[0].source_rows == (1,)
    assert edges[0].stroke_width == chart.spec.layers[0].line_width
    assert [(r["row_index"], r["target"], r["note"]) for r in chart.table()] == [(0,"A","loop"), (1,"C","edge")]
    assert [g.label for g in result.glyphs if not g.interactive] == ["A","B","C"]


def test_parallel_emits_one_trace_per_record_with_finite_extreme_axes():
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("parallel","Teams","team","A"),series_fields=["B","C"])
    chart = plot({"team":["East","West"],"A":[-1e308,1e308],"B":[2**53,2**53+1],
                  "C":[-5,-5],"description":["first","second"]},spec)
    result = layout(chart.spec.layers[0],chart.data)
    paths = [g.vertices for g in result.glyphs if g.interactive]
    assert paths == [((0,0),(.5,0),(1,.5)),((0,1),(.5,1),(1,.5))]
    assert chart.to_svg().count(b"<polyline") == 2
    assert chart.table()[1]["description"] == "second"


def test_numpy_parallel_normalization_preserves_signed_range_and_adjacent_integers():
    np = pytest.importorskip("numpy")
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("parallel", "Records", "name", "range"),
                    series_fields=["adjacent", "constant"])
    data = {"name": ["low", "middle", "high"],
            "range": np.array([-2**63, 0, 2**63-1], dtype=np.int64),
            "adjacent": np.array([2**53, 2**53+1, 2**53+2], dtype=np.int64),
            "constant": np.array([7, 7, 7], dtype=np.int64)}
    with np.errstate(over="raise"):
        chart = plot(data, spec)
        records = [g for g in layout(chart.spec.layers[0], chart.data).glyphs if g.interactive]
    assert [g.vertices for g in records] == [
        ((0, 0), (.5, 0), (1, .5)),
        ((0, .5), (.5, .5), (1, .5)),
        ((0, 1), (.5, 1), (1, .5)),
    ]
    assert chart.table()[1]["adjacent"] == 2**53+1
    svg = ET.fromstring(chart.to_svg())
    path = svg.findall(".//{*}polyline")[0].attrib["points"]
    x, y = map(float, path.split()[0].split(","))
    assert chart.hit_test(x, y)["row_index"] == 0


def test_numpy_parallel_png_export_is_bounded():
    pytest.importorskip("numpy")
    # A subprocess bounds the raster loop even if normalization regresses to a
    # finite but enormous out-of-viewport coordinate.
    subprocess.run([sys.executable, "-c", """
import numpy as np
from moxi import PlotSpec, plot
spec = PlotSpec()
spec.specialize(spec.add_catalog_mark('parallel', 'Records', 'name', 'a'), series_fields=['b'])
chart = plot({'name':['low','middle','high'], 'a':np.array([-2**63,0,2**63-1],dtype=np.int64),
              'b':[0,1,2]}, spec, width=160, height=120)
assert chart.to_png().startswith(b'\\x89PNG')
"""], check=True, timeout=5)


@pytest.mark.parametrize("size", [(640, 420), (960, 420), (420, 640), (1200, 240)])
def test_arc_export_fits_complete_circles_and_keeps_source_hits(size):
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("arc_diagram", "Edges", "source", "weight", x2_field="target"))
    chart = plot({"source": ["A", "B", "C"], "target": ["C", "A", "B"],
                  "weight": [3, 9, 6]}, spec, width=size[0], height=size[1])
    paths = ET.fromstring(chart.to_svg()).findall(".//{*}polyline")
    assert len(paths) == 3
    for row, path in enumerate(paths):
        points = [tuple(map(float, point.split(","))) for point in path.attrib["points"].split()]
        assert len(points) == 49
        left, baseline = points[0]
        right, end_baseline = points[-1]
        cx, radius = (left + right)/2, (right - left)/2
        assert baseline == pytest.approx(end_baseline, abs=.002)
        for x, y in points:
            assert 0 <= x <= size[0] and 0 <= y <= size[1]
            assert math.hypot(x-cx, y-baseline) == pytest.approx(radius, abs=.002)
        assert chart.hit_test(*points[24])["row_index"] == row
    assert [r["source"] for r in chart.table()] == ["A", "B", "C"]
    assert chart.to_png().startswith(b"\x89PNG")
    assert chart.to_pdf().startswith(b"%PDF")
