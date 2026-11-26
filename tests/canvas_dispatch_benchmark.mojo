"""Normal App scroll dispatch and paint/scene construction; no native host."""
from std.collections import List
from std.time import perf_counter_ns
from moxi import App, Rect, Point, Event, ScrollEvent
from moxi_canvas import *
from canvas_benchmark import SimpleNode, fixture, consume, report


def main() raises:
    var canvas = CanvasView[SimpleNode](fixture(1000, 2000))
    for object in canvas.document.objects:
        canvas.mount(object.id, SimpleNode())
    var app = App(canvas, Rect(0, 0, 1200, 800))
    _ = invoke_canvas(app, CanvasCommand.FIT_ALL)
    app.component.state.camera.pan(0, -64)
    app.rebuild_localized()
    var viewport = app.component.interaction_clip()
    var at = Point(viewport.x + viewport.width / 2, viewport.y + viewport.height / 2)
    # CPU construction only: excludes native preflight, accessibility, submission
    # and drawing. canvas_capacity.mojo measures those host phases separately.
    var samples = List[Float64]()
    var dispatch = List[Float64]()
    var construction = List[Float64]()
    var checksum: Float64 = 0
    var initial_builds = app.component.mounts[999].builds
    for i in range(40):
        var start = perf_counter_ns()
        var changed = dispatch_canvas(app, Event(ScrollEvent(at, Point(Float32(1 if i % 2 == 0 else -1), 0))))
        var dispatched = perf_counter_ns()
        var paint = app.paint()
        var scene = app.component.scene()
        var constructed = perf_counter_ns()
        if not changed or app.view.child_count() != 3015 or len(app.component.publication.visible) != 1000:
            raise Error("scroll must publish all ordinary children")
        checksum += consume(app.view, scene)
        for j in range(paint.count()):
            var command = paint.command(j)
            checksum += Float64(command.bounds.x + command.bounds.y + command.bounds.width)
        samples.append(Float64(constructed - start) / 1_000_000)
        dispatch.append(Float64(dispatched - start) / 1_000_000)
        construction.append(Float64(constructed - dispatched) / 1_000_000)
    report("normal-1000-visible dispatch publication", dispatch)
    report("normal-1000-visible paint and scene construction", construction)
    report("normal-1000-visible dispatch through pre-submission", samples)
    print("published_nodes", app.view.child_count(), "scene_commands", app.component.scene().count(), "paint_commands", app.paint().count(), "unrelated_measurements", app.component.mounts[999].builds - initial_builds, "checksum", checksum)
