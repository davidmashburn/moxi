"""Interactive line-fractal explorer, ported from Xilem's paint example."""

from moxi import (
    App,
    FRACTAL_CANVAS_ID,
    FRACTAL_SCROLL_ID,
    FractalState,
    NONE_KIND,
    Rect,
    WindowConfig,
)
from moxi.macos import MacOSCanvasPainter, MacOSRenderer, MacOSWindow


def repaint(
    mut app: App[FractalState],
    mut painter: MacOSCanvasPainter,
) raises:
    """Paint the component-owned canvas after the retained widget frame."""
    var canvas = app.view.bounds_for(FRACTAL_CANVAS_ID)
    var viewport = app.view.bounds_for(FRACTAL_SCROLL_ID)
    var clip = viewport.intersection(canvas)
    app.component.paint_canvas(painter, canvas, clip)


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var painter = MacOSCanvasPainter()
    window.open(WindowConfig("Moxi Interactive Line Fractal", 1180.0, 900.0))
    var size = window.size()
    var app = App[FractalState](
        FractalState(),
        Rect(0.0, 0.0, size.width, size.height),
    )

    # Show the first slice immediately, then let the frame clock complete the
    # expansion without freezing the window while a high-depth preset grows.
    _ = app.component.advance_render(1024)
    app.render(renderer)
    repaint(app, painter)

    while window.is_open():
        window.pump()
        var changed = app.tick(1.0 / 60.0)
        var event = window.poll_event()
        if event.kind != NONE_KIND:
            changed = app.dispatch(event) or changed
        if app.component.advance_render():
            changed = True
        if changed:
            app.render(renderer)
            repaint(app, painter)
