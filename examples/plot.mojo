"""Headless plotting component using the portable Moxi scene contract."""

from moxi import (
    App,
    ColumnView,
    Component,
    Rect,
    Scene,
    SoftwareSceneRenderer,
    default_panel_style,
    default_surface_style,
    make_plot_scenario,
)


comptime PLOT_CANVAS_ID = 1


struct PlotDemo(Component):
    """Compose a Canvas node and provide its renderer-neutral scene."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 20.0, 10.0)
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(
                bounds.x + 16.0,
                bounds.y + 16.0,
                bounds.width - 32.0,
                bounds.height - 32.0,
            ),
            default_panel_style(),
        )
        root.add_label(10, "Plot component", 32.0)
        root.add_canvas(PLOT_CANVAS_ID, "Plot scene", bounds.height - 100.0)
        root.layout()
        return root^

    def scene(mut self, bounds: Rect) -> Scene:
        var plot = make_plot_scenario(bounds)
        return plot.build_scene()


def main() raises:
    var bounds = Rect(0.0, 0.0, 640.0, 420.0)
    var app = App[PlotDemo](PlotDemo(), bounds)
    var scene = app.component.scene(bounds)
    var renderer = SoftwareSceneRenderer(640, 420)
    renderer.render_scene(scene)
    print("Moxi plot scene commands: ", scene.count())
    print("Moxi plot scene checksum: ", renderer.checksum())
    print("Moxi plot component canvas: ", app.view.bounds_for(PLOT_CANVAS_ID).width > 0.0)
