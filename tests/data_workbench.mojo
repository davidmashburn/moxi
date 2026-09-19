"""App-level workflow tests for the native data workbench surface."""

from moxi import (
    App,
    ACTION_PRESS,
    Event,
    FRAME_TICK_KIND,
    FrameEvent,
    KEY_A,
    KEY_C,
    KEY_ENTER,
    KeyEvent,
    MemoryClipboard,
    MOD_COMMAND,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    Rect,
    ResizeEvent,
    ScrollEvent,
    SemanticActionEvent,
    Size,
    TextInputEvent,
    test_check,
)
from moxi_demo.data_workbench import (
    DATA_WORKBENCH_CLEAR_FILTER_ID,
    DATA_WORKBENCH_EXPORT_CSV_ID,
    DATA_WORKBENCH_EXPORT_SVG_ID,
    DATA_WORKBENCH_FILTER_FIELD_ID,
    DATA_WORKBENCH_HISTOGRAM_CANVAS_ID,
    DATA_WORKBENCH_IMPORT_ID,
    DATA_WORKBENCH_IMPORT_PATH_ID,
    DATA_WORKBENCH_PLOT_ROW_ID,
    DATA_WORKBENCH_SCATTER_CANVAS_ID,
    DATA_WORKBENCH_SORT_ID,
    DATA_WORKBENCH_TABLE_PORTAL_ID,
    DATA_WORKBENCH_TABLE_ROW_BASE,
    DATA_WORKBENCH_THRESHOLD_ID,
    DATA_WORKBENCH_X_FIELD_ID,
    DATA_WORKBENCH_Y_FIELD_ID,
    DataWorkbenchState,
)
from moxi_demo.workbench_data import WorkbenchData


def _click(mut app: App[DataWorkbenchState], target: Int) -> Bool:
    """Activate a mounted control through App's pointer routing."""
    var bounds = app.view.bounds_for(target)
    if bounds.width <= 0.0 or bounds.height <= 0.0:
        return False
    var point = Point(bounds.x + 2.0, bounds.y + 2.0)
    var pressed = app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, point)))
    var released = app.dispatch(Event(PointerEvent(POINTER_UP_KIND, point)))
    return pressed and released


def _click_point(mut app: App[DataWorkbenchState], point: Point) -> Bool:
    """Send a plot click through the same pointer stream as a host window."""
    var pressed = app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, point)))
    var released = app.dispatch(Event(PointerEvent(POINTER_UP_KIND, point)))
    return pressed and released


def _replace_text(
    mut app: App[DataWorkbenchState],
    target: Int,
    text: String,
    end: Int,
) -> Bool:
    """Replace the complete text value through App's targeted text path."""
    var event = Event(TextInputEvent(text, 0, end))
    event.set_target(target)
    return app.dispatch(event)


def _write_file(path: String, contents: String) raises:
    with open(path, "w") as destination:
        destination.write(contents)


def _read_file(path: String) raises -> String:
    with open(path, "r") as source:
        return source.read()


