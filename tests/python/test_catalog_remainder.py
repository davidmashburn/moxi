from moxi import PlotSpec, plot
from moxi.specialized import layout


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
