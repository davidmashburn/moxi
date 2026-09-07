"""Export the canonical Moxi plot scene through canvas_mojo."""

from moxi import CanvasSceneRenderer, Rect, make_plot_scenario


def main() raises:
    var bounds = Rect(0.0, 0.0, 640.0, 420.0)
    var plot = make_plot_scenario(bounds)
    plot.set_title("Canvas scene export")
    var scene = plot.build_scene()
    var renderer = CanvasSceneRenderer(640, 420)
    renderer.render_scene(scene)
    renderer.write_png("/tmp/moxi-canvas-scene.png")
    print("Moxi canvas scene commands: ", renderer.command_count)
    print("Moxi canvas scene fallbacks: ", renderer.fallback_count)
    print("Moxi canvas scene checksum: ", renderer.checksum())
    print("Moxi canvas scene output: /tmp/moxi-canvas-scene.png")
