"""An actual Moxi component: investigation workbench and its fixed saved panel."""
from std.math import round
from moxi import ColumnView, Component, Event, Rect, Color, Scene, TextInputControl, TextInputState
from moxi.event import TEXT_INPUT_KIND, KEY_DOWN_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, KEY_F2
from moxi.scene import SCENE_TEXT
from moxi_plot import PlotSpec, PlotDataTable, PlotView
from cohort import THRESHOLD
from model import Investigation, Fit, ModelKind, MembershipMode, FixtureState
from panel import save_panel, load_panel

comptime NAME_ID = 10
comptime HYPOTHESIS_ID = 11
comptime PATH_ID = 12
comptime C0_ID = 13
comptime C1_ID = 14
comptime C2_ID = 15
comptime COLLECT_ID = 20
comptime MODE_ID = 21
comptime FILTER_ID = 22
comptime SORT_ID = 23
comptime FIXTURE_BUTTON_ID = 24
comptime MEAN_ID = 25
comptime LINEAR_ID = 26
comptime QUADRATIC_ID = 27
comptime APPLY_ID = 28
comptime REFIT_ID = 29
comptime COMPARE_ID = 30
comptime SAVE_ID = 31
comptime REOPEN_ID = 32
comptime INTERNALS_ID = 33
comptime FIT_CANVAS_ID = 40
comptime RESIDUAL_CANVAS_ID = 41


def number(value: Float64) -> String:
    var rounded = round(value * 1000) / 1000
    if abs(rounded) < 0.0005:
        rounded = 0
    return String(rounded)