def main() raises:
    # Explicit CSV keys preserve source identity across the batched plot path.
    var keyed = WorkbenchData()
    var loaded = keyed.load_csv("key,x,y\n90,1,2\n2,2,8\n400000,3,5\n7,4,1\n")
    test_check(loaded.accepted)
    test_check(keyed.select_key(90))
    test_check(keyed.select_key(400000))
    test_check(keyed.set_filter("y", 3.0))
    test_check(keyed.sort_visible("y"))
    test_check(keyed.visible_key_at(0) == 400000)
    var keyed_state = DataWorkbenchState(keyed)
    test_check(keyed_state.scatter_view.data.key_at(0) == 2)
    test_check(keyed_state.scatter_view.data.key_at(1) == 400000)
    test_check(keyed_state.scatter_view.data.row_count() == 2)
    test_check(keyed_state.data.hidden_selected_count() == 1)
    test_check(keyed_state.data.export_selected_csv() == "key,x,y\n90,1.0,2.0\n400000,3.0,5.0\n")
    var app = App[DataWorkbenchState](
        DataWorkbenchState(),
        Rect(0.0, 0.0, 1180.0, 820.0),
    )

    # The full retained view and semantic tree mount before any interaction.
    test_check(app.view.is_valid())
    test_check(app.component.total_row_count() == 48)
    test_check(app.component.visible_row_count() == 48)
    test_check(app.component.selected_row_count() == 0)
    test_check(app.view.bounds_for(DATA_WORKBENCH_PLOT_ROW_ID).width > 0.0)
    test_check(app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID).width > 0.0)
    test_check(app.view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID).width > 0.0)
    test_check(app.view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID).height >= 150.0)
    test_check(app.accessibility().count() > 10)
    test_check(app.component.status_text().count_codepoints() > 0)

    # Field controls cycle through numeric fields while keeping x/y distinct.
    test_check(_click(app, DATA_WORKBENCH_X_FIELD_ID))
    test_check(app.component.x_field == "time")
    test_check(_click(app, DATA_WORKBENCH_Y_FIELD_ID))
    test_check(app.component.y_field == "value")
    test_check(_click(app, DATA_WORKBENCH_FILTER_FIELD_ID))
    test_check(app.component.filter_field == "size")

    # Select and deselect a table row by its mounted virtualized row control.
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    test_check(app.component.selected_row_count() == 1)
    test_check(app.component.data.is_selected_key(0))
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    test_check(app.component.selected_row_count() == 0)

    # The table owns its own scroll state and preserves it through resize.
    var table_bounds = app.view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID)
    var table_point = Point(table_bounds.x + 20.0, table_bounds.y + 20.0)
    var scatter_reuse_bounds = app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID)
    var scatter_reuse_point = Point(
        scatter_reuse_bounds.x + 20.0,
        scatter_reuse_bounds.y + 20.0,
    )

    # Plot output reuse is intentionally narrow: only a table scroll may
    # preserve the plot render output, and only when the event is over the
    # table portal (or has already been routed to that portal).
    var selection_event = Event(
        SemanticActionEvent(DATA_WORKBENCH_TABLE_ROW_BASE, ACTION_PRESS)
    )
    test_check(not app.component.can_reuse_plot_output(selection_event, app.view))
    var filter_event = Event(TextInputEvent("6.0", 0, 3))
    filter_event.set_target(DATA_WORKBENCH_THRESHOLD_ID)
    test_check(not app.component.can_reuse_plot_output(filter_event, app.view))
    var clear_filter_event = Event(
        SemanticActionEvent(DATA_WORKBENCH_CLEAR_FILTER_ID, ACTION_PRESS)
    )
    test_check(not app.component.can_reuse_plot_output(clear_filter_event, app.view))
    var x_axis_event = Event(
        SemanticActionEvent(DATA_WORKBENCH_X_FIELD_ID, ACTION_PRESS)
    )
    test_check(not app.component.can_reuse_plot_output(x_axis_event, app.view))
    var y_axis_event = Event(
        SemanticActionEvent(DATA_WORKBENCH_Y_FIELD_ID, ACTION_PRESS)
    )
    test_check(not app.component.can_reuse_plot_output(y_axis_event, app.view))
    var pointer_event = Event(
        PointerEvent(POINTER_DOWN_KIND, scatter_reuse_point)
    )
    test_check(not app.component.can_reuse_plot_output(pointer_event, app.view))
    var plot_zoom_event = Event(
        ScrollEvent(scatter_reuse_point, Point(0.0, 20.0))
    )
    test_check(not app.component.can_reuse_plot_output(plot_zoom_event, app.view))
    var resize_event = Event(ResizeEvent(Size(1020.0, 760.0)))
    test_check(not app.component.can_reuse_plot_output(resize_event, app.view))
    var tick_event = Event(FrameEvent(1.0 / 60.0))
    test_check(tick_event.kind == FRAME_TICK_KIND)
    test_check(not app.component.can_reuse_plot_output(tick_event, app.view))

    var routed_table_scroll = Event(
        ScrollEvent(Point(0.0, 0.0), Point(0.0, 120.0))
    )
    routed_table_scroll.set_target(DATA_WORKBENCH_TABLE_PORTAL_ID)
    test_check(app.component.can_reuse_plot_output(routed_table_scroll, app.view))

    # A real table scroll keeps the linked data and both plot models intact.
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    var scatter_selection_before = app.component.scatter_view.runtime.selection()
    var histogram_selection_before = app.component.histogram_view.runtime.selection()
    var scatter_revision_before = app.component.scatter_view.runtime.plot.revision
    var histogram_revision_before = app.component.histogram_view.runtime.plot.revision
    test_check(app.component.data.selected_count() == 1)
    test_check(app.component.data.is_selected_key(0))
    test_check(scatter_selection_before.count() == 1)
    test_check(histogram_selection_before.count() == 1)
    var table_scroll_event = Event(ScrollEvent(table_point, Point(0.0, 120.0)))
    test_check(app.component.can_reuse_plot_output(table_scroll_event, app.view))
    test_check(
        app.dispatch(table_scroll_event)
    )
    test_check(app.component.table_scroll_offset() > 0.0)
    test_check(app.component.data.selected_count() == 1)
    test_check(app.component.data.is_selected_key(0))
    var scatter_selection_after = app.component.scatter_view.runtime.selection()
    var histogram_selection_after = app.component.histogram_view.runtime.selection()
    test_check(
        app.component.scatter_view.runtime.plot.revision == scatter_revision_before
    )
    test_check(
        app.component.histogram_view.runtime.plot.revision == histogram_revision_before
    )
    test_check(scatter_selection_after.count() == scatter_selection_before.count())
    test_check(scatter_selection_after.key_at(0) == scatter_selection_before.key_at(0))
    test_check(
        histogram_selection_after.count() == histogram_selection_before.count()
    )
    test_check(
        histogram_selection_after.key_at(0) == histogram_selection_before.key_at(0)
    )
    var deselect_row_event = Event(
        SemanticActionEvent(DATA_WORKBENCH_TABLE_ROW_BASE, ACTION_PRESS)
    )
    test_check(app.dispatch(deselect_row_event))
    test_check(app.component.selected_row_count() == 0)
    var old_table_offset = app.component.table_scroll_offset()
    test_check(app.resize(Rect(0.0, 0.0, 1020.0, 760.0)))
    test_check(app.component.table_scroll_offset() == old_table_offset)
    test_check(app.view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID).height >= 150.0)
    var reset_table_bounds = app.view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID)
    var reset_table_point = Point(reset_table_bounds.x + 20.0, reset_table_bounds.y + 20.0)
    test_check(
        app.dispatch(Event(ScrollEvent(reset_table_point, Point(0.0, -10000.0))))
    )
    test_check(app.component.table_scroll_offset() == 0.0)

    # Filter by the selected filter field and keep a hidden row selected.
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    test_check(app.component.selected_row_count() == 1)
    test_check(_replace_text(app, DATA_WORKBENCH_THRESHOLD_ID, "6.0", 4))
    test_check(app.component.visible_row_count() < app.component.total_row_count())
    test_check(app.component.hidden_selected_row_count() == 1)
    test_check(_click(app, DATA_WORKBENCH_CLEAR_FILTER_ID))
    test_check(app.component.visible_row_count() == app.component.total_row_count())
    test_check(app.component.selected_row_count() == 1)
    test_check(app.component.hidden_selected_row_count() == 0)
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    test_check(app.component.selected_row_count() == 0)

    # Sorting is routed by pointer activation and keeps the visible order
    # monotone after the component rebuilds its plot/table projections.
    test_check(_click(app, DATA_WORKBENCH_SORT_ID))
    test_check(app.component.sort_descending)
    test_check(
        app.component.data.visible_value_at("value", 0)
        >= app.component.data.visible_value_at("value", 1)
    )
    test_check(app.component.data.visible_key_at(0) == 12)
    test_check(app.component.data.visible_key_at(1) == 29)
    # The same focused button also handles the keyboard activation path.
    test_check(app.dispatch(Event(KeyEvent(KEY_ENTER))))
    test_check(not app.component.sort_descending)
    # Accessibility activation routes through the same App event contract.
    test_check(
        app.dispatch(
            Event(SemanticActionEvent(DATA_WORKBENCH_SORT_ID, ACTION_PRESS))
        )
    )
    test_check(app.component.sort_descending)

    # Import through the bounded native-file action using sparse stable keys.
    # The missing y value also exercises the table/plot validity contract.
    var import_path = "/tmp/moxi-data-workbench-integration.csv"
    var selected_path = String(import_path, ".selected.csv")
    var svg_path = String(import_path, ".scatter.svg")
    var sparse_csv = "key,x,y\n1000,1,\n2000,2,5\n"
    _write_file(import_path, sparse_csv)
    test_check(_replace_text(app, DATA_WORKBENCH_IMPORT_PATH_ID, import_path, 0))
    test_check(
        app.dispatch(
            Event(SemanticActionEvent(DATA_WORKBENCH_IMPORT_ID, ACTION_PRESS))
        )
    )
    test_check(app.component.total_row_count() == 2)
    test_check(app.component.data.key_at(0) == 1000)
    test_check(app.component.data.key_at(1) == 2000)
    test_check(not app.component.data.value_is_valid("y", 0))
    test_check(app.component.data.value_is_valid("y", 1))
    test_check(app.component.x_field == "x")
    test_check(app.component.y_field == "y")

    # A focused table row copies the selected Y value through the host
    # clipboard boundary, including the explicit missing-value label.
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    var missing_clipboard = MemoryClipboard()
    test_check(
        not app.dispatch_with_clipboard(
            Event(KeyEvent(KEY_C, MOD_COMMAND)),
            missing_clipboard,
        )
    )
    test_check(missing_clipboard.text == "missing")
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE + 1))
    var numeric_clipboard = MemoryClipboard()
    test_check(
        not app.dispatch_with_clipboard(
            Event(KeyEvent(KEY_C, MOD_COMMAND)),
            numeric_clipboard,
        )
    )
    test_check(numeric_clipboard.text == "5.0")
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE))
    test_check(_click(app, DATA_WORKBENCH_TABLE_ROW_BASE + 1))
    test_check(app.component.selected_row_count() == 0)

    # Clicking the only valid scatter observation selects its sparse key.
    var scatter_bounds = app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID)
    var histogram_bounds = app.view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID)
    app.component.scatter_view.set_bounds(scatter_bounds)
    app.component.histogram_view.set_bounds(histogram_bounds)
    var scatter_point = app.component.scatter_view.runtime.plot.series[0].points[0]
    var scatter_position = app.component.scatter_view.runtime.plot.screen_point(scatter_point)
    test_check(_click_point(app, scatter_position))
    test_check(app.component.selected_row_count() == 1)
    test_check(app.component.data.is_selected_key(2000))
    var histogram_selection = app.component.histogram_view.runtime.selection()
    test_check(histogram_selection.count() == 1)
    test_check(histogram_selection.key_at(0) >= 0)
    test_check(histogram_selection.key_at(0) < 18)
    test_check(histogram_selection.key_at(0) != 1000)
    test_check(histogram_selection.key_at(0) != 2000)

    # Selecting the synthetic histogram bin maps back to the sparse row key;
    # it must never be treated as the observation's stable key.
    var histogram_point = app.component.histogram_view.runtime.plot.series[0].points[0]
    var found_histogram_point = False
    for index in range(app.component.histogram_view.runtime.plot.series[0].count()):
        var candidate = app.component.histogram_view.runtime.plot.series[0].points[index]
        if candidate.y > 0.0:
            histogram_point = candidate
            found_histogram_point = True
            break
    test_check(found_histogram_point)
    test_check(_click_point(
        app,
        app.component.histogram_view.runtime.plot.screen_point(histogram_point),
    ))
    test_check(app.component.data.is_selected_key(2000))
    test_check(app.component.selected_row_count() == 1)

    # Export actions update their in-memory values and write the host files.
    test_check(_click(app, DATA_WORKBENCH_EXPORT_CSV_ID))
    test_check(app.component.selected_csv_text().count_codepoints() > 0)
    test_check(_read_file(selected_path) == app.component.selected_csv_text())
    test_check(_click(app, DATA_WORKBENCH_IMPORT_PATH_ID))
    test_check(app.dispatch(Event(KeyEvent(KEY_A, MOD_COMMAND))))
    var clipboard = MemoryClipboard()
    test_check(
        not app.dispatch_with_clipboard(
            Event(KeyEvent(KEY_C, MOD_COMMAND)),
            clipboard,
        )
    )
    test_check(clipboard.text == import_path)
    test_check(_click(app, DATA_WORKBENCH_EXPORT_SVG_ID))
    test_check(app.component.svg_text().count_codepoints() > 0)
    test_check(_read_file(svg_path).count_codepoints() > 0)

    # A one-column import has a valid y fallback and preserves missing cells.
    var one_column = app.component.load_csv_text("only\nnull\n2\n")
    test_check(one_column.accepted)
    app.rebuild()
    test_check(app.component.total_row_count() == 2)
    test_check(app.component.x_field == "only")
    test_check(app.component.y_field == "only")
    test_check(not app.component.data.value_is_valid("only", 0))
    test_check(app.component.data.value_is_valid("only", 1))

    # A malformed replacement reports an error while retaining the old data.
    var old_rows = app.component.total_row_count()
    var rejected = app.component.load_csv_text("only\nnot-a-number\n")
    test_check(not rejected.accepted)
    test_check(app.component.total_row_count() == old_rows)
    test_check(app.component.status_text().count_codepoints() > 0)
    app.rebuild()

    var final_scene = app.component.combined_scene(
        app.view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID),
        app.view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID),
    )
    test_check(len(final_scene.commands) > 0)
    print("Moxi data-workbench integration test passed")
