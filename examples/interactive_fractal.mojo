"""Interactive line-fractal explorer, ported from Xilem's paint example."""

from moxi import (
    App,
    FRACTAL_CANVAS_ID,
    FRACTAL_SCROLL_ID,
    FractalCanvasPainter,
    FractalState,
    MacOSMetalCanvasPainter,
    NONE_KIND,
    Rect,
    WindowConfig,
)
from moxi.macos import MacOSCanvasPainter, MacOSRenderer, MacOSWindow


def repaint[Painter: FractalCanvasPainter](
    mut app: App[FractalState],
    mut painter: Painter,
) raises:
    """Paint the component-owned canvas after the retained widget frame."""
    var canvas = app.view.bounds_for(FRACTAL_CANVAS_ID)
    var viewport = app.view.bounds_for(FRACTAL_SCROLL_ID)
    var clip = viewport.intersection(canvas)
    app.component.paint_canvas(painter, canvas, clip)


def run_loop[Painter: FractalCanvasPainter](
    mut app: App[FractalState],
    mut window: MacOSWindow,
    mut renderer: MacOSRenderer,
    mut painter: Painter,
) raises:
    """Run the shared interactive scenario with either canvas backend."""
    _ = app.component.advance_render(1024)
    app.render(renderer)
    repaint(app, painter)

    while window.is_open():
        window.pump()
        var changed = app.tick(1.0 / 60.0)
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            changed = app.dispatch(event) or changed
            event = window.poll_event()
        if app.component.advance_render():
            changed = True
        if changed:
            app.render(renderer)
            repaint(app, painter)


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Interactive Line Fractal", 1180.0, 900.0))
    var size = window.size()
    var app = App[FractalState](
        FractalState(),
        Rect(0.0, 0.0, size.width, size.height),
    )

    # Prefer Metal for the dense canvas while leaving controls, accessibility,
    # and the no-GPU fallback on the established AppKit host.
    var metal_painter = MacOSMetalCanvasPainter()
    var initial_canvas = app.view.bounds_for(FRACTAL_CANVAS_ID)
    if metal_painter.is_ready() and metal_painter.attach_to_window(initial_canvas):
        run_loop(app, window, renderer, metal_painter)
        metal_painter.shutdown()
        return

    metal_painter.shutdown()
    var fallback_painter = MacOSCanvasPainter()
    run_loop(app, window, renderer, fallback_painter)
