"""Canonical Python overlap scenarios used by parity and release checks."""

from .spec import PlotSpec


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
