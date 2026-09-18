"""Native-friendly numerical data workbench component.

The component keeps the workflow state in one place and presents three linked
surfaces: a PlotView scatter plot, a PlotView histogram, and a virtualized
table.  Hosts own the native window and submit ``combined_scene`` once after
rendering the retained Moxi view.
"""

from std.collections import List
from std.math import floor

from moxi import (
    BUTTON_KIND,
    ACTION_KIND,
    ACTION_PRESS,
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    Color,
    ColumnView,
    Component,
    Event,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
    MOD_COMMAND,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    Rect,
    SCROLL_KIND,
    Scene,
    SvgSceneRenderer,
    TextInputControl,
    TextInputState,
    TEXT_INPUT_KIND,
    VirtualItemBuilder,
    VirtualizedList,
    ViewNode,
)
from moxi.controls_basic import ButtonControl
from moxi_plot import PlotDataTable, PlotSpec, PlotView, PlotSelection

from .workbench_data import CsvLoadResult, WorkbenchData, make_workbench_fixture
from .workbench_files import read_workbench_csv, write_workbench_export


comptime DATA_WORKBENCH_TITLE_ID = 100
comptime DATA_WORKBENCH_STATUS_ID = 101
comptime DATA_WORKBENCH_X_LABEL_ID = 102
comptime DATA_WORKBENCH_Y_LABEL_ID = 103
comptime DATA_WORKBENCH_FILTER_LABEL_ID = 104
comptime DATA_WORKBENCH_CSV_LABEL_ID = 105
comptime DATA_WORKBENCH_X_FIELD_ID = 110
comptime DATA_WORKBENCH_Y_FIELD_ID = 111
comptime DATA_WORKBENCH_FILTER_FIELD_ID = 112
comptime DATA_WORKBENCH_THRESHOLD_ID = 113
comptime DATA_WORKBENCH_CLEAR_FILTER_ID = 114
comptime DATA_WORKBENCH_IMPORT_PATH_ID = 120
comptime DATA_WORKBENCH_IMPORT_ID = 121
comptime DATA_WORKBENCH_SORT_ID = 122
comptime DATA_WORKBENCH_EXPORT_CSV_ID = 123
comptime DATA_WORKBENCH_EXPORT_SVG_ID = 124
comptime DATA_WORKBENCH_PLOT_ROW_ID = 130
comptime DATA_WORKBENCH_SCATTER_CANVAS_ID = 131
comptime DATA_WORKBENCH_HISTOGRAM_CANVAS_ID = 132
comptime DATA_WORKBENCH_TABLE_HEADER_ID = 140
comptime DATA_WORKBENCH_TABLE_PORTAL_ID = 141
comptime DATA_WORKBENCH_TABLE_SLOT_ID = 142
comptime DATA_WORKBENCH_TABLE_ROW_BASE = 4_000_000
comptime DATA_WORKBENCH_TABLE_ROW_HEIGHT: Float32 = 28.0
comptime DATA_WORKBENCH_HISTOGRAM_BINS = 18


struct _ThresholdResult(ImplicitlyCopyable):
    var valid: Bool
    var value: Float32

    def __init__(out self, valid: Bool, value: Float32 = 0.0):
        self.valid = valid
        self.value = value


struct _HistogramParameters(ImplicitlyCopyable):
    """The range used by the plotting histogram's fixed bin count."""

    var valid: Bool
    var minimum: Float32
    var maximum: Float32
    var width: Float32

    def __init__(out self):
        self.valid = False
        self.minimum = 0.0
        self.maximum = 0.0
        self.width = 1.0


def _parse_threshold(text: String) -> _ThresholdResult:
    """Parse the small decimal form used by the threshold control."""
    var value = text
    var length = value.count_codepoints()
    var cursor = 0
    if length == 0:
        return _ThresholdResult(False)
    var sign: Float32 = 1.0
    var first = String(value[codepoint=0:1])
    if first == "-":
        sign = -1.0
        cursor = 1
    elif first == "+":
        cursor = 1
    var whole: Float32 = 0.0
    var digits = 0
    while cursor < length:
        var codepoint = ord(String(value[codepoint=cursor:cursor + 1]))
        if codepoint < 48 or codepoint > 57:
            break
        whole = whole * 10.0 + Float32(codepoint - 48)
        digits += 1
        cursor += 1
    var fraction: Float32 = 0.0
    var scale: Float32 = 0.1
    if cursor < length and String(value[codepoint=cursor:cursor + 1]) == ".":
        cursor += 1
        while cursor < length:
            var codepoint = ord(String(value[codepoint=cursor:cursor + 1]))
            if codepoint < 48 or codepoint > 57:
                break
            fraction += Float32(codepoint - 48) * scale
            scale *= 0.1
            digits += 1
            cursor += 1
    if digits == 0 or cursor != length:
        return _ThresholdResult(False)
    return _ThresholdResult(True, sign * (whole + fraction))


