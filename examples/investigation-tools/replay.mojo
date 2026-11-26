from std.ffi import external_call
from moxi import App, Point
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer, MacOSClipboard
from screen import InvestigationScreen, NAME_ID, HYPOTHESIS_ID, PATH_ID, C0_ID, C1_ID, C2_ID, COLLECT_ID, MODE_ID, FILTER_ID, SORT_ID, FIXTURE_BUTTON_ID, LINEAR_ID, QUADRATIC_ID, APPLY_ID, REFIT_ID, COMPARE_ID, SAVE_ID, REOPEN_ID, INTERNALS_ID
from model import ModelKind, MembershipMode, FixtureState
from panel import panel_json
from runtime import render, dispatch_pending

comptime REOPEN_MODE = 2


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def capture(name: String):
    var filename = name
    external_call["cohort_snapshot", NoneType](filename.as_c_string_span().ptr())


def drain(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer) raises:
    var clipboard = MacOSClipboard()
    _ = dispatch_pending(app, window, clipboard)
    render(app, renderer, plots)


def click(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, id: Int) raises:
    var bounds = app.view.bounds_for(id)
    var x = bounds.x + bounds.width/2
    var y = bounds.y + bounds.height/2
    check(bounds.width > 0 and bounds.height > 0 and app.root_bounds.contains(Point(x, y)), "Control must be mounted and within the window")
    check(app.hit_test(Point(x, y)) == id, "Actual hit target must match requested control")
    external_call["cohort_mouse", NoneType](x, y, Int32(1))
    drain(app, window, renderer, plots)
    external_call["cohort_mouse", NoneType](x, y, Int32(0))
    drain(app, window, renderer, plots)


def edit(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, id: Int, value: String) raises:
    click(app, window, renderer, plots, id)
    check(app.focus_id() == id, "Text input receives keyboard focus")
    external_call["investigation_select_all", NoneType]()
    drain(app, window, renderer, plots)
    var text = value
    external_call["investigation_text", NoneType](text.as_c_string_span().ptr())
    drain(app, window, renderer, plots)
    var actual = app.component.name_input.text
    if id == HYPOTHESIS_ID:
        actual = app.component.hypothesis_input.text
    elif id == C0_ID:
        actual = app.component.c0_input.text
    elif id == C1_ID:
        actual = app.component.c1_input.text
    elif id == C2_ID:
        actual = app.component.c2_input.text
    elif id == PATH_ID:
        actual = app.component.path_input.text
    if actual != value:
        capture("failed-text-replacement.png")
        raise Error(String("Native text replacement failed for ", id, ": expected [", value, "] observed [", actual, "]"))


def named_linear(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer) raises:
    edit(app, window, renderer, plots, NAME_ID, "Warm run α")
    edit(app, window, renderer, plots, HYPOTHESIS_ID, "Curvature may explain the warm readings; test alternatives.")
    click(app, window, renderer, plots, COLLECT_ID)
    check(app.component.model.name == "Warm run α" and app.component.model.ids() == "[318,429,530,641,752,863]", "Named cohort through native text and button")
    check(app.component.model.notebook.writes == 1, "I20 operation executed exactly once")
    click(app, window, renderer, plots, LINEAR_ID)
    check(abs(app.component.model.fit.c1 - 16) < 1e-8 and abs(app.component.model.sse(app.component.model.fit) - 448.0/3) < 1e-7, "Native fit coefficients and residuals")

