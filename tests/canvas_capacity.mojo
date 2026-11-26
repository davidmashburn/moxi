"""1,000 visible ordinary Components through the normal AppKit canvas host."""
from std.ffi import external_call
from std.collections import List
from std.sys import argv
from std.time import perf_counter_ns
from moxi import App, Component, ColumnView, Rect, Point, Event, WindowConfig, ScrollEvent
from moxi.event import *
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from moxi_canvas import *
from moxi_canvas.native import render_canvas
from canvas_benchmark import fixture, report


struct CapacityNode(Component):
    var clicks: Int

    def __init__(out self):
        self.clicks = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 4, 2)
        view.add_button(1, "Node", 25)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target == 1 and event.kind == CLICK_KIND:
            self.clicks += 1
            return True
        return False


def check(value: Bool, message: String) raises:
    if not value:
        raise Error(message)


def validate(mut app: App[CanvasView[CapacityNode]], mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, path: String) raises:
    check(len(app.component.publication.visible) == 1000, "all 1,000 nodes must be visible")
    check(app.view.child_count() == 3015, "3,015 ordinary view nodes")
    var start = perf_counter_ns()
    render_canvas(app, paint, graph)
    var submit_ms = Float64(perf_counter_ns() - start) / 1_000_000
    check(external_call["moxi_window_command_overflow_count", Int32]() == 0, "native output must not truncate")
    var capture_path = path
    var no_path = String("")
    var raster_ms = external_call["moxi_capacity_raster", Float64](no_path.as_c_string_span().ptr())
    check(raster_ms >= 0, "native raster/capture")
    check(external_call["moxi_canvas_capture", Int32](capture_path.as_c_string_span().ptr()) == 1, "capture actual AppKit content view")
    var visible = Int(external_call["moxi_capacity_visible_buttons", Int32]())
    check(visible == 1000, String("every native button must paint; observed ", visible))
    var last_button = app.view.bounds_for(app.component.control_id(1000, 1))
    check(external_call["moxi_capacity_button_geometry", Int32](last_button.x, last_button.y, last_button.width, last_button.height) == 1, "last native button shares published geometry")
    print("native_frame", path, "views", app.view.child_count(), "paint", app.paint().count(), "ordered", external_call["moxi_capacity_ordered_count", Int32](), "buttons_with_pixels", visible, "overflow", 0, "submit_including_semantics_ms", submit_ms, "drawRect_ms", raster_ms)


