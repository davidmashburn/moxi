"""Composed data-workbench application benchmark.

The benchmark exercises the public application path used by the native demo:
the parameterized WorkbenchData fixture is passed to DataWorkbenchState,
mounted in App, dispatched through App.dispatch, and rendered through the
retained paint stream plus the linked scatter/histogram scene.  The software
renderer is a deterministic headless oracle; its timings do not represent
input-to-display latency in a native window.
"""

from std.ffi import external_call

from moxi import (
    App,
    CLICK_KIND,
    ClickEvent,
    Event,
    ExecutionWorkCounters,
    POINTER_MOVE_KIND,
    Point,
    PointerEvent,
    Rect,
    ResizeEvent,
    SCENE_ROUNDED_RECT,
    ScrollEvent,
    Scene,
    Size,
    SoftwareSceneRenderer,
    TextInputEvent,
    test_check,
    scene_from_paint,
)
from moxi_demo.data_workbench import (
    DATA_WORKBENCH_CLEAR_FILTER_ID,
    DATA_WORKBENCH_HISTOGRAM_CANVAS_ID,
    DATA_WORKBENCH_SCATTER_CANVAS_ID,
    DATA_WORKBENCH_TABLE_PORTAL_ID,
    DATA_WORKBENCH_THRESHOLD_ID,
    DataWorkbenchState,
)
from moxi_demo.workbench_data import make_workbench_fixture


comptime WORKBENCH_WIDTH: Float32 = 1180.0
comptime WORKBENCH_HEIGHT: Float32 = 820.0
comptime FILTER_TEXT = "4.50"
comptime POINTER_PADDING: Float32 = 1.0


def benchmark_time_ns() -> Int64:
    return external_call["moxi_benchmark_time_ns", Int64]()


struct FrameMetrics(ImplicitlyCopyable):
    """Counts and checksum for one complete headless application frame."""

    var retained_commands: Int
    var plot_commands: Int
    var render_commands: Int
    var rasterized_pixels: Int
    var checksum: Int

    def __init__(out self):
        self.retained_commands = 0
        self.plot_commands = 0
        self.render_commands = 0
        self.rasterized_pixels = 0
        self.checksum = 0


struct OperationMetrics(ImplicitlyCopyable):
    """One timed dispatch followed by the same scene/render path as a host."""

    var elapsed_ms: Float64
    var changed: Bool
    var frame: FrameMetrics
    var work: ExecutionWorkCounters

    def __init__(out self):
        self.elapsed_ms = 0.0
        self.changed = False
        self.frame = FrameMetrics()
        self.work = ExecutionWorkCounters()


def midpoint(bounds: Rect) -> Point:
    return Point(
        bounds.x + bounds.width * 0.5,
        bounds.y + bounds.height * 0.5,
    )


def inset_midpoint(bounds: Rect) -> Point:
    var point = midpoint(bounds)
    if point.x <= bounds.x:
        point.x = bounds.x + POINTER_PADDING
    if point.y <= bounds.y:
        point.y = bounds.y + POINTER_PADDING
    return point


def bool_word(value: Bool) -> String:
    return "true" if value else "false"


def find_plot_point(scene: Scene, bounds: Rect) -> Point:
    """Choose a real emitted scatter marker for hover and selection.

    This derives the input coordinate from the component's scene.  It does
    not recreate row coordinates in the benchmark, so a change to the plot
    scale, filtering, or fixture remains visible in the interaction path.
    """
    for index in range(scene.count()):
        var command = scene.command(index)
        var marker = command.kind == SCENE_ROUNDED_RECT
        var small = command.bounds.width >= 4.0 and command.bounds.width <= 8.0
        small = small and command.bounds.height >= 4.0 and command.bounds.height <= 8.0
        if marker and small and bounds.contains(midpoint(command.bounds)):
            return midpoint(command.bounds)
    return inset_midpoint(bounds)