def replay(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, mode: Int32) raises:
    check(not app.component.model.fitted and len(app.component.model.members) == 0, "Normal entry point starts with fresh state")
    if mode == REOPEN_MODE:
        click(app, window, renderer, plots, REOPEN_ID)
        check(app.component.panel_open and app.component.model.name == "Warm run α", "New process restored name and panel")
        check(app.component.model.mode == MembershipMode.FROZEN and app.component.model.fixture == FixtureState.BASELINE and app.component.model.fit.kind == ModelKind.QUADRATIC, "Restored domain types")
        check(app.component.model.ids() == "[318,429,530,641,752,863]" and abs(app.component.model.fit.c0 - 69) < 1e-7 and abs(app.component.model.sse(app.component.model.fit) - 6) < 1e-7, "Restored intended IDs and edited coefficients")
        capture("13-new-process-reopen.png")
        click(app, window, renderer, plots, REFIT_ID)
        check(abs(app.component.model.fit.c0 - 68) < 1e-7 and app.component.model.sse(app.component.model.fit) < 1e-7, "Saved refit targets intended observations")
        capture("14-panel-refit.png")
        edit(app, window, renderer, plots, C1_ID, "-1")
        click(app, window, renderer, plots, APPLY_ID)
        check(abs(app.component.model.sse(app.component.model.fit) - 139) < 1e-7, "Reopened coefficient control recomputes intended residuals")
        capture("15-panel-edit.png")
        print("PASS fresh-process reopen: full configuration, stable IDs, saved refit and coefficient controls")
        return
    if mode == 3 or mode == 4:
        named_linear(app, window, renderer, plots)
        var before = panel_json(app.component.model)
        click(app, window, renderer, plots, REOPEN_ID if mode == 3 else SAVE_ID)
        check(app.component.status.startswith("Cannot apply:") and not app.component.panel_open, "File failure is visible")
        check(before == panel_json(app.component.model), "File failure preserves current investigation")
        capture("16-load-rejected.png" if mode == 3 else "17-save-rejected.png")
        print("PASS file failure: visible error and unchanged investigation")
        return

    capture("01-entry.png")
    edit(app, window, renderer, plots, NAME_ID, "")
    click(app, window, renderer, plots, COLLECT_ID)
    check(len(app.component.model.members) == 0 and app.component.model.notebook.writes == 0 and app.component.status.startswith("Cannot apply:"), String("Empty cohort name rejected: members=", app.component.model.ids(), " writes=", app.component.model.notebook.writes, " status=", app.component.status))
    named_linear(app, window, renderer, plots)
    capture("02-linear.png")
    var before = panel_json(app.component.model)
    edit(app, window, renderer, plots, C0_ID, "oops")
    click(app, window, renderer, plots, APPLY_ID)
    check(app.component.status.startswith("Cannot apply:") and panel_json(app.component.model) == before, "Invalid coefficient preserves fit")
    capture("03-invalid-coefficient.png")
    edit(app, window, renderer, plots, C0_ID, String(app.component.model.fit.c0))
    click(app, window, renderer, plots, COMPARE_ID)
    check(app.component.compared, "Alternatives visible")
    external_call["investigation_resize", NoneType](Float32(980), Float32(800))
    drain(app, window, renderer, plots)
    var last_alternative = app.view.bounds_for(303)
    check(last_alternative.y + last_alternative.height <= app.view.bounds_for(54).y, "Narrow alternatives remain above status")
    capture("04-alternatives.png")
    external_call["investigation_resize", NoneType](Float32(1140), Float32(860))
    drain(app, window, renderer, plots)
    click(app, window, renderer, plots, QUADRATIC_ID)
    check(app.component.model.fit.kind == ModelKind.QUADRATIC and app.component.model.sse(app.component.model.fit) < 1e-7, "Alternative quadratic model selected")
    capture("05-quadratic.png")
    edit(app, window, renderer, plots, C0_ID, "69")
    click(app, window, renderer, plots, SAVE_ID)
    check(not app.component.panel_open and app.component.status.startswith("Cannot apply:"), "Save refuses unapplied coefficient edits")
    click(app, window, renderer, plots, APPLY_ID)
    check(abs(app.component.model.sse(app.component.model.fit) - 6) < 1e-7, "Editable explicit model")
    capture("06-edited.png")
    before = panel_json(app.component.model)
    click(app, window, renderer, plots, FILTER_ID)
    click(app, window, renderer, plots, SORT_ID)
    check(panel_json(app.component.model) == before and app.component.high_only and app.component.descending, "Filtering and sorting preserve cohort and model")
    capture("07-stable-ids.png")
    click(app, window, renderer, plots, FIXTURE_BUTTON_ID)
    check(not app.component.model.contains(207) and not app.component.model.fitted, "Frozen cohort survives threshold crossing; fit invalidated")
    capture("08-frozen.png")
    click(app, window, renderer, plots, MODE_ID)
    check(app.component.model.mode == MembershipMode.LIVE and app.component.model.contains(207), "Live membership refreshes through I20")
    click(app, window, renderer, plots, QUADRATIC_ID)
    capture("09-live.png")
    click(app, window, renderer, plots, FIXTURE_BUTTON_ID)
    check(not app.component.model.contains(207) and not app.component.model.fitted, "Live member leaves as reading falls")
    click(app, window, renderer, plots, MODE_ID)
    check(app.component.model.mode == MembershipMode.FROZEN, "Back to frozen membership")
    click(app, window, renderer, plots, QUADRATIC_ID)
    edit(app, window, renderer, plots, C0_ID, "69")
    click(app, window, renderer, plots, APPLY_ID)
    click(app, window, renderer, plots, SAVE_ID)
    check(app.component.panel_open and app.component.status.startswith("Saved fixed panel"), "Panel saved through normal control")
    capture("10-saved-panel.png")
    external_call["investigation_resize", NoneType](Float32(980), Float32(800))
    drain(app, window, renderer, plots)
    check(app.root_bounds.width == 980 and app.root_bounds.height == 800, "Narrow window layout")
    capture("11-narrow-panel.png")
    click(app, window, renderer, plots, REFIT_ID)
    check(app.component.model.sse(app.component.model.fit) < 1e-7, "Narrow fixed panel refit")
    click(app, window, renderer, plots, REOPEN_ID)
    check(abs(app.component.model.fit.c0 - 69) < 1e-7, "Saved coefficients survive refit and reopen")
    click(app, window, renderer, plots, INTERNALS_ID)
    check(not app.component.panel_open, "Explicit route to internals")
    # AppKit reserves function keys while a text editor is active. Give a
    # normal button focus before exercising the existing I20 native shortcut.
    click(app, window, renderer, plots, FILTER_ID)
    external_call["cohort_shortcut", NoneType]()
    drain(app, window, renderer, plots)
    check(not app.component.model.fitted and app.component.model.ids() == "[318,429,530,641,752,863]", "F2 reuses I20 and invalidates previous fit")
    capture("12-internals.png")
    print("PASS native UI: entry, text, I20 collection/F2, fits, residuals, alternatives, editing, rejection, stable IDs, live/frozen, save, narrow layout and internals")