struct WorkbenchRowBuilder(VirtualItemBuilder):
    """Build a table row from a source-row index supplied by the recycler."""

    var keys: List[Int]
    var visible_sources: List[Int]
    var x_values: List[Float32]
    var y_values: List[Float32]
    var x_valid: List[Bool]
    var y_valid: List[Bool]
    var x_field: String
    var y_field: String
    var selected: PlotSelection

    def __init__(
        out self,
        keys: List[Int],
        visible_sources: List[Int],
        x_values: List[Float32],
        y_values: List[Float32],
        x_valid: List[Bool],
        y_valid: List[Bool],
        x_field: String,
        y_field: String,
        selected: PlotSelection,
    ):
        self.keys = keys.copy()
        self.visible_sources = visible_sources.copy()
        self.x_values = x_values.copy()
        self.y_values = y_values.copy()
        self.x_valid = x_valid.copy()
        self.y_valid = y_valid.copy()
        self.x_field = x_field
        self.y_field = y_field
        self.selected = selected.clone()

    def __init__(out self, *, copy: Self):
        self.keys = copy.keys.copy()
        self.visible_sources = copy.visible_sources.copy()
        self.x_values = copy.x_values.copy()
        self.y_values = copy.y_values.copy()
        self.x_valid = copy.x_valid.copy()
        self.y_valid = copy.y_valid.copy()
        self.x_field = copy.x_field
        self.y_field = copy.y_field
        self.selected = copy.selected.clone()

    def build(self, index: Int, key: Int, bounds: Rect) -> ViewNode:
        # The recycler key stays positional. Resolve it to the source-row
        # index for values and widget identity so sorting never reuses a row's
        # control id for a different source row.
        var row_key = -1
        var x: Float32 = 0.0
        var y: Float32 = 0.0
        var x_is_valid = False
        var y_is_valid = False
        var checked = False
        var source = -1
        if key >= 0 and key < len(self.visible_sources):
            source = self.visible_sources[key]
            if source >= 0 and source < len(self.keys):
                row_key = self.keys[source]
                x = self.x_values[source]
                y = self.y_values[source]
                x_is_valid = self.x_valid[source]
                y_is_valid = self.y_valid[source]
            checked = self.selected.contains(row_key)
        var mark = "○"
        if checked:
            mark = "●"
        var x_text = String(x) if x_is_valid else "missing"
        var y_text = String(y) if y_is_valid else "missing"
        var text = String(
            mark, "  row ", row_key, "   ", self.x_field, " = ", x_text,
            "   ", self.y_field, " = ", y_text,
        )
        var node = ButtonControl(
            DATA_WORKBENCH_TABLE_ROW_BASE + source,
            text,
            bounds.height,
        ).node()
        node.semantics.value = String("source row ", source)
        node.style.fill = Color(0.13, 0.24, 0.36, 1.0) if checked else (
            Color(0.10, 0.14, 0.21, 1.0) if index % 2 == 0 else Color(0.12, 0.16, 0.23, 1.0)
        )
        node.style.corner_radius = 2.0
        return node


def _copy_workbench_data(source: WorkbenchData) -> WorkbenchData:
    """Copy the model through its public storage contract for App snapshots."""
    return source.clone()


