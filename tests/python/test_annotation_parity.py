"""Regressions for real annotation ink, shared placement and retained sources."""
import copy
from io import BytesIO
from pathlib import Path
import runpy
import xml.etree.ElementTree as ET

import pytest

from moxi import PlotSpec, plot
from moxi.specialized import LayoutVersion, PALETTE

EXAMPLE = runpy.run_path(str(Path(__file__).parents[2] / "examples/python-annotations/render.py"))
EXPECTED = {
    "calendar_heatmap": "Sun Mon Tue Wed Thu Fri Sat Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(),
    "sankey": list("ABCD"),
    "parallel": list("ABC"),
    "bump": ["1", "2", "A", "B", "C"],
    "arc_diagram": list("ABC"),
    "pie": list("ABCD"),
    "donut": list("ABCD"),
    "polar_bar": list("ABCD"),
    "nightingale": list("ABCD"),
    "radialbar": list("ABCD"),
    "radar": ["Speed", "Range", "Weight", "Price", "Power", "value", "other"],
    "gauge": ["67.0"],
}


def figure(name, width=640, height=480):
    return next(EXAMPLE["figures"](width, height, (name,)))[1]


def svg_labels(chart):
    return ET.fromstring(chart.to_svg()).findall(".//{*}text[@font-family='monospace']")


def label_box(element):
    offset = {"start": 0, "middle": .5, "end": 1}[element.get("text-anchor")]
    x = round(float(element.get("x")) - len(element.text) * 7 * offset)
    y = round(float(element.get("y")) - 9)
    return x, y, x + len(element.text) * 7, y + 9


def without_labels(chart):
    plain = copy.copy(chart)
    plain._plot_labels = lambda: iter(())
    return plain


@pytest.mark.parametrize("name, expected", [
    ("calendar_heatmap",
     [(text, 39, y, "end") for text, y in zip(
         "Sun Mon Tue Wed Thu Fri Sat".split(), [75, 130, 185, 240, 295, 350, 405])]
     + [(text, x, 40, "start") for text, x in zip(
         "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(),
         [48, 90, 133, 185, 228, 270, 323, 365, 418, 460, 502, 555])]),
    ("sankey", [("A", 74, 232, "start"), ("B", 343, 132, "start"),
                ("C", 343, 292, "start"), ("D", 612, 232, "start")]),
])
def test_normal_svg_labels_preserve_pinned_anchors(name, expected):
    # Independent 640x480 SVG values from dataviz_mojo at
    # 3fd5a7e7c622d6130c99a290b88c4fee039deab2, checked by check_labels.
    labels = svg_labels(figure(name))
    assert len(labels) == len(expected)
    for label, (text, x, y, anchor) in zip(labels, expected):
        assert label.text == text
        assert label.get("text-anchor") == anchor
        assert abs(float(label.get("x")) - x) <= 1.1
        assert abs(float(label.get("y")) - y) <= 1.1


