"""GPU scene component; links the offscreen Metal renderer."""

from moxi import (
    App,
    Color,
    ColumnView,
    Component,
    MacOSMetalRenderer,
    Point,
    Rect,
    Scene,
    default_panel_style,
    default_surface_style,
)


comptime METAL_CANVAS_ID = 1


struct MetalSceneDemo(Component):
    """A component owns the scene; the host chooses the Metal renderer."""

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
        root.add_label(10, "Metal scene component", 32.0)
        root.add_canvas(METAL_CANVAS_ID, "Metal scene", bounds.height - 100.0)
        root.layout()
        return root^

    def scene(self, bounds: Rect) -> Scene:
        var scene = Scene()
        scene.append_rounded_rect(
            1,
            bounds,
            Color(0.055, 0.085, 0.15, 1.0),
            16.0,
        )
        scene.append_text(
            2,
            "Metal scene",
            Rect(bounds.x + 22.0, bounds.y + 18.0, bounds.width - 44.0, 28.0),
            Color(0.82, 0.92, 1.0, 1.0),
        )
        for index in range(18):
            var x = bounds.x + 28.0 + Float32(index) * 14.0
            var top = bounds.y + 72.0
            var bottom = bounds.y + bounds.height - 24.0 - Float32(index % 5) * 18.0
            scene.append_line(
                100 + index,
                Point(x, top),
                Point(bounds.x + bounds.width - 28.0 - Float32(index) * 9.0, bottom),
                Color(0.25, 0.75, 1.0, 0.84),
                2.0,
            )
        return scene^


def main() raises:
    var bounds = Rect(0.0, 0.0, 320.0, 220.0)
    var app = App[MetalSceneDemo](MetalSceneDemo(), bounds)
    var scene = app.component.scene(bounds)
    var renderer = MacOSMetalRenderer(320, 220)
    if not renderer.is_ready():
        print("Moxi Metal unavailable")
        return
    renderer.render_scene(scene)
    print("Moxi Metal frames: ", renderer.frame_count())
    print("Moxi Metal vertices: ", renderer.vertex_count())
    print("Moxi Metal checksum: ", renderer.checksum())
    renderer.shutdown()
