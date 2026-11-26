import pytest

from moxi import PlotSpec, plot
from moxi.specialized import layout


def funnel(values, *, specialized=True):
    spec = PlotSpec()
    layer = spec.add_catalog_mark("funnel", "Pipeline", "stage", "value")
    if specialized:
        spec.specialize(layer)
    return plot({"stage": list(range(len(values))), "value": values}, spec)


def test_sorted_ties_and_zero_keep_source_identity():
    chart = funnel([2, 0, 3, 2])
    result = layout(chart.spec.layers[0], chart.data)
    assert [g.source_rows for g in result.glyphs] == [(2,), (0,), (3,), (1,)]
    assert [r["rank"] for r in chart.table()] == [2, 4, 1, 3]
    assert not result.glyphs[-1].interactive
    assert result.glyphs[-2].vertices[2:] == ((0, 1), (0, 1))
    assert chart.hit_test(54, 100, tolerance=0) is None


def test_single_stage_and_legacy_default():
    chart = funnel([7])
    assert layout(chart.spec.layers[0], chart.data).glyphs[0].vertices == (
        (-1, 1), (1, 1), (1, 0), (-1, 0))
    assert b"<polygon" not in funnel([3, 9, 6], specialized=False).to_svg()


@pytest.mark.parametrize("values", [[0, 0], [-1, 2], [1, float("nan")], [None, 3]])
def test_invalid_stage_values(values):
    with pytest.raises(ValueError):
        funnel(values).to_svg()