def work_delta(
    before: ExecutionWorkCounters,
    after: ExecutionWorkCounters,
) -> ExecutionWorkCounters:
    var result = ExecutionWorkCounters()
    result.invalidation_count = after.invalidation_count - before.invalidation_count
    result.dependency_visits = after.dependency_visits - before.dependency_visits
    result.dirty_marks = after.dirty_marks - before.dirty_marks
    result.dirty_consumed = after.dirty_consumed - before.dirty_consumed
    result.component_builds = after.component_builds - before.component_builds
    result.reconciled_nodes = after.reconciled_nodes - before.reconciled_nodes
    result.paint_commands = after.paint_commands - before.paint_commands
    result.parent_builds = after.parent_builds - before.parent_builds
    result.root_fallbacks = after.root_fallbacks - before.root_fallbacks
    result.keyed_insertions = after.keyed_insertions - before.keyed_insertions
    result.keyed_removals = after.keyed_removals - before.keyed_removals
    result.keyed_moves = after.keyed_moves - before.keyed_moves
    return result^


def render_workbench(
    mut app: App[DataWorkbenchState],
    mut renderer: SoftwareSceneRenderer,
) raises -> FrameMetrics:
    """Render retained controls and both linked plot scenes in one frame."""
    var frame = FrameMetrics()
    var paint = app.paint()
    var retained = scene_from_paint(paint)
    frame.retained_commands = retained.count()
    renderer.render_scene(retained)
    var retained_pixels = renderer.rasterized_pixels
    var retained_checksum = renderer.checksum()

    var scatter_bounds = app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID)
    var histogram_bounds = app.view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID)
    var plots = app.component.combined_scene(scatter_bounds, histogram_bounds)
    frame.plot_commands = plots.count()
    renderer.render_scene(plots)
    frame.render_commands = frame.retained_commands + frame.plot_commands
    frame.rasterized_pixels = retained_pixels + renderer.rasterized_pixels
    frame.checksum = retained_checksum + renderer.checksum()
    return frame^


def dispatch_and_render(
    mut app: App[DataWorkbenchState],
    mut renderer: SoftwareSceneRenderer,
    event: Event,
) raises -> OperationMetrics:
    var result = OperationMetrics()
    var before = app.execution_work_counters()
    var start = benchmark_time_ns()
    result.changed = app.dispatch(event)
    result.frame = render_workbench(app, renderer)
    var end = benchmark_time_ns()
    result.elapsed_ms = Float64(end - start) / 1000000.0
    result.work = work_delta(before, app.execution_work_counters())
    return result^


def print_case(
    row_count: Int,
    operation: String,
    elapsed_ms: Float64,
    changed: Bool,
    app: App[DataWorkbenchState],
    frame: FrameMetrics,
    work: ExecutionWorkCounters,
):
    """Emit one parser-friendly record; every field is one key=value token."""
    print(
        "WORKBENCH ",
        String("rows=", row_count),
        " ",
        String("operation=", operation),
        " ",
        String("in_process_elapsed_ms=", elapsed_ms),
        " ",
        String("dispatch_changed=", bool_word(changed)),
        " ",
        String("source_rows=", app.component.total_row_count()),
        " ",
        String("visible_rows=", app.component.visible_row_count()),
        " ",
        String("selection_rows=", app.component.selected_row_count()),
        " ",
        String("hidden_selection_rows=", app.component.hidden_selected_row_count()),
        " ",
        String("scroll_offset=", app.component.table_scroll_offset()),
        " ",
        String("retained_commands=", frame.retained_commands),
        " ",
        String("plot_commands=", frame.plot_commands),
        " ",
        String("render_commands=", frame.render_commands),
        " ",
        String("rasterized_pixels=", frame.rasterized_pixels),
        " ",
        String("component_builds=", work.component_builds),
        " ",
        String("reconciled_nodes=", work.reconciled_nodes),
        " ",
        String("root_fallbacks=", work.root_fallbacks),
        " ",
        String("checksum=", frame.checksum),
        " visible_latency=not_measured cache_reuse=not_measured",
    )


def settle(mut app: App[DataWorkbenchState], mut renderer: SoftwareSceneRenderer) raises:
    _ = render_workbench(app, renderer)


def click_view(
    mut app: App[DataWorkbenchState],
    mut renderer: SoftwareSceneRenderer,
    target_id: Int,
) raises:
    var bounds = app.view.bounds_for(target_id)
    _ = app.dispatch(Event(ClickEvent(inset_midpoint(bounds))))
    settle(app, renderer)