struct InvestigationScreen(Component):
    var model: Investigation
    var name_input: TextInputState
    var hypothesis_input: TextInputState
    var path_input: TextInputState
    var c0_input: TextInputState
    var c1_input: TextInputState
    var c2_input: TextInputState
    var high_only: Bool
    var descending: Bool
    var compared: Bool
    var panel_open: Bool
    var status: String

    def __init__(out self):
        self.model = Investigation()
        self.name_input = TextInputState(self.model.name)
        self.hypothesis_input = TextInputState(self.model.hypothesis)
        self.path_input = TextInputState("panel.json")
        self.c0_input = TextInputState("0")
        self.c1_input = TextInputState("0")
        self.c2_input = TextInputState("0")
        self.high_only = False
        self.descending = False
        self.compared = False
        self.panel_open = False
        self.status = "Name a cohort, then collect readings >= 70 (button or F2)."

    def sync_coefficients(mut self):
        self.c0_input = TextInputState(String(self.model.fit.c0))
        self.c1_input = TextInputState(String(self.model.fit.c1))
        self.c2_input = TextInputState(String(self.model.fit.c2))

    def edit(mut self, event: Event) -> Bool:
        var input = self.name_input
        if event.target == HYPOTHESIS_ID:
            input = self.hypothesis_input
        elif event.target == PATH_ID:
            input = self.path_input
        elif event.target == C0_ID:
            input = self.c0_input
        elif event.target == C1_ID:
            input = self.c1_input
        elif event.target == C2_ID:
            input = self.c2_input
        elif event.target != NAME_ID:
            return False
        var changed = False
        if event.kind == COMPOSITION_UPDATE_KIND:
            input.set_composition(event.text, event.selection_start, event.selection_end)
            changed = True
        elif event.kind == COMPOSITION_END_KIND:
            input.clear_composition()
            changed = True
        elif event.kind == TEXT_INPUT_KIND:
            changed = input.replace_text_range(event.text, event.replacement_start, event.replacement_end) if event.replacement_start >= 0 else input.insert_text(event.text)
        elif event.kind == KEY_DOWN_KIND:
            changed = input.handle_key(event.key, event.modifiers)
        if event.target == NAME_ID:
            self.name_input = input
            self.model.name = input.text
        elif event.target == HYPOTHESIS_ID:
            self.hypothesis_input = input
            self.model.hypothesis = input.text
        elif event.target == PATH_ID:
            self.path_input = input
        elif event.target == C0_ID:
            self.c0_input = input
        elif event.target == C1_ID:
            self.c1_input = input
        elif event.target == C2_ID:
            self.c2_input = input
        if changed:
            self.status = "Edits are unsaved. Apply coefficient fields before saving."
        return changed

    def act(mut self, id: Int) raises:
        if id == COLLECT_ID and not self.panel_open:
            self.model.collect()
            self.compared = False
            self.status = "Named cohort collected through I20; fit a model next."
        elif id == MODE_ID and not self.panel_open:
            self.model.set_mode(MembershipMode.LIVE if self.model.mode == MembershipMode.FROZEN else MembershipMode.FROZEN)
            self.compared = False
            self.status = "Membership mode changed; fit again before saving."
        elif id == FILTER_ID:
            self.high_only = not self.high_only
            self.status = "Table filter changed. Cohort IDs and fitted data are unchanged."
        elif id == SORT_ID:
            self.descending = not self.descending
            self.status = "Table order changed. Membership follows stable observation IDs."
        elif id == FIXTURE_BUTTON_ID and not self.panel_open:
            self.model.set_fixture(FixtureState.CROSSING if self.model.fixture == FixtureState.BASELINE else FixtureState.BASELINE)
            self.compared = False
            self.status = "Reading 207 crossed the rule. Live membership refreshes; frozen IDs stay. Fit again."
        elif (id == MEAN_ID or id == LINEAR_ID or id == QUADRATIC_ID) and not self.panel_open:
            var kind = ModelKind.MEAN if id == MEAN_ID else (ModelKind.LINEAR if id == LINEAR_ID else ModelKind.QUADRATIC)
            self.model.fit_model(kind)
            self.sync_coefficients()
            self.status = "Least-squares fit applied to the named cohort. Residual = observed - predicted."
        elif id == REFIT_ID:
            var kind = self.model.fit.kind
            self.model.fit_model(kind)
            self.sync_coefficients()
            self.status = "Refitted the panel's model against its intended cohort and sensor target. Unsaved."
        elif id == APPLY_ID:
            if not self.model.fitted:
                raise Error("Fit a model before editing coefficients")
            var fitted = Fit(self.model.fit.kind, Float64(self.c0_input.text), Float64(self.c1_input.text), Float64(self.c2_input.text))
            fitted.validate()
            self.model.fit = fitted
            self.status = "Edited coefficients applied. Residuals and error recomputed; panel is unsaved."
        elif id == COMPARE_ID:
            if not self.model.fitted:
                raise Error("Fit a model before comparing alternatives")
            self.compared = True
            self.status = "Alternatives use identical cohort IDs. Training error is not scientific explanation."
        elif id == SAVE_ID:
            # Pending coefficient edits must never appear saved when they were ignored.
            if self.model.fitted and (Float64(self.c0_input.text) != self.model.fit.c0 or Float64(self.c1_input.text) != self.model.fit.c1 or Float64(self.c2_input.text) != self.model.fit.c2):
                raise Error("Apply coefficient edits before saving")
            if self.path_input.text.strip().count_codepoints() == 0:
                raise Error("Enter a local panel path")
            save_panel(self.path_input.text, self.model)
            self.panel_open = True
            self.status = "Saved fixed panel: named cohort, stable target, model, coefficients and two supported controls."
        elif id == REOPEN_ID:
            # Parse and validate a temporary value before replacing the current investigation.
            var reopened = load_panel(self.path_input.text)
            self.model = reopened^
            self.name_input = TextInputState(self.model.name)
            self.hypothesis_input = TextInputState(self.model.hypothesis)
            self.sync_coefficients()
            self.panel_open = True
            self.compared = True
            self.status = "Reopened fixed panel from disk. Refit and coefficient controls target this cohort."
        elif id == INTERNALS_ID:
            self.panel_open = False
            self.status = "Investigation internals: cohort, provenance, alternatives and panel controls."

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == KEY_DOWN_KIND and event.key == KEY_F2 and not self.panel_open:
            try:
                self.act(COLLECT_ID)
            except e:
                self.status = String("Cannot apply: ", e)
            return True
        if self.edit(event):
            return True
        if not event.is_activation():
            return False
        try:
            self.act(event.target)
        except e:
            self.status = String("Cannot apply: ", e)
        return True

    def input(self, mut view: ColumnView, parent: Int, id: Int, state: TextInputState):
        var control = TextInputControl(id, state.text, state.cursor, state.anchor, 32)
        control.set_composition(state.composition, state.composition_selection_start, state.composition_selection_end)
        view.add_to(parent, control.node())

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 18, 6)
        view.set_panel(0, Rect(8, 8, bounds.width - 16, bounds.height - 16))
        view.add_label(1, "Investigation tools  /  " + ("Saved fixed panel" if self.panel_open else "Sensor workbench"), 32)
        view.add_label(2, "I10  ·  Synthetic observations → named cohort → fit & residuals → alternatives → reusable panel", 24)
        var file_row = view.add_row(100, 0, 34, 0, 8)
        self.input(view, file_row, PATH_ID, self.path_input)
        view.add_button_to(file_row, REOPEN_ID, "Reopen panel", 34)
        view.add_button_to(file_row, SAVE_ID, "Save fixed panel", 34)
        var body = view.add_row(101, 0, bounds.height - 220, 0, 16)
        var left = view.add_column_to(body, 102, 0, 0, 4)
        var right = view.add_column_to(body, 103, 0, 0, 5)
        view.add_label_to(left, 3, "1  /  Cohort & provenance", 28)
        if not self.panel_open:
            view.add_label_to(left, 4, "Cohort name", 20)
            self.input(view, left, NAME_ID, self.name_input)
            view.add_label_to(left, 5, "Hypothesis (a claim to investigate)", 20)
            self.input(view, left, HYPOTHESIS_ID, self.hypothesis_input)
            var cohort_row = view.add_row_to(left, 104, 0, 36, 0, 8)
            view.add_button_to(cohort_row, COLLECT_ID, "Collect >= 70  (F2)", 36)
            view.add_button_to(cohort_row, MODE_ID, "Mode: " + self.model.mode.value, 36)
        else:
            view.add_label_to(left, 4, self.model.name + "  /  " + self.model.mode.value, 30)
            view.add_label_to(left, 5, self.model.hypothesis, 44)
            view.add_label_to(left, 6, "Source: sensor-curve-v1 / " + self.model.fixture.value, 24)
            view.add_label_to(left, 7, "Target: reading by stable observation ID; x = sample index", 28)
            view.add_button_to(left, INTERNALS_ID, "Open investigation internals", 34)
        view.add_label_to(left, 8, "Members " + self.model.ids(), 26)
        view.add_label_to(left, 9, "Rule: reading >= 70. Frozen IDs survive later changes.", 24)
        var table_row = view.add_row_to(left, 105, 0, 34, 0, 8)
        view.add_button_to(table_row, FILTER_ID, "Table: " + (">= 70" if self.high_only else "all rows"), 34)
        view.add_button_to(table_row, SORT_ID, "Order: " + ("descending" if self.descending else "ascending"), 34)
        if not self.panel_open:
            view.add_button_to(left, FIXTURE_BUTTON_ID, "Toggle reading 207: 58 ↔ 76 (threshold crossing)", 34)
        view.add_label_to(left, 50, "ID     x     reading     cohort     residual", 24)
        for index in range(len(self.model.notebook.rows)):
            var i = len(self.model.notebook.rows)-1-index if self.descending else index
            var row = self.model.notebook.rows[i]
            if self.high_only and row.reading < THRESHOLD:
                continue
            var residual = number(self.model.residual(i, self.model.fit)) if self.model.fitted and self.model.contains(row.id) else String("—")
            view.add_label_to(left, 200+i, String(row.id, "     ", i, "     ", row.reading, "     ", "●" if self.model.contains(row.id) else "—", "     ", residual), 24)
        view.add_label_to(right, 51, "2  /  Explicit model & residuals", 28)
        if not self.panel_open:
            var models = view.add_row_to(right, 106, 0, 34, 0, 6)
            view.add_button_to(models, MEAN_ID, "Fit mean", 34)
            view.add_button_to(models, LINEAR_ID, "Fit linear", 34)
            view.add_button_to(models, QUADRATIC_ID, "Fit quadratic", 34)
        view.add_label_to(right, 52, String("y ≈ ", number(self.model.fit.c0), " + (", number(self.model.fit.c1), ")x + (", number(self.model.fit.c2), ")x²") if self.model.fitted else String("y = c0 + c1·x + c2·x²   /   fields: c0, c1, c2"), 24)
        var coefficients = view.add_row_to(right, 107, 0, 32, 0, 6)
        self.input(view, coefficients, C0_ID, self.c0_input)
        self.input(view, coefficients, C1_ID, self.c1_input)
        self.input(view, coefficients, C2_ID, self.c2_input)
        var operations = view.add_row_to(right, 108, 0, 34, 0, 6)
        view.add_button_to(operations, APPLY_ID, "Apply coefficients", 34)
        view.add_button_to(operations, REFIT_ID, "Refit " + self.model.fit.kind.value, 34)
        view.add_label_to(right, 53, String(self.model.fit.kind.value, " / n=", len(self.model.members), " / SSE=", number(self.model.sse(self.model.fit)), " / RMSE=", number(self.model.rmse(self.model.fit))) if self.model.fitted else String("No current fit. Collect a cohort, then choose a model."), 26)
        var show_alternatives = self.compared and not self.panel_open
        var plot_reduction = max(Float32(0), (860 - bounds.height) / 2) + Float32(10 if show_alternatives else 0)
        view.add_canvas_to(right, FIT_CANVAS_ID, "Observed readings & model (sample index, reading)", max(Float32(100), Float32(210 if self.panel_open else 170) - plot_reduction))
        view.add_canvas_to(right, RESIDUAL_CANVAS_ID, "Residual = observed - predicted (sample index, reading)", max(Float32(80), Float32(190 if self.panel_open else 150) - plot_reduction))
        if not self.panel_open:
            view.add_button_to(right, COMPARE_ID, "3  /  Compare alternatives on this cohort", 34)
        if show_alternatives and self.model.fitted:
            for kind in [ModelKind.MEAN, ModelKind.LINEAR, ModelKind.QUADRATIC]:
                try:
                    var alternative = self.model.least_squares(kind)
                    view.add_label_to(right, 300+kind.parameter_count(), String(kind.value, "  /  ", kind.parameter_count(), " parameters  /  training SSE ", number(self.model.sse(alternative))), 22)
                except:
                    view.add_label_to(right, 300+kind.parameter_count(), kind.value + " / insufficient observations", 22)
        view.add_label(54, self.status, 40)
        view.add_label(55, "Synthetic demonstration. Training fit and residuals do not establish causation or generalization.", 22)
        view.layout()
        return view^

    def plot_scene(self, bounds: Rect, residuals: Bool) -> Scene:
        var table = PlotDataTable()
        _ = table.add_float_column("predicted")
        _ = table.add_float_column("zero")
        for i in range(len(self.model.notebook.rows)):
            var row = self.model.notebook.rows[i]
            if not self.model.contains(row.id):
                continue
            var y = self.model.residual(i, self.model.fit) if residuals else Float64(row.reading)
            _ = table.append_with_key(row.id, Float32(i), Float32(y))
            var index = table.row_count()-1
            _ = table.set_float_field("predicted", index, Float32(self.model.fit.predict(Float64(i))))
            _ = table.set_float_field("zero", index, 0)
        var spec = PlotSpec("Residuals / observed - predicted" if residuals else "Readings (blue) / model (green)")
        _ = spec.add_scatter("residual" if residuals else "observed", "x", "y", Color(0.30, 0.65, 0.96, 1))
        _ = spec.add_line("zero" if residuals else "model", "x", "zero" if residuals else "predicted", Color(0.28, 0.82, 0.58, 1))
        var plot = PlotView(spec, table, bounds)
        if residuals:
            var extent: Float32 = 1
            for i in range(len(self.model.notebook.rows)):
                if self.model.contains(self.model.notebook.rows[i].id):
                    extent = max(extent, Float32(abs(self.model.residual(i, self.model.fit))) * 1.2)
            plot.runtime.plot.set_y_domain(-extent, extent)
        var full_scene = plot.build_scene()
        var scene = Scene()
        var area = plot.runtime.plot.plot_area
        # The portable plot emits six y labels even in a short canvas. Compose
        # its public scene with fewer gutter labels, retaining both endpoints.
        # Marks, tick/grid lines, domains and data remain the original plot.
        var last_label_y = area.y + area.height + 100
        for command in full_scene.commands:
            if command.kind == SCENE_TEXT and command.bounds.x < area.x and command.bounds.y >= area.y - 8 and command.bounds.y <= area.y + area.height:
                var label_y = command.bounds.y + 8
                var is_top = abs(label_y - area.y) < 0.5
                if not is_top and (last_label_y - label_y < 18 or label_y - area.y < 18):
                    continue
                last_label_y = label_y
            scene.append(command)
        return scene^

    def combined_scene(self, view: ColumnView) -> Scene:
        var scene = Scene()
        if not self.model.fitted:
            return scene^
        var fit = self.plot_scene(view.bounds_for(FIT_CANVAS_ID), False)
        var residual = self.plot_scene(view.bounds_for(RESIDUAL_CANVAS_ID), True)
        for command in fit.commands:
            scene.append(command)
        for command in residual.commands:
            scene.append(command)
        return scene^
