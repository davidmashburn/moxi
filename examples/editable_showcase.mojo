"""Editable component used by the Moxi Playground hot-reload lesson.

Edit the component or its ``scene`` method, save the file, and the Playground
rebuilds this module and swaps its canvas scene without replacing the window.
The exported function is the intentionally small development ABI; ordinary
applications still compose ``EditableShowcase`` directly as a Component.
"""

from moxi import (
    Color,
    ColumnView,
    Component,
    Point,
    Rect,
    Scene,
)
from moxi.macos import MacOSCanvasSceneRenderer


comptime EDITABLE_TITLE_ID = 1
comptime EDITABLE_BODY_ID = 2
comptime EDITABLE_CANVAS_ID = 3


struct EditableShowcase(Component):
    """A normal Moxi component with an embeddable scene."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 22.0, 10.0)
        root.add_label(EDITABLE_TITLE_ID, "Editable component", 34.0)
        root.add_label(
            EDITABLE_BODY_ID,
            "This view and its scene come from the same Mojo source file.",
            28.0,
        )
        root.add_canvas(
            EDITABLE_CANVAS_ID,
            "Editable scene canvas",
            bounds.height - 120.0,
        )
        root.layout()
        return root^

    def scene(self, bounds: Rect) -> Scene:
        var scene = Scene()
        scene.append_rounded_rect(
            1,
            bounds,
            Color(0.055, 0.09, 0.17, 1.0),
            18.0,
        )
        scene.append_text(
            2,
            "Edit me · save to reload",
            Rect(bounds.x + 24.0, bounds.y + 22.0, bounds.width - 48.0, 28.0),
            Color(0.80, 0.94, 1.0, 1.0),
        )
        for index in range(22):
            var x = bounds.x + 28.0 + Float32(index) * 12.0
            var y = bounds.y + bounds.height - 34.0 - Float32(index % 6) * 24.0
            scene.append_line(
                100 + index,
                Point(x, bounds.y + 74.0),
                Point(bounds.x + bounds.width - 30.0, y),
                Color(0.25, 0.78, 1.0, 0.78),
                2.0,
            )
        return scene^


@export
def moxi_live_frame(
    x: Float32,
    y: Float32,
    width: Float32,
    height: Float32,
) abi("C") -> Int32:
    """Render one edited component scene into the host-owned canvas."""
    var bounds = Rect(x, y, width, height)
    var component = EditableShowcase()
    var scene = component.scene(bounds)
    var renderer = MacOSCanvasSceneRenderer()
    renderer.set_clip(bounds)
    try:
        renderer.render_scene(scene)
    except:
        return -1
    return Int32(scene.count())
