import json

import pytest

import moxi
from moxi.scenarios import overlap_scenarios, recipe_scenarios


DATA = {"x": [0.0, 1.0, 2.0, 3.0], "y": [1.0, 3.0, 2.0, 4.0], "group": ["a", "a", "b", "b"]}


def test_clean_value_boundary_round_trip_and_exports():
    spec = moxi.PlotSpec("Telemetry")
    layer = spec.add_line("CPU", "x", "y")
    assert spec.encode(layer, "color", "group", "nominal")
    spec.add_hover()
    spec.add_annotation("peak", 2.0, 4.0)
    assert spec.validate()

    payload = spec.to_json()
    assert json.loads(payload)["version"] == 1
    decoded = moxi.PlotSpec.from_json(payload)
    assert decoded.to_json() == payload

    figure = moxi.plot(DATA, decoded, width=96, height=64)
    assert figure.to_svg().startswith(b"<svg")
    assert figure.to_png().startswith(b"\x89PNG\r\n\x1a\n")
    assert figure.to_pdf().startswith(b"%PDF-1.4")
    assert len(figure.to_rgba()) == 96 * 64 * 4
    assert figure.to_numpy().shape == (64, 96, 4)
    assert figure.capabilities().as_dict()["compiler_runtime"] is False


@pytest.mark.parametrize("name,data,spec", list(overlap_scenarios()))
def test_dataviz_overlap_scenarios_are_renderable(name, data, spec):
    figure = moxi.plot(data, spec, width=80, height=60)
    assert spec.validate(), name
    assert len(figure.to_svg()) > 300, name
    assert len(figure.to_png()) > 70, name


def test_numpy_input_is_columnar_when_available():
    np = pytest.importorskip("numpy")
    figure = moxi.plot(np.array([[0.0, 1.0], [1.0, 2.0]]), moxi.PlotSpec.from_dict({
        "version": 1,
        "title": "array",
        "composition": "layer",
        "facet": {"row": "", "column": ""},
        "shared_scales": {"x": True, "y": True},
        "layers": [{
            "id": 1, "mark": "line", "label": "line", "x": "0", "y": "1",
            "x2": "", "y2": "", "color_field": "", "fill_field": "",
            "stroke_field": "", "size_field": "", "opacity_field": "", "text_field": "",
            "stat_low_field": "", "stat_high_field": "", "median_field": "",
            "line_width": 2.0, "size": 6.0, "opacity": 1.0, "tooltip": "",
            "color": [0.25, 0.75, 1.0, 1.0],
        }],
        "encodings": [
            {"layer": 1, "channel": "x", "field": "0", "type": "quantitative", "literal": "", "has_literal": False},
            {"layer": 1, "channel": "y", "field": "1", "type": "quantitative", "literal": "", "has_literal": False},
        ],
        "transforms": [], "scales": [], "interactions": [], "annotations": [],
    }), width=32, height=24)
    assert figure.to_numpy().shape == (24, 32, 4)


@pytest.mark.parametrize("name,data,spec", list(recipe_scenarios()))
def test_recipe_wave_has_real_geometry_and_all_exports(name, data, spec):
    assert spec.validate(), name
    figure = moxi.plot(data, spec, width=160, height=120)
    geometry = figure._raw_geometry(spec.layers[0])
    if name == "histogram":
        assert len(geometry.rects) == 4
        assert sum(rect[4] for rect in geometry.rects) == len(data["value"])
    elif name == "density":
        assert len(geometry.points) == 6
        assert max(point[1] for point in geometry.points) > 0.0
    elif name == "ecdf":
        assert [point[0] for point in geometry.points] == sorted(data["value"])
        assert geometry.points[-1][1] == 1.0
    elif name == "regression":
        assert len(geometry.points) == 8
        assert geometry.points[-1][1] > geometry.points[0][1]
    elif name == "hexbin":
        assert geometry.rects
        assert all(rect[4] > 0.0 for rect in geometry.rects)
    elif name == "error_bar":
        assert len(geometry.errors) == len(data["y"])
    svg = figure.to_svg().decode("utf-8")
    assert f'data-mark="{name}"' in svg, name
    if name == "line":
        assert geometry.kind == "line"
        assert "<polyline" in svg
    assert len(figure.to_png()) > 100, name
    assert len(figure.to_pdf()) > 300, name
    assert len(figure.to_rgba()) == 160 * 120 * 4, name


def test_recipe_builders_preserve_mojo_transform_shape():
    spec = moxi.PlotSpec("recipes")
    spec.add_histogram("hist", "value", 7)
    spec.add_density("density", "value", 9)
    spec.add_ecdf("ecdf", "value")
    spec.add_hexbin("hex", "x", "y", 5, 4)
    spec.add_regression("fit", "x", "y", 11)
    spec.add_error_bar("error", "x", "y", y2_field="y2")
    transforms = spec.as_dict()["transforms"]
    assert [(item["kind"], item["limit"], item["window"]) for item in transforms] == [
        ("histogram", 7, 1),
        ("density", 9, 1),
        ("ecdf", 0, 1),
        ("hexbin", 5, 4),
        ("regression", 11, 1),
    ]
    assert spec.as_dict()["layers"][-1]["y2"] == "y2"
