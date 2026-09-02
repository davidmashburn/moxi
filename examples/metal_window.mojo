"""Visible Metal scene window demo with an explicit scene component."""

from moxi import (
    Color,
    ColumnView,
    Component,
    MacOSMetalRenderer,
    MacOSMetalWindow,
    Point,
    Rect,
    Scene,
    WindowConfig,
)


struct MetalWindowDemo(Component):
    """Keep the component scene independent from the Metal window host."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 20.0, 10.0)
        root.add_label(1, "Metal window component", 32.0)
        root.add_canvas(2, "Metal scene", bounds.height - 80.0)
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
            "Metal window",
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
    var component = MetalWindowDemo()
    var renderer = MacOSMetalRenderer(640, 420)
    var window = MacOSMetalWindow()
    window.open(WindowConfig("Moxi Metal scene", 640.0, 420.0))
    if not renderer.is_ready() or not window.is_open():
        print("Moxi Metal window unavailable")
        renderer.shutdown()
        return
    while window.is_open():
        var scene = component.scene(Rect(0.0, 0.0, 640.0, 420.0))
        renderer.render_scene(scene)
        window.pump()
    renderer.shutdown()
