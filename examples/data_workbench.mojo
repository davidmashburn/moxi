"""Native Moxi Data Workbench window."""

from moxi import App, NONE_KIND, Rect, WindowConfig
from moxi.macos import MacOSCanvasSceneRenderer, MacOSClipboard, MacOSRenderer, MacOSWindow
from moxi_demo.data_workbench import (
    DATA_WORKBENCH_HISTOGRAM_CANVAS_ID,
    DATA_WORKBENCH_SCATTER_CANVAS_ID,
    DataWorkbenchState,
)


def render_frame(
    mut app: App[DataWorkbenchState],
    mut renderer: MacOSRenderer,
    mut scene_renderer: MacOSCanvasSceneRenderer,
) raises:
    app.render(renderer)
    var scatter = app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID)
    var histogram = app.view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID)
    var left = scatter.x if scatter.x < histogram.x else histogram.x
    var top = scatter.y if scatter.y < histogram.y else histogram.y
    var right = scatter.x + scatter.width
    var histogram_right = histogram.x + histogram.width
    if histogram_right > right:
        right = histogram_right
    var bottom = scatter.y + scatter.height
    var histogram_bottom = histogram.y + histogram.height
    if histogram_bottom > bottom:
        bottom = histogram_bottom
    var plot_bounds = Rect(left, top, right - left, bottom - top)
    scene_renderer.set_clip(plot_bounds)
    scene_renderer.render_scene(app.component.combined_scene(scatter, histogram))


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    var config = WindowConfig("Moxi · Data Workbench", 1180.0, 820.0)
    config.set_min_size(980.0, 720.0)
    window.open(config)
    var size = window.size()
    var app = App[DataWorkbenchState](
        DataWorkbenchState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    var scene_renderer = MacOSCanvasSceneRenderer()
    render_frame(app, renderer, scene_renderer)
    while window.is_open():
        window.pump()
        var event = window.poll_event()
        var changed = app.tick(1.0 / 60.0)
        while event.kind != NONE_KIND:
            changed = app.dispatch_with_clipboard(event, clipboard) or changed
            event = window.poll_event()
        if changed:
            render_frame(app, renderer, scene_renderer)
