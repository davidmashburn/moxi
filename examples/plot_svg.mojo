"""Web-compatible SVG output for an explicit Moxi plot component."""

from moxi import (
    App,
    ColumnView,
    Component,
    Rect,
    Scene,
    SvgSceneRenderer,
    default_panel_style,
    default_surface_style,
    make_plot_scenario,
)


comptime SVG_CANVAS_ID = 1


struct PlotSvgDemo(Component):
    """Build the same scene once, then send it to the SVG backend."""

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
        root.add_label(10, "Plot SVG export", 32.0)
        root.add_canvas(SVG_CANVAS_ID, "SVG scene", bounds.height - 100.0)
        root.layout()
        return root^

    def scene(mut self, bounds: Rect) -> Scene:
        var plot = make_plot_scenario(bounds)
        plot.set_title("SVG export scene")
        return plot.build_scene()


def main() raises:
    var bounds = Rect(0.0, 0.0, 640.0, 420.0)
    var app = App[PlotSvgDemo](PlotSvgDemo(), bounds)
    var scene = app.component.scene(bounds)
    var renderer = SvgSceneRenderer(640, 420)
    renderer.render_scene(scene)
    print(renderer.markup())
