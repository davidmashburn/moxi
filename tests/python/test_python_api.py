import json

import pytest

import moxi
from moxi.scenarios import overlap_scenarios


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