@pytest.mark.parametrize("name", EXPECTED)
@pytest.mark.parametrize("size", [(320, 240), (960, 480)])
def test_shared_labels_have_real_png_and_independently_rasterized_pdf_ink(name, size):
    Image = pytest.importorskip("PIL.Image")
    ImageChops = pytest.importorskip("PIL.ImageChops")
    pypdf = pytest.importorskip("pypdf")
    mupdf = pytest.importorskip("pymupdf")
    chart = figure(name, *size)
    original_spec = chart.spec.to_json()
    original_data = copy.deepcopy(chart.data.columns)
    geometries = [(layer.id, copy.deepcopy(vars(g))) for layer, g in chart._render_geometries()]
    labels = svg_labels(chart)
    texts = [label.text for label in labels]
    if name == "calendar_heatmap" and size[0] == 320:
        assert texts[:7] == EXPECTED[name][:7]
        assert 2 < len(texts[7:]) < 12
        assert all(text in EXPECTED[name][7:] for text in texts[7:])
    else:
        assert texts == EXPECTED[name]
    plain = without_labels(chart)
    png = Image.open(BytesIO(chart.to_png())).convert("RGB")
    png_difference = ImageChops.difference(png, Image.open(BytesIO(plain.to_png())).convert("RGB"))
    pdf_bytes = chart.to_pdf()
    page = pypdf.PdfReader(BytesIO(pdf_bytes)).pages[0]
    assert list(map(float, page.mediabox)) == [0, 0, *size]
    assert [str(args[0]) for args, op in page.get_contents().operations if op == b"Tj"] == texts
    assert page["/Resources"]["/Font"]["/F1"]["/BaseFont"] == "/Courier"

    def raster_pdf(content):
        with mupdf.open(stream=content, filetype="pdf") as document:
            pixmap = document[0].get_pixmap(alpha=False)
            return Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)

    pdf_raster = raster_pdf(pdf_bytes)
    pdf_difference = ImageChops.difference(pdf_raster, raster_pdf(plain.to_pdf()))
    occupied = []
    for element in labels:
        box = label_box(element)
        x, y, right, bottom = box
        assert 0 <= x < right <= chart.width and 0 <= y < bottom <= chart.height
        assert all(right + 2 <= a or x >= c + 2 or bottom + 2 <= b or y >= d + 2
                   for a, b, c, d in occupied)
        occupied.append(box)
        # Subtract unlabeled geometry so a nearby trace cannot pass as text ink.
        assert png_difference.crop(box).getbbox() is not None, (name, element.text, "PNG")
        assert pdf_difference.crop(box).getbbox() is not None, (name, element.text, "PDF raster")
        assert any(png.getpixel((col, row)) == (36, 50, 74)
                   for row in range(y, bottom) for col in range(x, right))
    swatches = ET.fromstring(chart.to_svg()).findall(".//{*}rect[@width='9'][@height='9']")
    for index, swatch in enumerate(swatches):
        point = int(swatch.get("x")) + 4, int(swatch.get("y")) + 4
        expected = tuple(round(channel * 255) for channel in PALETTE[index % len(PALETTE)][:3])
        assert png.getpixel(point) == expected
        assert all(abs(a - b) <= 1 for a, b in zip(pdf_raster.getpixel(point), expected))
    assert chart.spec.to_json() == original_spec and chart.data.columns == original_data
    assert [(layer.id, vars(g)) for layer, g in chart._render_geometries()] == geometries


@pytest.mark.parametrize("name", EXPECTED)
def test_annotations_do_not_add_targets_or_change_existing_source_selection(name):
    chart = figure(name, 320, 240)
    plain = without_labels(chart)
    for element in svg_labels(chart):
        x, y, right, bottom = label_box(element)
        assert chart.hit_test((x + right) / 2, (y + bottom) / 2, 1) == plain.hit_test((x + right) / 2, (y + bottom) / 2, 1)
    for layer, geometry in chart._render_geometries():
        if not geometry.interactive:
            continue
        point = (geometry.points[0] if geometry.points else
                 geometry.segments[0][:2] if geometry.segments else
                 geometry.polygons[0][0] if geometry.polygons else geometry.rects[0][:2])
        hit = chart.hit_test(*point, 1)
        assert hit == plain.hit_test(*point, 1)
        assert hit is not None and hit["layer"] == layer.id
        assert hit["row_index"] in hit["source_rows"]
    assert chart.table() == plain.table()


def test_radial_legend_keeps_zero_rows_and_palette_order():
    chart = figure("radialbar", 320, 240)
    data = {"category": ["North", "North", "South", "West"], "value": [4, 0, 3, 1]}
    chart = plot(data, chart.spec, width=320, height=240)
    labels = list(chart._plot_labels())
    assert [item.text for item in labels] == data["category"]
    assert [item.swatch for item in labels] == list(PALETTE)
    assert [row["value"] for row in chart.table()] == data["value"]
    assert not any(g.source_row == 1 and g.interactive for _, g in chart._render_geometries())


