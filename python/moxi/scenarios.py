"""Canonical Python overlap scenarios used by parity and release checks."""

from .spec import CATALOG_MARKS, PlotSpec


def overlap_scenarios():
    data = {
        "x": [0.0, 1.0, 2.0, 3.0],
        "y": [1.0, 3.0, 2.0, 4.0],
        "group": ["a", "a", "b", "b"],
    }
    builders = {
        "point": lambda s: s.add_scatter("points"),
        "line": lambda s: s.add_line("line"),
        "bar": lambda s: s.add_bar("bars"),
        "area": lambda s: s.add_area("area"),
        "box": lambda s: s.add_box("box", "y", "group"),
        "heatmap": lambda s: s.add_heatmap("heatmap", "x", "y", 4, 4),
    }
    for name, builder in builders.items():
        spec = PlotSpec(name)
        builder(spec)
        yield name, data, spec


def recipe_scenarios():
    """Canonical recipe-wave cases shared by tests, benchmarks, and docs."""
    data = {
        "value": [-2.0, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0],
        "x": [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
        "y": [0.2, 1.1, 1.8, 2.9, 4.2, 4.8, 6.2, 6.9],
        "y2": [0.0, 0.8, 1.4, 2.4, 3.7, 4.3, 5.6, 6.3],
    }
    builders = {
        "histogram": lambda s: s.add_histogram("histogram", "value", 4),
        "density": lambda s: s.add_density("density", "value", 6),
        "ecdf": lambda s: s.add_ecdf("ecdf", "value"),
        "regression": lambda s: s.add_regression("regression", "x", "y", 8),
        "hexbin": lambda s: s.add_hexbin("hexbin", "x", "y", 4, 3),
        "error_bar": lambda s: s.add_error_bar("error bars", "x", "y", y2_field="y2"),
    }
    for name, builder in builders.items():
        spec = PlotSpec(name)
        builder(spec)
        yield name, data, spec


def catalog_scenarios():
    """One deterministic value-boundary fixture for every absorbed catalog mark."""
    data = {
        "x": [0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0],
        "y": [1.0, 3.0, 2.0, 5.0, 4.0, 6.0, 3.0, 2.0],
        "x2": [0.65, 1.65, 2.65, 3.65, 4.65, 5.65, 6.65, 7.65],
        "y2": [0.4, 1.2, 1.0, 2.2, 1.5, 3.0, 1.8, 1.1],
        "open": [0.8, 2.7, 2.3, 4.4, 4.5, 5.4, 3.4, 2.4],
        "low": [0.5, 2.2, 1.8, 4.0, 4.0, 5.0, 3.0, 1.7],
        "high": [1.5, 3.4, 2.8, 5.5, 5.1, 6.5, 4.0, 2.9],
        "size": [4.0, 8.0, 12.0, 6.0, 10.0, 14.0, 7.0, 11.0],
        "opacity": [0.45, 0.55, 0.65, 0.75, 0.85, 0.95, 0.70, 0.60],
        "group": ["a", "a", "b", "b", "a", "a", "b", "b"],
    }
    for mark in CATALOG_MARKS:
        spec = PlotSpec(mark)
        options = {
            "x2_field": "x2",
            "y2_field": "y2",
        }
        if mark in {"grouped_bar", "stacked_bar", "punchcard"}:
            options["color_field"] = "group"
        if mark == "candlestick":
            options.update({
                "y2_field": "open",
                "stat_low_field": "low",
                "stat_high_field": "high",
            })
        if mark == "punchcard":
            options.update({"size_field": "size", "opacity_field": "opacity"})
        spec.add_catalog_mark(
            mark,
            mark,
            "x",
            "y",
            **options,
        )
        yield mark, data, spec
