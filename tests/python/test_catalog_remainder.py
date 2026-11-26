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
