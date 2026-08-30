"""Repeatable layout/reconcile/paint workload for local comparisons."""

from moxi import (
    ColumnRuntime,
    Rect,
    PerformanceCounters,
    PerformanceReport,
    SoftwareSceneRenderer,
    VirtualListState,
    WxStyleState,
    scene_from_paint,
)


def main() raises:
    var view = WxStyleState().build(Rect(0.0, 0.0, 560.0, 1100.0))
    var runtime = ColumnRuntime()
    var renderer = SoftwareSceneRenderer(240, 400)
    var virtual = VirtualListState(10000, 24.0, 2)
    virtual.set_viewport(240.0, 400.0)
    var metrics = PerformanceCounters()

    var passes = 100
    for _ in range(passes):
        view.layout()
        runtime.reconcile(view)
        var commands = runtime.paint()
        var scene = scene_from_paint(commands)
        renderer.render_scene(scene)
        metrics.record_frame(
            view.child_count(),
            view.child_count(),
            commands.count(),
            scene.count(),
            renderer.rasterized_pixels,
        )
        virtual.scroll_by(0.0, 12.0)

    var visible = virtual.visible()
    print("Moxi retained pipeline benchmark passes: ", passes)
    print("Moxi layout benchmark children: ", view.child_count())
    print("Moxi paint benchmark commands: ", runtime.paint().count())
    print("Moxi scene benchmark checksum: ", renderer.checksum())
    print("Moxi virtual benchmark visible: ", visible.start, "..", visible.end)
    var report = PerformanceReport(metrics)
    print("Moxi benchmark average operations/frame: ", report.counters.average_operations())
    print("Moxi benchmark rasterized pixels/frame: ", metrics.rasterized_pixels // passes)
    print("Moxi benchmark timing: /usr/bin/time reports wall-clock process time")
