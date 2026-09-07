"""Emit one cross-language PlotSpec fixture for the Python contract gate."""

from moxi import PlotSpec


def main():
    var spec = PlotSpec("Core overlap")
    _ = spec.add_line("line")
    _ = spec.add_scatter("points")
    _ = spec.add_bar("bars")
    _ = spec.add_area("area")
    _ = spec.add_box("box", "y", "group")
    _ = spec.add_heatmap("heatmap", "x", "y", 4, 4)
    print(spec.to_json())
