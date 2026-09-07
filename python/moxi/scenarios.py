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
