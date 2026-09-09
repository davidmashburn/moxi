"""Portable Plot API smoke test.

This test deliberately imports the focused plotting lane rather than the
compatibility root.  It is the smallest executable proof that a headless
consumer can build a plot and render it without the native host modules.
"""

from moxi.geometry import Rect
from moxi_plot.plot_api import Plot, PlotDataTable, PlotSpec, plot_from_spec
from moxi.software import SoftwareSceneRenderer
from moxi.style import Color
from moxi.testing import test_check


def main() raises:
    var data = PlotDataTable()
    _ = data.append(0.0, 1.0)
    _ = data.append(1.0, 3.0)
    _ = data.append(2.0, 2.0)
    test_check(data.row_count() == 3)

    var spec = PlotSpec("portable")
    _ = spec.add_line("series")
    test_check(spec.validate())

    var plot = plot_from_spec(spec, data, Rect(0.0, 0.0, 160.0, 120.0))
    var scene = plot.build_scene()
    test_check(scene.count() > 0)

    var renderer = SoftwareSceneRenderer(160, 120)
    renderer.render_scene(scene)
    test_check(renderer.checksum() > 0)

    # Keep the direct Plot path in this lane too: portable consumers should
    # not need PlotSpec when they only need a small retained plot.
    var direct = Plot(Rect(0.0, 0.0, 80.0, 60.0))
    var series = direct.add_series("direct", Color(0.25, 0.75, 1.0, 1.0))
    _ = direct.add_point(series, 0.0, 0.0)
    _ = direct.add_point(series, 1.0, 1.0)
    direct.fit_to_data()
    test_check(direct.build_scene().count() > 0)
    print("Moxi portable plot lane passed")