def run_case(row_count: Int) raises:
    var bounds = Rect(0.0, 0.0, WORKBENCH_WIDTH, WORKBENCH_HEIGHT)
    var cold_start = benchmark_time_ns()
    var fixture = make_workbench_fixture(row_count)
    var component = DataWorkbenchState(fixture)
    var app = App[DataWorkbenchState](component, bounds)
    var renderer = SoftwareSceneRenderer(Int(WORKBENCH_WIDTH), Int(WORKBENCH_HEIGHT))
    var cold_frame = render_workbench(app, renderer)
    var cold_end = benchmark_time_ns()
    var cold_elapsed_ms = Float64(cold_end - cold_start) / 1000000.0
    var cold_work = app.execution_work_counters()

    test_check(app.view_is_valid())
    test_check(app.component.total_row_count() == row_count)
    test_check(cold_frame.plot_commands > 0)
    print_case(
        row_count,
        "cold_load",
        cold_elapsed_ms,
        True,
        app,
        cold_frame,
        cold_work,
    )

    var scatter_bounds = app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID)
    var scatter_scene = app.component.scatter_scene(scatter_bounds)
    var plot_point = find_plot_point(scatter_scene, scatter_bounds)

    # Focus the real text control before measuring its committed replacement.
    click_view(app, renderer, DATA_WORKBENCH_THRESHOLD_ID)
    var filter_event = Event(TextInputEvent(FILTER_TEXT, 0, 4))
    filter_event.target = DATA_WORKBENCH_THRESHOLD_ID
    var filter_result = dispatch_and_render(app, renderer, filter_event)
    test_check(filter_result.changed)
    test_check(filter_result.frame.plot_commands > 0)
    test_check(app.component.visible_row_count() < row_count)
    print_case(
        row_count,
        "filter",
        filter_result.elapsed_ms,
        filter_result.changed,
        app,
        filter_result.frame,
        filter_result.work,
    )

    click_view(app, renderer, DATA_WORKBENCH_CLEAR_FILTER_ID)

    var hover_event = Event(PointerEvent(POINTER_MOVE_KIND, plot_point))
    var hover_result = dispatch_and_render(app, renderer, hover_event)
    test_check(hover_result.changed)
    print_case(
        row_count,
        "hover",
        hover_result.elapsed_ms,
        hover_result.changed,
        app,
        hover_result.frame,
        hover_result.work,
    )

    var selection_event = Event(ClickEvent(plot_point))
    var selection_result = dispatch_and_render(app, renderer, selection_event)
    test_check(selection_result.changed)
    test_check(app.component.selected_row_count() > 0)
    print_case(
        row_count,
        "selection",
        selection_result.elapsed_ms,
        selection_result.changed,
        app,
        selection_result.frame,
        selection_result.work,
    )

    var table_bounds = app.view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID)
    var scroll_event = Event(
        ScrollEvent(inset_midpoint(table_bounds), Point(0.0, 480.0))
    )
    var scroll_result = dispatch_and_render(app, renderer, scroll_event)
    test_check(scroll_result.changed)
    test_check(app.component.table_scroll_offset() > 0.0)
    print_case(
        row_count,
        "scroll",
        scroll_result.elapsed_ms,
        scroll_result.changed,
        app,
        scroll_result.frame,
        scroll_result.work,
    )

    var resize_result = dispatch_and_render(
        app,
        renderer,
        Event(ResizeEvent(Size(1280.0, 900.0))),
    )
    test_check(resize_result.changed)
    test_check(app.view_is_valid())
    print_case(
        row_count,
        "resize",
        resize_result.elapsed_ms,
        resize_result.changed,
        app,
        resize_result.frame,
        resize_result.work,
    )


def main() raises:
    print("Moxi data-workbench composed benchmark")
    print("measurement_boundary=cold_fixture_state_app_first_frame_and_steady_dispatch_plus_scene_render")
    print("fixture=make_workbench_fixture_parameterized")
    print("application_path=DataWorkbenchState_App_dispatch_combined_scene")
    print("visible_latency=not_measured")
    print("memory=process_peak_only_if_wrapper_supports_it")
    print("memory_scope=process_not_operation_level")
    print("release_baseline=unestablished")
    run_case(10000)
    run_case(100000)
