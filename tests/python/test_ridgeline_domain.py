"""A density's sampled peak must survive every export viewport."""
import pytest

from moxi import PlotSpec, plot
from moxi.specialized import layout
from moxi.wave_b import WaveBMark, _density


@pytest.mark.parametrize('group_count', [1, 2, 3, 6])
@pytest.mark.parametrize('constant', [False, True])
@pytest.mark.parametrize('size', [(640, 480), (320, 240)])
def test_ridgeline_domain_encloses_every_density_sample(group_count, constant, size):
    values = [2., 2., 2.] if constant else [-1., 0., 1.]
    columns = dict(group=[str(i) for i in range(group_count) for _ in values],
                   value=values*group_count)
    spec = PlotSpec('Complete ridgeline profiles')
    layer = spec.add_catalog_mark(WaveBMark.RIDGELINE.value, 'density', 'group', 'value')
    spec.specialize(layer)
    figure = plot(columns, spec, width=size[0], height=size[1])
    geometry = layout(figure.spec.layers[0], figure.data)
    for glyph in geometry.glyphs:
        assert all(geometry.y_domain[0] <= y <= geometry.y_domain[1]
                   for x, y in glyph.vertices)
    left, top, width, height, *_ = figure._layout()
    for _, rendered in figure._render_geometries():
        assert all(top-1e-9 <= y <= top+height+1e-9
                   for polygon in rendered.polygons for x, y in polygon)


def test_ridgeline_reframing_preserves_category_order_and_density_shapes():
    columns = dict(group=['A']*4+['B']*4, value=[-2., -1., 1., 2.]*2)
    spec = PlotSpec('Density shapes')
    layer = spec.add_catalog_mark(WaveBMark.RIDGELINE.value, 'density', 'group', 'value')
    spec.specialize(layer)
    figure = plot(columns, spec)
    geometry = layout(figure.spec.layers[0], figure.data)
    first, second = geometry.glyphs
    assert first.source_rows == (0, 1, 2, 3)
    assert second.source_rows == (4, 5, 6, 7)
    assert [x for x, y in first.vertices] == [x for x, y in second.vertices]
    assert [y-1 for x, y in first.vertices] == pytest.approx([y for x, y in second.vertices])
    _, density = _density(columns['value'][:4])
    rise = [y for x, y in second.vertices[1:-1]]
    assert [y/max(rise) for y in rise] == pytest.approx(density)