def main() raises:
    var args = argv()
    check(len(args) == 2, "Usage: canvas-capacity OUTPUT_DIRECTORY")
    var output = args[1]
    var canvas = CanvasView[CapacityNode](fixture(1000, 2000))
    for object in canvas.document.objects:
        canvas.mount(object.id, CapacityNode())
    var app = App(canvas, Rect(0, 0, 1200, 800))
    _ = invoke_canvas(app, CanvasCommand.FIT_ALL)
    # Keep every node above the foreground minimap, so its blue cells cannot
    # satisfy the per-button pixel checks or cover the last input target.
    app.component.state.camera.pan(0, -64)
    app.rebuild_localized()
    var window = MacOSWindow()
    window.open(WindowConfig("Moxi D03 · 1,000 visible nodes", 1200, 800))
    var paint = MacOSRenderer(present_on_end_frame=False)
    var graph = MacOSCanvasSceneRenderer()
    window.pump()
    var opening = window.poll_event()
    while opening.kind != NONE_KIND:
        _ = dispatch_canvas(app, opening)
        opening = window.poll_event()
    validate(app, paint, graph, output + "/01-all-visible.png")
    # High identities are beyond the former native slot ceiling. Check the last
    # node via object, port and ordinary control hit tests, then actual NSEvents.
    var last = 1000
    var control = app.component.control_id(last, 1)
    var button = app.view.bounds_for(control)
    var at = Point(button.x + button.width / 2, button.y + button.height / 2)
    check(app.runtime.hit_test(at) != control, "child controls stay outside roving input scope before entry")
    check(app.component.snapshot().hit_object(at) == last, "last canvas object hit")
    var port = app.component.snapshot().ports.get(last * 2 + 1, Point(0, 0))
    check(app.component.snapshot().hit_port(port) == last * 2 + 1, "last port hit")
    # Child controls use their normal App routing after explicit entry.
    app.component.state.select(last)
    _ = invoke_canvas(app, CanvasCommand.ENTER_CONTROLS)
    button = app.view.bounds_for(control)
    at = Point(button.x + button.width / 2, button.y + button.height / 2)
    check(app.runtime.hit_test(at) == control, "last ordinary control hit after entry")
    for kind in List[Int]([POINTER_DOWN_KIND, POINTER_UP_KIND]):
        external_call["moxi_capacity_pointer", NoneType](Int32(kind), at.x, at.y)
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            _ = dispatch_canvas(app, event)
            event = window.poll_event()
    check(app.component.mounts[999].child.clicks == 1, "native click reaches last ordinary component once")
    check(app.component.mounts[0].child.clicks == 0, "native click cannot reach first component")
    _ = invoke_canvas(app, CanvasCommand.LEAVE_CONTROLS)
    validate(app, paint, graph, output + "/02-selected-last.png")
    var original = app.component.document.world_bounds(last)
    _ = invoke_canvas(app, CanvasCommand.MOVE)
    app.component.state.nudge(-20, -20)
    app.rebuild_localized()
    var moved = app.component.presentation_document().world_bounds(last)
    check(moved.x == original.x - 20 and moved.y == original.y - 20, "last-node move preview")
    var projected = app.component.state.camera.rect(moved)
    check(app.component.snapshot().hit_object(Point(projected.x + projected.width / 2, projected.y + projected.height / 2)) == last, "moving object hit follows preview")
    validate(app, paint, graph, output + "/03-moving-last.png")
    _ = invoke_canvas(app, CanvasCommand.CANCEL)
    check(app.component.presentation_document().world_bounds(last).x == original.x, "cancel restores world position")
    app.component.state.camera.pan(-4, -3)
    app.rebuild_localized()
    validate(app, paint, graph, output + "/04-panned.png")
    button = app.view.bounds_for(control)
    at = Point(button.x + button.width / 2, button.y + button.height / 2)
    check(app.runtime.hit_test(at) != control and app.component.snapshot().hit_object(at) == last, "pan keeps object hits aligned and child controls outside input scope")
    _ = invoke_canvas(app, CanvasCommand.ENTER_CONTROLS)
    check(app.runtime.hit_test(at) == control, "last ordinary control hit after pan and reentry")
    _ = invoke_canvas(app, CanvasCommand.LEAVE_CONTROLS)
    # Include ordinary App publication, native submission/semantics, and an
    # actual drawRect. This is not compositor, GPU, or device-to-display time.
    var samples = List[Float64]()
    var dispatch_samples = List[Float64]()
    var submit_samples = List[Float64]()
    var raster_samples = List[Float64]()
    var reset_samples = List[Float64]()
    var ax_begin_samples = List[Float64]()
    var ax_end_samples = List[Float64]()
    var no_path = String("")
    var pan_at = app.component.interaction_clip()
    var pan_point = Point(pan_at.x + pan_at.width / 2, pan_at.y + pan_at.height / 2)
    var camera_checksum: Float64 = 0
    var control_checksum: Float64 = 0
    for i in range(40):
        var pan = Event(ScrollEvent(pan_point, Point(Float32(1 if i % 2 == 0 else -1), 0)))
        var previous_x = app.component.state.camera.x
        var start = perf_counter_ns()
        var changed = dispatch_canvas(app, pan)
        var dispatched = perf_counter_ns()
        render_canvas(app, paint, graph)
        var submitted = perf_counter_ns()
        var raster_ms = external_call["moxi_capacity_raster", Float64](no_path.as_c_string_span().ptr())
        var finished = perf_counter_ns()
        samples.append(Float64(finished - start) / 1_000_000)
        dispatch_samples.append(Float64(dispatched - start) / 1_000_000)
        submit_samples.append(Float64(submitted - dispatched) / 1_000_000)
        raster_samples.append(raster_ms)
        reset_samples.append(external_call["moxi_capacity_reset_ms", Float64]())
        ax_begin_samples.append(external_call["moxi_capacity_ax_begin_ms", Float64]())
        ax_end_samples.append(external_call["moxi_capacity_ax_end_ms", Float64]())
        check(changed and (app.component.state.camera.x - previous_x) * Float64(pan.scroll_delta.x) < 0, "normal scroll dispatch pans the camera")
        check(raster_ms >= 0, "timed native drawRect")
        check(app.view.child_count() == 3015 and external_call["moxi_window_command_overflow_count", Int32]() == 0, "timed publication cannot truncate")
        button = app.view.bounds_for(control)
        at = Point(button.x + button.width / 2, button.y + button.height / 2)
        check(external_call["moxi_capacity_button_geometry", Int32](button.x, button.y, button.width, button.height) == 1 and app.component.snapshot().hit_object(at) == last, "timed native/control/object geometry agrees")
        camera_checksum += app.component.state.camera.x
        control_checksum += Float64(button.x + button.y + button.width)
    check(external_call["moxi_capacity_visible_buttons", Int32]() == 1000, "timed pan keeps every node painted")
    report("native-1000-visible scroll dispatch publication submission semantics drawRect (no compositor)", samples)
    report("native-1000-visible dispatch publication", dispatch_samples)
    report("native-1000-visible submission semantics", submit_samples)
    report("native-1000-visible drawRect", raster_samples)
    report("native-1000-visible native reset (within submission)", reset_samples)
    report("native-1000-visible AX begin (within submission)", ax_begin_samples)
    report("native-1000-visible AX end (within submission)", ax_end_samples)
    print("native_window_inline_bytes", external_call["moxi_capacity_state_bytes", Int64]())
    print("normal_scroll_camera_checksum", camera_checksum, "control_geometry_checksum", control_checksum)
    # The historical benchmark's larger root still publishes exactly 3,015
    # views. Submit it too; the real-window captures above use 1,200 x 800.
    _ = app.resize(Rect(0, 0, 7000, 4000))
    app.rebuild_localized()
    check(app.view.child_count() == 3015, "historical 7,000 x 4,000 root")
    render_canvas(app, paint, graph)
    check(external_call["moxi_window_command_overflow_count", Int32]() == 0, "historical large root native capacity")
    # The two ordinary ceilings differ: labels/panels that do not paint still
    # publish semantics. Refuse either limit before touching the prior frame.
    var oversized_canvas = CanvasView[CapacityNode](fixture(1361, 0))
    for object in oversized_canvas.document.objects:
        oversized_canvas.mount(object.id, CapacityNode())
    var oversized = App(oversized_canvas, Rect(0, 0, 7000, 4000))
    _ = invoke_canvas(oversized, CanvasCommand.FIT_ALL)
    var capacity = Int(external_call["moxi_window_command_capacity", Int32]())
    check(oversized.paint().count() == capacity and len(oversized.accessibility().nodes) > capacity, "AX-only boundary fixture")
    var prior_ordered = external_call["moxi_capacity_ordered_count", Int32]()
    var refused = False
    try:
        render_canvas(oversized, paint, graph)
    except:
        refused = True
    check(refused and external_call["moxi_capacity_ordered_count", Int32]() == prior_ordered, "AX limit refused before frame mutation")
    oversized.component.document.add(CanvasObject(1362, Rect(160, 4080, 140, 100), "One over"))
    oversized.component.mount(1362, CapacityNode())
    oversized.rebuild_localized()
    check(oversized.paint().count() > capacity, "ordered boundary fixture")
    refused = False
    try:
        render_canvas(oversized, paint, graph)
    except:
        refused = True
    check(refused and external_call["moxi_capacity_ordered_count", Int32]() == prior_ordered, "ordered limit refused before frame mutation")
    check(external_call["moxi_window_command_overflow_count", Int32]() == 0, "preflight never truncates native state")
    print("D03 native semantic and ordered preflight refusal before frame mutation: PASS; capacity", capacity)
    print("D03 1,000-visible native output, selected/moving nodes, NSEvent input and hit tests: PASS")
    window.close()