def test_gauge_displays_actual_measurement_when_needle_is_clamped():
    original = figure("gauge")
    data = {"category": ["Load"], "value": [125.25], "minimum": [0], "maximum": [100]}
    chart = plot(data, original.spec)
    assert [label.text for label in svg_labels(chart)] == ["125.3"]
    assert chart.table()[0]["value"] == 125.25
    data["value"] = [100]
    clamped = plot(data, original.spec)
    assert [(g.part, g.segments, g.points) for _, g in chart._render_geometries()] == [
        (g.part, g.segments, g.points) for _, g in clamped._render_geometries()]


@pytest.mark.parametrize("value, expected", [(-12.25, "-12.3"), (-.01, "0.0"), (.05, "0.1"),
                                             (1e15, "1000000000000000.0")])
def test_gauge_rounding_and_large_value_fallback(value, expected):
    chart = figure("gauge")
    data = dict(chart.data.columns, value=[value])
    assert [label.text for label in svg_labels(plot(data, chart.spec))] == [expected]


def test_fitting_and_xml_escaping_do_not_change_sankey_inputs():
    original = figure("sankey")
    data = {"source": ["North & East", "North & East"], "target": ['South "West"', "Far endpoint"], "value": [2, 3]}
    before = copy.deepcopy(data)
    chart = plot(data, original.spec, width=320, height=240)
    labels = svg_labels(chart)
    assert any(label.text.endswith("…") for label in labels)
    assert b"North &amp; East" in chart.to_svg()
    assert data == before
    assert [row["source"] for row in chart.table()] == before["source"]
    assert [row["target"] for row in chart.table()] == before["target"]


def test_existing_unicode_fallback_is_explicit_and_sources_are_retained():
    chart = figure("pie", 320, 240)
    data = {"category": ["Snow ☃", "B", "C", "D"], "value": [4, 2, 3, 1]}
    chart = plot(data, chart.spec, width=320, height=240)
    replacement = plot(dict(data, category=["Snow ?", "B", "C", "D"]), chart.spec, width=320, height=240)
    # Use wide slots so the unsupported character itself is rendered.
    chart.width = replacement.width = 960
    assert chart.to_png() == replacement.to_png()
    assert chart.to_pdf() == replacement.to_pdf()
    assert "Snow ☃" in chart.to_svg().decode()
    assert chart.table()[0]["category"] == "Snow ☃"


@pytest.mark.parametrize("size", [(1, 1), (80, 60)])
def test_tiny_exports_fit_or_omit_labels_without_crashing(size):
    for _, chart in EXAMPLE["figures"](*size):
        for label in svg_labels(chart):
            x, y, right, bottom = label_box(label)
            assert 0 <= x < right <= chart.width and 0 <= y < bottom <= chart.height
        assert len(chart.to_rgba()) == size[0] * size[1] * 4
        assert chart.to_pdf().startswith(b"%PDF")


def test_unsupported_labels_and_mixed_layer_contract_stay_unchanged():
    # At the pinned public API, single-series polar has no text requests.
    polar = figure("polar")
    assert not svg_labels(polar)
    spec = PlotSpec()
    spec.add_line(x_field="x", y_field="y")
    spec.add_catalog_mark("pie", x_field="x", y_field="y")
    mixed = plot({"x": [0, 1], "y": [2, 3]}, spec)
    original = mixed.spec.to_json()
    assert list(mixed._plot_labels()) == []
    assert len(ET.fromstring(mixed.to_svg()).findall(".//{*}line[@stroke='#667085']")) == 2
    assert mixed.to_png().startswith(b"\x89PNG") and mixed.to_pdf().startswith(b"%PDF")
    assert mixed.spec.to_json() == original
    spec.layers[1].layout_version = LayoutVersion.SPECIALIZED
    with pytest.raises(ValueError, match="invalid PlotSpec"):
        plot({"x": [0, 1], "y": [2, 3]}, spec)
