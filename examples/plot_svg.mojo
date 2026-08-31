"""Web-compatible SVG output for the shared plot component."""

from moxi import Rect, SHOWCASE_PLOT_SVG, ShowcaseState, SvgSceneRenderer


def main() raises:
    var component = ShowcaseState(SHOWCASE_PLOT_SVG)
    var scene = component.scene(Rect(0.0, 0.0, 640.0, 420.0))
    var renderer = SvgSceneRenderer(640, 420)
    renderer.render_scene(scene)
    print(renderer.markup())
