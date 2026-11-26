from array import array
import copy
from io import BytesIO
import xml.etree.ElementTree as ET

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


def test_adjacent_large_integers_keep_exact_ranks_and_table_values():
    values = [2**53, 2**53 + 1, 2**53]
    chart = funnel(values)
    result = layout(chart.spec.layers[0], chart.data)
    assert [g.row for g in result.glyphs] == [1, 0, 2]
    assert [r["rank"] for r in chart.table()] == [2, 1, 3]
    assert [r["value"] for r in chart.table()] == values


def test_single_stage_and_legacy_default():
    chart = funnel([7])
    assert layout(chart.spec.layers[0], chart.data).glyphs[0].vertices == (
        (-1, 1), (1, 1), (1, 0), (-1, 0))
    assert b"<polygon" not in funnel([3, 9, 6], specialized=False).to_svg()
    assert not list(funnel([3, 9, 6], specialized=False)._plot_labels())


@pytest.mark.parametrize("values", [[0, 0], [-1, 2], [1, float("nan")], [None, 3]])
def test_invalid_stage_values(values):
    with pytest.raises(ValueError):
        funnel(values).to_svg()


def labeled_funnel(stages, values, size):
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("funnel", "Pipeline", "stage", "value"))
    return plot({"stage": stages, "value": values}, spec, width=size[0], height=size[1])


@pytest.mark.parametrize("size", [(640, 420), (240, 180)])
def test_sorted_stage_legends_have_actual_export_ink_without_changing_geometry(size):
    Image = pytest.importorskip("PIL.Image")
    ImageChops = pytest.importorskip("PIL.ImageChops")
    pypdf = pytest.importorskip("pypdf")
    mupdf = pytest.importorskip("pymupdf")
    chart = labeled_funnel(list("ABC"), [3, 9, 6], size)
    original_spec = chart.spec.to_json()
    original_rows = copy.deepcopy(chart.table())
    original_geometry = [(layer.id, copy.deepcopy(vars(g))) for layer, g in chart._render_geometries()]
    labels = list(chart._plot_labels())
    assert [label.text for label in labels] == list("BCA")
    svg = ET.fromstring(chart.to_svg())
    assert [e.text for e in svg.findall(".//{*}text")] == list("BCA")
    assert [e.get("fill") for e in svg.findall(".//{*}rect[@width='9']")] == [
        e.get("fill") for e in svg.findall(".//{*}polygon")]
    plain = copy.copy(chart)
    plain._plot_labels = lambda: iter(())
    assert [e.attrib for e in ET.fromstring(plain.to_svg()).findall(".//{*}polygon")] == [
        e.attrib for e in svg.findall(".//{*}polygon")]
    png = Image.open(BytesIO(chart.to_png())).convert("RGB")
    png_difference = ImageChops.difference(png, Image.open(BytesIO(plain.to_png())).convert("RGB"))
    pdf_bytes = chart.to_pdf()
    page = pypdf.PdfReader(BytesIO(pdf_bytes)).pages[0]
    assert [str(args[0]) for args, op in page.get_contents().operations if op == b"Tj"] == list("BCA")

    def raster_pdf(content):
        with mupdf.open(stream=content, filetype="pdf") as document:
            pixmap = document[0].get_pixmap(alpha=False)
            return Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)

    pdf_raster = raster_pdf(pdf_bytes)
    pdf_difference = ImageChops.difference(pdf_raster, raster_pdf(plain.to_pdf()))
    previous_right = 0
    left, top, width, height, *_ = chart._layout()
    for label in labels:
        text, x, y, swatch = label.cell
        right, bottom = x + len(text) * 7, y + 9
        assert previous_right + 2 <= x - 13 < right <= chart.width
        assert top + height + 4 <= y < bottom <= chart.height
        previous_right = right
        box = x, y, right, bottom
        assert png_difference.crop(box).getbbox() is not None
        assert pdf_difference.crop(box).getbbox() is not None
        expected = tuple(round(channel * 255) for channel in swatch[:3])
        assert png.getpixel((x - 9, y + 4)) == expected
        assert all(abs(a - b) <= 1 for a, b in zip(pdf_raster.getpixel((x - 9, y + 4)), expected))
        assert chart.hit_test(x, y, tolerance=0) is None
    assert chart.spec.to_json() == original_spec and chart.table() == original_rows
    assert [(layer.id, vars(g)) for layer, g in chart._render_geometries()] == original_geometry


def test_legend_keeps_exact_signed_int64_order_ties_and_zero_source_rows():
    values = array("q", [2**53, 0, 2**53 + 1, 2**53])
    assert values.itemsize == 8
    chart = labeled_funnel(list("ABCD"), values, (640, 420))
    assert [label.text for label in chart._plot_labels()] == list("CADB")
    assert [g.source_rows for g in layout(chart.spec.layers[0], chart.data).glyphs] == [(2,), (0,), (3,), (1,)]
    assert [r["rank"] for r in chart.table()] == [2, 4, 1, 3]
    assert [r["value"] for r in chart.table()] == list(values)
    assert all(type(r["value"]) is int for r in chart.table())


def test_numpy_int64_stage_legends_follow_exact_ranks_near_signed_limit():
    np = pytest.importorskip("numpy")
    values = np.array([2**63 - 2, 2**63 - 1, 2**63 - 2], dtype=np.int64)
    chart = labeled_funnel(list("ABC"), values, (640, 420))
    assert [label.text for label in chart._plot_labels()] == list("BAC")
    assert [r["rank"] for r in chart.table()] == [2, 1, 3]
    assert [r["value"] for r in chart.table()] == list(values)
    assert all(isinstance(r["value"], np.int64) for r in chart.table())
    for _, geometry in chart._render_geometries():
        vertices = geometry.polygons[0]
        x = sum(point[0] for point in vertices) / len(vertices)
        y = sum(point[1] for point in vertices) / len(vertices)
        hit = chart.hit_test(x, y, tolerance=0)
        assert hit["row_index"] == geometry.source_row
        assert hit["source_rows"] == list(geometry.source_rows)


@pytest.mark.parametrize("size", [(1, 1), (64, 48)])
def test_omit_legend_when_the_existing_margin_cannot_fit_text(size):
    chart = labeled_funnel(list("ABC"), [3, 9, 6], size)
    assert list(chart._plot_labels()) == []
    assert len(ET.fromstring(chart.to_svg()).findall(".//{*}polygon")) == 3


@pytest.mark.parametrize("count", [1, 3, 26])
def test_narrow_long_stage_labels_fit_and_sample_without_losing_source_rows(count):
    stages = [f"Original stage {i}" for i in range(count)]
    chart = labeled_funnel(stages, list(range(count, 0, -1)), (240, 180))
    labels = list(chart._plot_labels())
    assert 1 <= len(labels) <= count
    if count > 3:
        assert len(labels) < count
    assert any(label.text.endswith("…") for label in labels) == (count > 1)
    previous_right = 0
    for label in labels:
        text, x, y, _ = label.cell
        assert previous_right + 2 <= x - 13 < x + len(text) * 7 <= chart.width
        assert 0 <= y < y + 9 <= chart.height
        previous_right = x + len(text) * 7
    assert [r["category"] for r in chart.table()] == stages