struct DataWorkbenchState(Component):
    """Stateful data exploration surface backed by ``WorkbenchData``."""

    var data: WorkbenchData
    var x_field: String
    var y_field: String
    var filter_field: String
    var threshold_input: TextInputState
    var import_path_input: TextInputState
    var table_offset: Float32
    var sort_descending: Bool
    var scatter_view: PlotView
    var histogram_view: PlotView
    var selected_csv: String
    var svg_markup: String
    var status: String
    var cached_keys: List[Int]
    var cached_visible_sources: List[Int]
    var cached_x: List[Float32]
    var cached_y: List[Float32]
    var cached_x_valid: List[Bool]
    var cached_y_valid: List[Bool]

    def __init__(out self, *, copy: Self):
        """Copy component state without requiring WorkbenchData to be copyable."""
        self.data = _copy_workbench_data(copy.data)
        self.x_field = copy.x_field
        self.y_field = copy.y_field
        self.filter_field = copy.filter_field
        self.threshold_input = copy.threshold_input
        self.import_path_input = copy.import_path_input
        self.table_offset = copy.table_offset
        self.sort_descending = copy.sort_descending
        self.scatter_view = PlotView(copy=copy.scatter_view)
        self.histogram_view = PlotView(copy=copy.histogram_view)
        self.selected_csv = copy.selected_csv
        self.svg_markup = copy.svg_markup
        self.status = copy.status
        self.cached_keys = copy.cached_keys.copy()
        self.cached_visible_sources = copy.cached_visible_sources.copy()
        self.cached_x = copy.cached_x.copy()
        self.cached_y = copy.cached_y.copy()
        self.cached_x_valid = copy.cached_x_valid.copy()
        self.cached_y_valid = copy.cached_y_valid.copy()

    def __init__(out self, fixture: WorkbenchData):
        """Create a workbench around caller-owned data for tests and hosts."""
        self.data = fixture
        self.x_field = self.data.field_name(0)
        self.y_field = self.data.field_name(1) if self.data.field_count() > 1 else self.x_field
        self.filter_field = self.data.filter_field
        if self.filter_field.count_codepoints() == 0 and self.data.field_count() > 0:
            self.filter_field = self.data.field_name(0)
        self.threshold_input = TextInputState("0.70")
        self.import_path_input = TextInputState()
        self.table_offset = 0.0
        self.sort_descending = False
        self.selected_csv = ""
        self.svg_markup = ""
        self.status = String(
            "Fixture loaded · ",
            self.data.row_count(),
            " rows · choose fields, filter, select, and export",
        )
        self.cached_keys = List[Int]()
        self.cached_visible_sources = List[Int]()
        self.cached_x = List[Float32]()
        self.cached_y = List[Float32]()
        self.cached_x_valid = List[Bool]()
        self.cached_y_valid = List[Bool]()
        self.scatter_view = PlotView(
            PlotSpec("Scatter"), PlotDataTable(), Rect(0.0, 0.0, 1.0, 1.0)
        )
        self.histogram_view = PlotView(
            PlotSpec("Histogram"), PlotDataTable(), Rect(0.0, 0.0, 1.0, 1.0)
        )
        var table = self._plot_table()
        var scatter_spec = self._scatter_spec()
        var histogram_spec = self._histogram_spec()
        self.scatter_view = PlotView(scatter_spec, table, Rect(0.0, 0.0, 1.0, 1.0))
        self.histogram_view = PlotView(histogram_spec, table, Rect(0.0, 0.0, 1.0, 1.0))
        self._fit_histogram_domain()
        self._refresh_cache()

    def __init__(out self):
        self.data = make_workbench_fixture()
        self.x_field = self.data.field_name(0)
        self.y_field = self.data.field_name(1) if self.data.field_count() > 1 else self.x_field
        self.filter_field = self.data.filter_field
        if self.filter_field.count_codepoints() == 0 and self.data.field_count() > 0:
            self.filter_field = self.data.field_name(0)
        self.threshold_input = TextInputState("0.70")
        self.import_path_input = TextInputState()
        self.table_offset = 0.0
        self.sort_descending = False
        self.selected_csv = ""
        self.svg_markup = ""
        self.status = String(
            "Fixture loaded · ",
            self.data.row_count(),
            " rows · choose fields, filter, select, and export",
        )
        self.cached_keys = List[Int]()
        self.cached_visible_sources = List[Int]()
        self.cached_x = List[Float32]()
        self.cached_y = List[Float32]()
        self.cached_x_valid = List[Bool]()
        self.cached_y_valid = List[Bool]()
        self.scatter_view = PlotView(
            PlotSpec("Scatter"), PlotDataTable(), Rect(0.0, 0.0, 1.0, 1.0)
        )
        self.histogram_view = PlotView(
            PlotSpec("Histogram"), PlotDataTable(), Rect(0.0, 0.0, 1.0, 1.0)
        )
        var table = self._plot_table()
        var scatter_spec = self._scatter_spec()
        var histogram_spec = self._histogram_spec()
        self.scatter_view = PlotView(scatter_spec, table, Rect(0.0, 0.0, 1.0, 1.0))
        self.histogram_view = PlotView(histogram_spec, table, Rect(0.0, 0.0, 1.0, 1.0))
        self._fit_histogram_domain()
        self._refresh_cache()

    def _plot_table(self) -> PlotDataTable:
        var table = PlotDataTable()
        # Keep plotting in source order and let the table alone follow sorting.
        # Validate all keys once: imported source keys need not be monotonic.
        var keys = List[Int]()
        var xs = List[Float32]()
        var ys = List[Float32]()
        var xs_valid = List[Bool]()
        var ys_valid = List[Bool]()
        var visible = List[Bool](capacity=self.data.row_count())
        for _ in range(self.data.row_count()):
            visible.append(False)
        for visible_index in range(self.data.visible_count()):
            var visible_source = self.data.visible_source_index_at(visible_index)
            if visible_source >= 0 and visible_source < self.data.row_count():
                visible[visible_source] = True
        for source in range(self.data.row_count()):
            if not visible[source]:
                continue
            var x_valid = self.data.value_is_valid(self.x_field, source)
            var y_valid = self.data.value_is_valid(self.y_field, source)
            keys.append(self.data.key_at(source))
            xs.append(self.data.value_at(self.x_field, source))
            ys.append(self.data.value_at(self.y_field, source))
            xs_valid.append(x_valid)
            ys_valid.append(y_valid)
        _ = table.append_rows(keys, xs, ys, xs_valid, ys_valid)
        return table^

    def _scatter_spec(self) -> PlotSpec:
        var spec = PlotSpec(String("Scatter · ", self.x_field, " × ", self.y_field))
        _ = spec.add_scatter(
            "observations",
            "x",
            "y",
            Color(0.27, 0.67, 0.95, 0.92),
        )
        _ = spec.add_hover(True, True)
        _ = spec.add_brush(False)
        _ = spec.add_click_select(True)
        return spec^

    def _histogram_spec(self) -> PlotSpec:
        var spec = PlotSpec(String("Histogram · ", self.y_field))
        _ = spec.add_histogram(
            "distribution",
            "y",
            18,
            Color(0.36, 0.82, 0.64, 0.86),
        )
        _ = spec.add_hover(False, True)
        _ = spec.add_click_select(True)
        return spec^

    def _histogram_bin_for_value(
        self,
        value: Float32,
        minimum: Float32,
        width: Float32,
    ) -> Int:
        var bin_index = Int(floor((value - minimum) / width))
        if bin_index < 0:
            bin_index = 0
        if bin_index >= DATA_WORKBENCH_HISTOGRAM_BINS:
            bin_index = DATA_WORKBENCH_HISTOGRAM_BINS - 1
        return bin_index

    def _histogram_parameters(self) -> _HistogramParameters:
        var result = _HistogramParameters()
        for visible_index in range(self.data.visible_count()):
            var source = self.data.visible_source_index_at(visible_index)
            if source < 0 or not self.data.value_is_valid(self.y_field, source):
                continue
            var value = self.data.value_at(self.y_field, source)
            if not result.valid:
                result.minimum = value
                result.maximum = value
                result.valid = True
            else:
                if value < result.minimum:
                    result.minimum = value
                if value > result.maximum:
                    result.maximum = value
        if not result.valid:
            return result^
        if result.maximum == result.minimum:
            result.minimum -= 0.5
            result.maximum += 0.5
        result.width = (result.maximum - result.minimum) / Float32(
            DATA_WORKBENCH_HISTOGRAM_BINS
        )
        if result.width <= 0.0:
            result.width = 1.0
        return result^

    def _fit_histogram_domain(mut self):
        """Include the final histogram bin's x2 edge in the x scale.

        ``Plot.fit_to_data`` fits positional x values, while histogram bars
        use ``x2`` for their right edge. The final bar therefore needs an
        application-provided upper bound equal to the computed data maximum.
        """
        var parameters = self._histogram_parameters()
        if not parameters.valid:
            return
        self.histogram_view.runtime.plot.set_x_domain(
            parameters.minimum,
            parameters.maximum,
        )
        var maximum_count: Float32 = 1.0
        if len(self.histogram_view.runtime.plot.series) > 0:
            for index in range(
                len(self.histogram_view.runtime.plot.series[0].points)
            ):
                var count = self.histogram_view.runtime.plot.series[0].points[index].y
                if count > maximum_count:
                    maximum_count = count
        self.histogram_view.runtime.plot.set_y_domain(0.0, maximum_count)

    def _histogram_selection_for_observations(
        self,
        observations: PlotSelection,
    ) -> PlotSelection:
        var result = PlotSelection()
        var parameters = self._histogram_parameters()
        if not parameters.valid:
            return result^
        for visible_index in range(self.data.visible_count()):
            var source = self.data.visible_source_index_at(visible_index)
            if source < 0 or not self.data.value_is_valid(self.y_field, source):
                continue
            var key = self.data.key_at(source)
            if observations.contains(key):
                _ = result.add(
                    self._histogram_bin_for_value(
                        self.data.value_at(self.y_field, source),
                        parameters.minimum,
                        parameters.width,
                    )
                )
        return result^

    def _observations_for_histogram_selection(
        self,
        bins: PlotSelection,
    ) -> PlotSelection:
        var result = PlotSelection()
        var parameters = self._histogram_parameters()
        if not parameters.valid:
            return result^
        for visible_index in range(self.data.visible_count()):
            var source = self.data.visible_source_index_at(visible_index)
            if source < 0 or not self.data.value_is_valid(self.y_field, source):
                continue
            var bin_index = self._histogram_bin_for_value(
                self.data.value_at(self.y_field, source),
                parameters.minimum,
                parameters.width,
            )
            if bins.contains(bin_index):
                _ = result.add(self.data.key_at(source))
        return result^

    def _refresh_cache(mut self):
        self.cached_keys = self.data.keys.copy()
        self.cached_visible_sources = self.data.visible_indices()
        self.cached_x = List[Float32](capacity=self.data.row_count())
        self.cached_y = List[Float32](capacity=self.data.row_count())
        self.cached_x_valid = List[Bool](capacity=self.data.row_count())
        self.cached_y_valid = List[Bool](capacity=self.data.row_count())
        for row in range(self.data.row_count()):
            self.cached_x.append(self.data.value_at(self.x_field, row))
            self.cached_y.append(self.data.value_at(self.y_field, row))
            self.cached_x_valid.append(self.data.value_is_valid(self.x_field, row))
            self.cached_y_valid.append(self.data.value_is_valid(self.y_field, row))

    def _refresh_visuals(mut self):
        self._refresh_cache()
        var table = self._plot_table()
        self.scatter_view.replace_spec(self._scatter_spec(), table)
        self.histogram_view.replace_spec(self._histogram_spec(), table)
        self._fit_histogram_domain()
        var selection = self.data.selected.clone()
        self.scatter_view.runtime.set_linked_selection(selection)
        self.histogram_view.runtime.set_linked_selection(
            self._histogram_selection_for_observations(selection)
        )
        if self.table_offset < 0.0:
            self.table_offset = 0.0

    def _replace_visible_selection(mut self, selection: PlotSelection):
        var previous = self.data.selected.clone()
        self.data.clear_selection()
        # Plot runtimes only contain currently visible marks. Keep selected
        # keys that the active filter hides, then replace the visible part
        # with the plot's linked selection.
        for index in range(len(previous.keys)):
            var key = previous.keys[index]
            var source = self.data.source_index_for_key(key)
            var visible = False
            for visible_index in range(self.data.visible_count()):
                if self.data.visible_source_index_at(visible_index) == source:
                    visible = True
                    break
            if not visible:
                _ = self.data.select_key(key)
        for index in range(len(selection.keys)):
            _ = self.data.select_key(selection.keys[index])
        var linked = self.data.selected.clone()
        self.scatter_view.runtime.set_linked_selection(linked)
        self.histogram_view.runtime.set_linked_selection(
            self._histogram_selection_for_observations(linked)
        )
        self.status = String(
            "Selected ",
            self.data.selected_count(),
            " rows (",
            self.data.hidden_selected_count(),
            " hidden by filter)",
        )

    def _sync_model_selection(mut self):
        self._replace_visible_selection(self.scatter_view.runtime.selection())

    def _target_is_plot(self, event: Event, target: Int, bounds: Rect) -> Bool:
        if not (
            event.kind == CLICK_KIND
            or event.kind == POINTER_DOWN_KIND
            or event.kind == POINTER_MOVE_KIND
            or event.kind == POINTER_UP_KIND
            or event.kind == POINTER_CANCEL_KIND
        ):
            return False
        if event.target == target:
            return True
        return event.target == -1 and bounds.contains(event.position)

    def _toggle_source_row(mut self, source: Int) -> Bool:
        if source < 0 or source >= self.data.row_count():
            return False
        var key = self.data.key_at(source)
        var selected = self.data.toggle_selected_key(key)
        var selection = self.data.selected.clone()
        self.scatter_view.runtime.set_linked_selection(selection)
        self.histogram_view.runtime.set_linked_selection(
            self._histogram_selection_for_observations(selection)
        )
        self.status = String(
            "Selected " if selected else "Deselected ",
            self.data.selected_count(),
            " rows (",
            self.data.hidden_selected_count(),
            " hidden by filter)",
        )
        return True

    def _selection_equal(self, left: PlotSelection, right: PlotSelection) -> Bool:
        if left.count() != right.count():
            return False
        for index in range(left.count()):
            if left.key_at(index) != right.key_at(index):
                return False
        return True

    def _handle_text_input(mut self, event: Event, input_id: Int) -> Bool:
        if event.target != input_id:
            return False
        var input = self.threshold_input
        if input_id == DATA_WORKBENCH_IMPORT_PATH_ID:
            input = self.import_path_input
        if event.kind == COMPOSITION_UPDATE_KIND:
            input.set_composition(event.text, event.selection_start, event.selection_end)
            if input_id == DATA_WORKBENCH_IMPORT_PATH_ID:
                self.import_path_input = input
            else:
                self.threshold_input = input
            return True
        if event.kind == COMPOSITION_END_KIND:
            if not input.has_composition():
                return False
            input.clear_composition()
        elif event.kind == TEXT_INPUT_KIND:
            var changed = (
                input.replace_text_range(
                    event.text,
                    event.replacement_start,
                    event.replacement_end,
                )
                if event.replacement_start >= 0 and event.replacement_end >= 0
                else input.insert_text(event.text)
            )
            if input_id == DATA_WORKBENCH_IMPORT_PATH_ID:
                self.import_path_input = input
            else:
                self.threshold_input = input
            return changed
        elif event.kind == KEY_DOWN_KIND:
            var changed = input.handle_key(event.key, event.modifiers)
            if input_id == DATA_WORKBENCH_IMPORT_PATH_ID:
                self.import_path_input = input
            else:
                self.threshold_input = input
            if input_id == DATA_WORKBENCH_THRESHOLD_ID and changed:
                return self._apply_threshold()
            return changed
        else:
            return False
        if input_id == DATA_WORKBENCH_IMPORT_PATH_ID:
            self.import_path_input = input
        else:
            self.threshold_input = input
        return True

    def _apply_threshold(mut self) -> Bool:
        var parsed = _parse_threshold(self.threshold_input.text)
        if not parsed.valid:
            self.status = String("Filter error: threshold must be numeric")
            return True
        var threshold = parsed.value
        if not self.data.set_filter(self.filter_field, threshold):
            self.status = String("Filter error: unknown field ", self.filter_field)
            return True
        self.table_offset = 0.0
        self._refresh_visuals()
        self.status = String(
            "Filter ",
            self.filter_field,
            " > ",
            threshold,
            " · ",
            self.data.visible_count(),
            " visible · ",
            self.data.hidden_selected_count(),
            " selected hidden",
        )
        return True

    def _cycle_x_field(mut self):
        var index = self.data.field_index(self.x_field)
        if index < 0:
            index = 0
        index = (index + 1) % self.data.field_count()
        self.x_field = self.data.field_name(index)
        if self.x_field == self.y_field and self.data.field_count() > 1:
            index = (index + 1) % self.data.field_count()
            self.x_field = self.data.field_name(index)
        self._refresh_visuals()
        self.status = String("X field: ", self.x_field)

    def _cycle_y_field(mut self):
        var index = self.data.field_index(self.y_field)
        if index < 0:
            index = 0
        index = (index + 1) % self.data.field_count()
        self.y_field = self.data.field_name(index)
        if self.x_field == self.y_field and self.data.field_count() > 1:
            index = (index + 1) % self.data.field_count()
            self.y_field = self.data.field_name(index)
        self._refresh_visuals()
        self.status = String("Y field: ", self.y_field)

    def _cycle_filter_field(mut self) -> Bool:
        var index = self.data.field_index(self.filter_field)
        if index < 0:
            index = 0
        index = (index + 1) % self.data.field_count()
        self.filter_field = self.data.field_name(index)
        if self.data.filter_is_active():
            return self._apply_threshold()
        self.status = String("Filter field: ", self.filter_field)
        return True

    def _export_svg(mut self, bounds: Rect):
        self.svg_markup = ""
        var safe_width = Int(bounds.width) if bounds.width > 1.0 else 1
        var safe_height = Int(bounds.height) if bounds.height > 1.0 else 1
        var renderer = SvgSceneRenderer(safe_width, safe_height)
        try:
            # SVG consumers expect a local origin even when the native canvas
            # is laid out below toolbars or beside the histogram.
            var local_bounds = Rect(0.0, 0.0, bounds.width, bounds.height)
            self.scatter_view.set_bounds(local_bounds)
            renderer.render_scene(self.scatter_view.build_scene())
            self.svg_markup = renderer.markup()
            self.scatter_view.set_bounds(bounds)
            self.status = String(
                "SVG ready · ",
                self.svg_markup.count_codepoints(),
                " characters",
            )
        except e:
            self.scatter_view.set_bounds(bounds)
            self.status = String("SVG export error: ", e)

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 14.0, 8.0)
        root.set_clip_to_bounds(True)
        root.add_label(
            DATA_WORKBENCH_TITLE_ID,
            "Moxi Data Workbench",
            34.0,
        )
        root.add_label(DATA_WORKBENCH_STATUS_ID, self.status, 28.0)

        var fields = root.add_row(210, 0.0, 42.0, 4.0, 6.0)
        root.add_label_to(fields, DATA_WORKBENCH_X_LABEL_ID, "X", 36.0)
        root.add_button_to(fields, DATA_WORKBENCH_X_FIELD_ID, String(self.x_field), 36.0)
        root.add_label_to(fields, DATA_WORKBENCH_Y_LABEL_ID, "Y", 36.0)
        root.add_button_to(fields, DATA_WORKBENCH_Y_FIELD_ID, String(self.y_field), 36.0)
        root.add_label_to(fields, DATA_WORKBENCH_FILTER_LABEL_ID, "Filter", 36.0)
        root.add_button_to(fields, DATA_WORKBENCH_FILTER_FIELD_ID, String(self.filter_field), 36.0)
        var threshold = TextInputControl(
            DATA_WORKBENCH_THRESHOLD_ID,
            self.threshold_input.text,
            self.threshold_input.cursor,
            self.threshold_input.anchor,
            36.0,
        )
        threshold.set_composition(
            self.threshold_input.composition,
            self.threshold_input.composition_selection_start,
            self.threshold_input.composition_selection_end,
        )
        root.add_to(fields, threshold.node())
        root.add_button_to(fields, DATA_WORKBENCH_CLEAR_FILTER_ID, "Clear", 36.0)
        root.set_fixed_width(DATA_WORKBENCH_X_LABEL_ID, 24.0)
        root.set_fixed_width(DATA_WORKBENCH_Y_LABEL_ID, 24.0)
        root.set_fixed_width(DATA_WORKBENCH_FILTER_LABEL_ID, 54.0)
        root.set_fixed_width(DATA_WORKBENCH_THRESHOLD_ID, 140.0)
        root.set_fixed_width(DATA_WORKBENCH_CLEAR_FILTER_ID, 80.0)
        root.set_accessibility_label(DATA_WORKBENCH_THRESHOLD_ID, "Filter threshold, keep values greater than")

        var actions = root.add_row(220, 0.0, 42.0, 4.0, 6.0)
        root.add_label_to(actions, DATA_WORKBENCH_CSV_LABEL_ID, "CSV", 36.0)
        var import_path = TextInputControl(
            DATA_WORKBENCH_IMPORT_PATH_ID,
            self.import_path_input.text,
            self.import_path_input.cursor,
            self.import_path_input.anchor,
            36.0,
        )
        import_path.set_composition(
            self.import_path_input.composition,
            self.import_path_input.composition_selection_start,
            self.import_path_input.composition_selection_end,
        )
        root.add_to(actions, import_path.node())
        root.add_button_to(actions, DATA_WORKBENCH_IMPORT_ID, "Import path", 36.0)
        root.add_button_to(actions, DATA_WORKBENCH_SORT_ID, "Sort Y", 36.0)
        root.add_button_to(actions, DATA_WORKBENCH_EXPORT_CSV_ID, "Export selected CSV", 36.0)
        root.add_button_to(actions, DATA_WORKBENCH_EXPORT_SVG_ID, "Export scatter SVG", 36.0)
        root.set_fixed_width(DATA_WORKBENCH_CSV_LABEL_ID, 54.0)
        root.set_fixed_width(DATA_WORKBENCH_IMPORT_ID, 96.0)
        root.set_fixed_width(DATA_WORKBENCH_SORT_ID, 80.0)
        root.set_fixed_width(DATA_WORKBENCH_EXPORT_CSV_ID, 170.0)
        root.set_fixed_width(DATA_WORKBENCH_EXPORT_SVG_ID, 170.0)
        root.set_accessibility_label(DATA_WORKBENCH_IMPORT_PATH_ID, "Local CSV file path")

        var plot_height: Float32 = 252.0
        var plot_row = root.add_row(DATA_WORKBENCH_PLOT_ROW_ID, 0.0, plot_height, 0.0, 8.0)
        root.add_canvas_to(plot_row, DATA_WORKBENCH_SCATTER_CANVAS_ID, "Scatter plot", plot_height)
        root.add_canvas_to(plot_row, DATA_WORKBENCH_HISTOGRAM_CANVAS_ID, "Histogram", plot_height)
        root.set_min_width(DATA_WORKBENCH_SCATTER_CANVAS_ID, 260.0)
        root.set_min_width(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID, 260.0)
        var canvas_width = (bounds.width - 36.0) / 2.0
        root.set_preferred_width(DATA_WORKBENCH_SCATTER_CANVAS_ID, canvas_width)
        root.set_preferred_width(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID, canvas_width)

        root.add_label(
            DATA_WORKBENCH_TABLE_HEADER_ID,
            String(
                "Rows · ",
                self.data.visible_count(),
                " visible / ",
                self.data.row_count(),
                " total · ",
                self.data.selected_count(),
                " selected · ",
                self.data.hidden_selected_count(),
                " hidden",
            ),
            28.0,
        )

        var table_height: Float32 = bounds.height - 470.0
        if table_height < 150.0:
            table_height = 150.0
        var table_builder = WorkbenchRowBuilder(
            self.cached_keys.copy(),
            self.cached_visible_sources.copy(),
            self.cached_x.copy(),
            self.cached_y.copy(),
            self.cached_x_valid.copy(),
            self.cached_y_valid.copy(),
            self.x_field,
            self.y_field,
            self.data.selected.clone(),
        )
        var virtual = VirtualizedList(
            table_builder,
            self.data.visible_count(),
            DATA_WORKBENCH_TABLE_ROW_HEIGHT,
            2,
        )
        virtual.set_offset(self.table_offset)
        var table = virtual.build(Rect(bounds.x, bounds.y, bounds.width, table_height))
        _ = root.add_portal(DATA_WORKBENCH_TABLE_PORTAL_ID, table_height, 0.0, 0.0, 0.0)
        root.add_component_view_to(
            DATA_WORKBENCH_TABLE_PORTAL_ID,
            DATA_WORKBENCH_TABLE_SLOT_ID,
            table,
            0,
            table_height,
        )
        root.set_accessibility_label(DATA_WORKBENCH_TABLE_PORTAL_ID, "Virtualized data table")
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if self._handle_text_input(event, DATA_WORKBENCH_THRESHOLD_ID):
            if event.kind == TEXT_INPUT_KIND:
                return self._apply_threshold()
            return True
        if self._handle_text_input(event, DATA_WORKBENCH_IMPORT_PATH_ID):
            return True

        if event.target >= DATA_WORKBENCH_TABLE_ROW_BASE and (
            event.kind == CLICK_KIND
            or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS)
            or (
                event.kind == KEY_DOWN_KIND
                and (event.key == KEY_ENTER or event.key == KEY_SPACE)
            )
        ):
            return self._toggle_source_row(event.target - DATA_WORKBENCH_TABLE_ROW_BASE)

        if self._target_is_plot(
            event,
            DATA_WORKBENCH_SCATTER_CANVAS_ID,
            view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID),
        ):
            self.scatter_view.set_bounds(view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID))
            var before_selection = self.scatter_view.runtime.selection()
            var changed = self.scatter_view.runtime.dispatch(event)
            var after_selection = self.scatter_view.runtime.selection()
            if changed and not self._selection_equal(before_selection, after_selection):
                self._sync_model_selection()
            return changed
        if self._target_is_plot(
            event,
            DATA_WORKBENCH_HISTOGRAM_CANVAS_ID,
            view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID),
        ):
            self.histogram_view.set_bounds(view.bounds_for(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID))
            var before_bins = self.histogram_view.runtime.selection()
            var changed = self.histogram_view.runtime.dispatch(event)
            var after_bins = self.histogram_view.runtime.selection()
            if changed and not self._selection_equal(before_bins, after_bins):
                self._replace_visible_selection(
                    self._observations_for_histogram_selection(after_bins)
                )
            return changed

        if event.kind == SCROLL_KIND and (
            event.target == DATA_WORKBENCH_TABLE_PORTAL_ID
            or view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID).contains(event.position)
        ):
            self.table_offset += event.scroll_delta.y
            if self.table_offset < 0.0:
                self.table_offset = 0.0
            var max_offset = Float32(self.data.visible_count()) * DATA_WORKBENCH_TABLE_ROW_HEIGHT - view.bounds_for(DATA_WORKBENCH_TABLE_PORTAL_ID).height
            if max_offset < 0.0:
                max_offset = 0.0
            if self.table_offset > max_offset:
                self.table_offset = max_offset
            self.status = String("Table offset ", self.table_offset)
            return True

        var activated = event.kind == CLICK_KIND or (
            event.kind == KEY_DOWN_KIND
            and (event.key == KEY_ENTER or event.key == KEY_SPACE)
        ) or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS)
        if not activated:
            return False
        if event.target == DATA_WORKBENCH_X_FIELD_ID:
            self._cycle_x_field()
            return True
        if event.target == DATA_WORKBENCH_Y_FIELD_ID:
            self._cycle_y_field()
            return True
        if event.target == DATA_WORKBENCH_FILTER_FIELD_ID:
            return self._cycle_filter_field()
        if event.target == DATA_WORKBENCH_CLEAR_FILTER_ID:
            self.data.clear_filter()
            self.table_offset = 0.0
            self._refresh_visuals()
            self.status = "Filter cleared"
            return True
        if event.target == DATA_WORKBENCH_IMPORT_ID:
            if self.import_path_input.text.count_codepoints() == 0:
                self.status = "Import error: enter a local CSV path"
            else:
                try:
                    _ = self.load_csv_text(read_workbench_csv(self.import_path_input.text))
                except e:
                    self.status = String("Import error: ", e)
            return True
        if event.target == DATA_WORKBENCH_SORT_ID:
            self.sort_descending = not self.sort_descending
            if not self.data.sort_visible(self.y_field, self.sort_descending):
                self.status = String("Sort error: unknown field ", self.y_field)
            else:
                self.table_offset = 0.0
                self._refresh_visuals()
                self.status = String(
                    "Sorted ",
                    self.y_field,
                    " descending" if self.sort_descending else " ascending",
                )
            return True
        if event.target == DATA_WORKBENCH_EXPORT_CSV_ID:
            self.selected_csv = self.data.export_selected_csv()
            var path = "/tmp/moxi-workbench-selected.csv"
            if self.import_path_input.text.count_codepoints() > 0:
                path = String(self.import_path_input.text, ".selected.csv")
            try:
                write_workbench_export(path, self.selected_csv)
                self.status = String("Saved ", self.data.selected_count(), " selected rows to ", path)
            except e:
                self.status = String("CSV export error: ", e)
            return True
        if event.target == DATA_WORKBENCH_EXPORT_SVG_ID:
            self._export_svg(view.bounds_for(DATA_WORKBENCH_SCATTER_CANVAS_ID))
            if self.svg_markup.count_codepoints() > 0:
                var path = "/tmp/moxi-workbench-scatter.svg"
                if self.import_path_input.text.count_codepoints() > 0:
                    path = String(self.import_path_input.text, ".scatter.svg")
                try:
                    write_workbench_export(path, self.svg_markup)
                    self.status = String("Saved scatter SVG to ", path)
                except e:
                    self.status = String("SVG export error: ", e)
            return True
        return False

    def update_retained(mut self, event: Event, view: ColumnView) -> Bool:
        # The plot runtimes and table offset are retained in component state;
        # update() owns event routing so App.dispatch tests exercise one path.
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if target == DATA_WORKBENCH_THRESHOLD_ID:
            var copied = self.threshold_input.selected_text()
            self.threshold_input.clipboard = copied
            return copied
        if target == DATA_WORKBENCH_IMPORT_PATH_ID:
            var copied = self.import_path_input.selected_text()
            self.import_path_input.clipboard = copied
            return copied
        if target >= DATA_WORKBENCH_TABLE_ROW_BASE:
            var source = target - DATA_WORKBENCH_TABLE_ROW_BASE
            if source >= 0 and source < self.data.row_count():
                var copied = String("missing")
                if self.data.value_is_valid(self.y_field, source):
                    copied = String(self.data.value_at(self.y_field, source))
                return copied
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == DATA_WORKBENCH_THRESHOLD_ID and self.threshold_input.has_selection():
            _ = self.threshold_input.cut_selection()
            return self.threshold_input.clipboard
        if target == DATA_WORKBENCH_IMPORT_PATH_ID and self.import_path_input.has_selection():
            _ = self.import_path_input.cut_selection()
            return self.import_path_input.clipboard
        return ""

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        if text.count_codepoints() == 0:
            return False
        if target == DATA_WORKBENCH_THRESHOLD_ID:
            self.threshold_input.clipboard = text
            if not self.threshold_input.insert_text(text):
                return False
            _ = self._apply_threshold()
            return True
        if target == DATA_WORKBENCH_IMPORT_PATH_ID:
            self.import_path_input.clipboard = text
            return self.import_path_input.insert_text(text)
        return False

    def load_csv_text(mut self, contents: String) -> CsvLoadResult:
        var result = self.data.load_csv_text(contents)
        if result.accepted:
            self.x_field = self.data.field_name(0)
            self.y_field = self.data.field_name(1) if self.data.field_count() > 1 else self.x_field
            self.filter_field = self.data.field_name(0)
            self.threshold_input = TextInputState("0.0")
            self.table_offset = 0.0
            self._refresh_visuals()
            self.status = String(
                "Loaded CSV · ",
                result.rows,
                " rows · ",
                result.columns,
                " numeric fields",
            )
        else:
            self.status = String("Import error: ", result.message)
        return result

    def visible_row_count(self) -> Int:
        return self.data.visible_count()

    def total_row_count(self) -> Int:
        return self.data.row_count()

    def selected_row_count(self) -> Int:
        return self.data.selected_count()

    def hidden_selected_row_count(self) -> Int:
        return self.data.hidden_selected_count()

    def table_scroll_offset(self) -> Float32:
        return self.table_offset

    def selected_csv_text(self) -> String:
        return self.selected_csv

    def svg_text(self) -> String:
        return self.svg_markup

    def status_text(self) -> String:
        return self.status

    def scatter_scene(mut self, bounds: Rect) -> Scene:
        self.scatter_view.set_bounds(bounds)
        return self.scatter_view.build_scene()

    def histogram_scene(mut self, bounds: Rect) -> Scene:
        self.histogram_view.set_bounds(bounds)
        return self.histogram_view.build_scene()

    def combined_scene(mut self, scatter_bounds: Rect, histogram_bounds: Rect) -> Scene:
        """Return both plot scenes in one clipped render pass.

        The native canvas renderer clears its custom command buffer at the
        beginning of each render pass, so hosts should use this method when
        presenting both linked plots in one frame.
        """
        var result = Scene()
        var scatter = self.scatter_scene(scatter_bounds)
        result.push_clip(DATA_WORKBENCH_SCATTER_CANVAS_ID, scatter_bounds)
        for index in range(len(scatter.commands)):
            result.append(scatter.commands[index])
        result.pop_clip(DATA_WORKBENCH_SCATTER_CANVAS_ID)
        var histogram = self.histogram_scene(histogram_bounds)
        result.push_clip(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID, histogram_bounds)
        for index in range(len(histogram.commands)):
            result.append(histogram.commands[index])
        result.pop_clip(DATA_WORKBENCH_HISTOGRAM_CANVAS_ID)
        return result^

    def scene(mut self, bounds: Rect) -> Scene:
        return self.scatter_scene(bounds)
