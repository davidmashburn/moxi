"""Web-compatible SVG output for the shared plot scenario."""

from moxi import Rect, SvgSceneRenderer, make_plot_scenario


def main() raises:
    var plot = make_plot_scenario(Rect(0.0, 0.0, 640.0, 420.0))
    var scene = plot.build_scene()
    var renderer = SvgSceneRenderer(640, 420)
    renderer.render_scene(scene)
    print(renderer.markup())
