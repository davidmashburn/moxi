"""Native Moxi Data Workbench window."""

from std.ffi import external_call

from moxi import App, NONE_KIND, Rect, WindowConfig
from moxi.macos import MacOSCanvasSceneRenderer, MacOSClipboard, MacOSRenderer, MacOSWindow
from moxi_demo.data_workbench import (
    DATA_WORKBENCH_HISTOGRAM_CANVAS_ID,
    DATA_WORKBENCH_SCATTER_CANVAS_ID,
    DataWorkbenchState,
)


def same_bounds(a: Rect, b: Rect) -> Bool:
    return a.x == b.x and a.y == b.y and a.width == b.width and a.height == b.height


struct PlotOutputCache:
    var valid: Bool
    var scatter: Rect
    var histogram: Rect

    def __init__(out self):
        self.valid = False
        self.scatter = Rect(0.0, 0.0, 0.0, 0.0)
        self.histogram = Rect(0.0, 0.0, 0.0, 0.0)


def render_frame(
    mut app: App[DataWorkbenchState],
    mut renderer: MacOSRenderer,
    mut scene_renderer: MacOSCanvasSceneRenderer,
    mut plot_output: PlotOutputCache,
    reuse_plot_output: Bool,
    timing_enabled: Bool,
) raises:
    app.render(renderer)
    var scatter = app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID)
    var histogram = app.view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID)
    var reuse = (
        reuse_plot_output and plot_output.valid
        and same_bounds(scatter, plot_output.scatter)
        and same_bounds(histogram, plot_output.histogram)
    )
    if reuse:
        # begin_frame retains the native commands and raster output in this host.
        if timing_enabled:
            external_call["moxi_window_timing_begin_scene", NoneType]()
            external_call["moxi_window_timing_end_scene", NoneType]()
            external_call["moxi_window_timing_frame_ready", NoneType]()
        return
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
    if timing_enabled:
        external_call["moxi_window_timing_begin_scene", NoneType]()
        var scene = app.component.combined_scene(scatter, histogram)
        external_call["moxi_window_timing_end_scene", NoneType]()
        scene_renderer.render_scene(scene)
        external_call["moxi_window_timing_frame_ready", NoneType]()
    else:
        scene_renderer.render_scene(app.component.combined_scene(scatter, histogram))
    plot_output.valid = True
    plot_output.scatter = scatter
    plot_output.histogram = histogram


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    var config = WindowConfig("Moxi · Data Workbench", 1180.0, 820.0)
    config.set_min_size(980.0, 720.0)
    window.open(config)
    external_call["moxi_window_set_custom_paint_cache_enabled", NoneType](Int32(1))
    var native_timing_enabled = external_call[
        "moxi_window_timing_enabled", Int32
    ]() != 0
    var size = window.size()
    var app = App[DataWorkbenchState](
        DataWorkbenchState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    var scene_renderer = MacOSCanvasSceneRenderer()
    var plot_output = PlotOutputCache()
    render_frame(app, renderer, scene_renderer, plot_output, False, False)
    while window.is_open():
        window.pump()
        var event = window.poll_event()
        var changed = app.tick(1.0 / 60.0)
        var reuse_plot_output = not changed
        var event_changed = False
        while event.kind != NONE_KIND:
            # Any other event (including an unchanged one) invalidates this batch.
            reuse_plot_output = (
                app.component.can_reuse_plot_output(event, app.view)
                and reuse_plot_output
            )
            if native_timing_enabled:
                external_call["moxi_window_timing_begin_dispatch", NoneType](
                    Int32(event.kind)
                )
            var dispatched = app.dispatch_with_clipboard(event, clipboard)
            if native_timing_enabled:
                external_call["moxi_window_timing_end_dispatch", NoneType]()
            event_changed = dispatched or event_changed
            changed = dispatched or changed
            event = window.poll_event()
        if changed:
            render_frame(
                app,
                renderer,
                scene_renderer,
                plot_output,
                reuse_plot_output,
                native_timing_enabled and event_changed,
            )
        if native_timing_enabled and not event_changed:
            external_call["moxi_window_timing_cancel", NoneType]()
