"""Scoped native regression for full coefficients and allowed-length metadata."""
from std.ffi import external_call
from moxi import App, Point, Rect
from moxi.scene import SCENE_TEXT
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from screen import InvestigationScreen, NAME_ID, HYPOTHESIS_ID, MODE_ID, C0_ID, C1_ID, C2_ID, QUADRATIC_ID, APPLY_ID, COMPARE_ID, SAVE_ID, REOPEN_ID, REFIT_ID, INTERNALS_ID, FIT_CANVAS_ID, RESIDUAL_CANVAS_ID
from model import ModelKind, MembershipMode
from panel import panel_json
from replay import check, capture, drain, click, edit, named_linear

comptime EDITED_C0 = "-33.333333333333336"
comptime EDITED_C1 = "16.123456789012344"
comptime EDITED_C2 = "-1.2345678901234567e-123"


def wide_text(length: Int) -> String:
    var text = String("")
    for i in range(length):
        text += "W"
    return text^


def layout_fits(app: App[InvestigationScreen]) raises -> Bool:
    var fits = True
    var column = app.view.bounds_for(103)
    var status = app.view.bounds_for(54)
    for child in app.view.children:
        if child.id != C0_ID and child.id != C1_ID and child.id != C2_ID:
            continue
        var text = child.text
        var needed = external_call["investigation_text_width", Float32](text.as_c_string_span().ptr(), child.style.font_size) + 24
        var bounds = child.bounds
        var visible = bounds.width >= needed
        fits = fits and visible
        print("FIELD", child.id, "text", text, "available", bounds.width, "needed", needed, "fits", visible)
        fits = fits and bounds.x >= column.x and bounds.x + bounds.width <= column.x + column.width and bounds.y + bounds.height <= status.y
        check(app.hit_test(Point(bounds.x+2, bounds.y+bounds.height/2)) == child.id and app.hit_test(Point(bounds.x+bounds.width-2, bounds.y+bounds.height/2)) == child.id, "Both ends of each coefficient retain the correct hit target")
    var previous = app.view.bounds_for(C2_ID)
    for id in [APPLY_ID, 53, FIT_CANVAS_ID, RESIDUAL_CANVAS_ID]:
        var bounds = app.view.bounds_for(id)
        check(bounds.y >= previous.y + previous.height, "Coefficient controls, metrics and plots do not overlap vertically")
        previous = bounds
    for id in [FIT_CANVAS_ID, RESIDUAL_CANVAS_ID]:
        var canvas = app.view.bounds_for(id)
        var scene = app.component.plot_scene(canvas, id == RESIDUAL_CANVAS_ID)
        var labels = List[Rect]()
        for command in scene.commands:
            if command.kind != SCENE_TEXT or command.bounds.x != canvas.x + 2:
                continue
            for previous in labels:
                check(command.bounds.y >= previous.y + previous.height + 2 or previous.y >= command.bounds.y + command.bounds.height + 2, "Native plot y labels stay separated rather than collapsing with the data area")
            labels.append(command.bounds)
        check(len(labels) >= 2, "Each native plot retains distinct endpoint labels and a nonzero data area")
    if app.component.compared and not app.component.panel_open:
        var last = app.view.bounds_for(303)
        check(last.height > 0 and last.y + last.height <= min(status.y, column.y + column.height), "All three alternatives remain inside their column and above status at minimum size")
    if app.component.panel_open:
        for text in [app.component.model.name, app.component.model.hypothesis, "Mode: " + app.component.model.mode.value]:
            var label = text
            var visible = external_call["investigation_label_fits", Int32](label.as_c_string_span().ptr()) != 0
            print("LABEL", text.count_codepoints(), "characters; all native glyphs fit", visible)
            fits = fits and visible
        var previous = app.view.bounds_for(3)
        for id in [4, MODE_ID, 5, 6, 7, INTERNALS_ID, 8, 9, 105, 50, 200, 201, 202, 203, 204, 205, 206, 207]:
            var bounds = app.view.bounds_for(id)
            # Missing mode in the original screen is a regression failure, not
            # an early stop: retain before captures of the other fields, too.
            if id == MODE_ID and bounds.height == 0:
                fits = False
                continue
            check(bounds.y >= previous.y + previous.height, "Saved metadata, provenance, controls and table rows do not overlap")
            previous = bounds
        var left = app.view.bounds_for(102)
        print("TABLE bottom", previous.y + previous.height, "column ends", left.y + left.height, "status starts", status.y)
        check(previous.y + previous.height <= min(status.y, left.y + left.height), "All eight table rows remain inside the column and above status after wrapping metadata")
    return fits


def capture_sizes(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, prefix: String) raises -> Bool:
    var fits = True
    for width in [980, 1140]:
        var height = 800 if width == 980 else 860
        external_call["investigation_resize", NoneType](Float32(width), Float32(height))
        drain(app, window, renderer, plots)
        check(app.root_bounds.width == Float32(width) and app.root_bounds.height == Float32(height), "Actual native content size matches regression viewport")
        print("VIEW", prefix, width, height)
        capture(prefix + ("-min.png" if width == 980 else "-large.png"))
        fits = layout_fits(app) and fits
    return fits


def check_edited(app: App[InvestigationScreen]) raises:
    var model = app.component.model
    check(model.fitted and model.fit.kind == ModelKind.QUADRATIC, "Edited quadratic model restored")
    check(model.fit.c0 == Float64(EDITED_C0) and model.fit.c1 == Float64(EDITED_C1) and model.fit.c2 == Float64(EDITED_C2), "All edited Float64 coefficients survive exactly")
    check(Float64(app.component.c0_input.text) == model.fit.c0 and Float64(app.component.c1_input.text) == model.fit.c1 and Float64(app.component.c2_input.text) == model.fit.c2, "Editor values round-trip to the exact model coefficients")
    check(model.ids() == "[318,429,530,641,752,863]", "Persistence targets the original stable observations")
    check(model.name == wide_text(64) and model.hypothesis == wide_text(140), "Maximum-length name and hypothesis survive without truncation")


def replay_layout(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, reopen: Bool) raises:
    check(not app.component.model.fitted and len(app.component.model.members) == 0, "Normal entry creates fresh investigation")
    if reopen:
        click(app, window, renderer, plots, REOPEN_ID)
        check(app.component.panel_open, "Fresh process reopened saved panel")
        check_edited(app)
        check(app.component.model.mode == MembershipMode.LIVE, "Fresh process restores live membership")
        check(capture_sizes(app, window, renderer, plots, "reopened"), "Reopened coefficients, metadata and mode fit at both sizes")
        var before = panel_json(app.component.model)
        click(app, window, renderer, plots, APPLY_ID)
        check(panel_json(app.component.model) == before, "No-op Apply after reopen preserves exact Float64 values")
        click(app, window, renderer, plots, REFIT_ID)
        check(app.component.model.sse(app.component.model.fit) < 1e-7, "Reopened refit targets the original observations")
        click(app, window, renderer, plots, REOPEN_ID)
        check_edited(app)
        print("PASS layout reopen: maximum metadata, live mode, exact coefficients, no-op Apply, refit and disk restoration")
        return

    named_linear(app, window, renderer, plots)
    var before = panel_json(app.component.model)
    click(app, window, renderer, plots, APPLY_ID)
    check(panel_json(app.component.model) == before, "No-op Apply preserves full-precision linear fit")
    click(app, window, renderer, plots, COMPARE_ID)
    var fits = capture_sizes(app, window, renderer, plots, "linear")
    click(app, window, renderer, plots, QUADRATIC_ID)
    # Native editing at the minimum size, not only after widening the window.
    external_call["investigation_resize", NoneType](Float32(980), Float32(800))
    drain(app, window, renderer, plots)
    before = panel_json(app.component.model)
    edit(app, window, renderer, plots, C2_ID, "oops")
    click(app, window, renderer, plots, APPLY_ID)
    check(app.component.status.startswith("Cannot apply:") and panel_json(app.component.model) == before, "Invalid coefficient preserves the existing fit")
    edit(app, window, renderer, plots, C0_ID, EDITED_C0)
    edit(app, window, renderer, plots, C1_ID, "16.123456789012345")
    var replacement = String("4")
    external_call["investigation_edit_last_character", NoneType](replacement.as_c_string_span().ptr())
    drain(app, window, renderer, plots)
    check(app.component.c1_input.text == EDITED_C1, "Native field editor navigates to the end, deletes and inserts the final digit")
    edit(app, window, renderer, plots, C2_ID, EDITED_C2)
    click(app, window, renderer, plots, SAVE_ID)
    check(not app.component.panel_open and app.component.status.startswith("Cannot apply:") and panel_json(app.component.model) == before, "Save rejects pending coefficient edits without changing the fit")
    edit(app, window, renderer, plots, NAME_ID, wide_text(64))
    edit(app, window, renderer, plots, HYPOTHESIS_ID, wide_text(140))
    replacement = "Z"
    external_call["investigation_edit_last_character", NoneType](replacement.as_c_string_span().ptr())
    drain(app, window, renderer, plots)
    check(app.component.hypothesis_input.text == wide_text(139) + "Z", "The end of a maximum-length hypothesis remains normally editable")
    replacement = "W"
    external_call["investigation_edit_last_character", NoneType](replacement.as_c_string_span().ptr())
    drain(app, window, renderer, plots)
    click(app, window, renderer, plots, APPLY_ID)
    check_edited(app)
    fits = capture_sizes(app, window, renderer, plots, "edited") and fits
    # Apply at the larger size, too, without silently rounding the displayed values.
    before = panel_json(app.component.model)
    click(app, window, renderer, plots, APPLY_ID)
    check(panel_json(app.component.model) == before, "No-op Apply at larger size preserves all edited coefficients")
    external_call["investigation_resize", NoneType](Float32(980), Float32(800))
    drain(app, window, renderer, plots)
    click(app, window, renderer, plots, SAVE_ID)
    check(app.component.panel_open and app.component.status.startswith("Saved fixed panel"), "Native Save writes the fixed panel")
    check(app.component.model.mode == MembershipMode.FROZEN, "Original frozen membership is retained")
    fits = capture_sizes(app, window, renderer, plots, "saved-frozen") and fits
    click(app, window, renderer, plots, REFIT_ID)
    click(app, window, renderer, plots, REOPEN_ID)
    check_edited(app)
    check(app.component.model.mode == MembershipMode.FROZEN, "Same-process reopen restores frozen membership")
    fits = capture_sizes(app, window, renderer, plots, "saved-frozen") and fits
    click(app, window, renderer, plots, INTERNALS_ID)
    check(not app.component.panel_open, "Normal route back to investigation internals remains available")
    click(app, window, renderer, plots, MODE_ID)
    click(app, window, renderer, plots, QUADRATIC_ID)
    edit(app, window, renderer, plots, C0_ID, EDITED_C0)
    edit(app, window, renderer, plots, C1_ID, EDITED_C1)
    edit(app, window, renderer, plots, C2_ID, EDITED_C2)
    click(app, window, renderer, plots, APPLY_ID)
    click(app, window, renderer, plots, SAVE_ID)
    check(app.component.panel_open and app.component.model.mode == MembershipMode.LIVE, "Live membership can also be saved")
    fits = capture_sizes(app, window, renderer, plots, "saved-live") and fits
    click(app, window, renderer, plots, REFIT_ID)
    click(app, window, renderer, plots, REOPEN_ID)
    check_edited(app)
    check(app.component.model.mode == MembershipMode.LIVE, "Same-process reopen restores live membership")
    fits = capture_sizes(app, window, renderer, plots, "saved-live") and fits
    check(fits, "Full coefficients, maximum-length metadata and separate mode must fit at both sizes")
    print("PASS layout: native min/large, all editors, invalid/pending edits, end navigation, exact Apply, maximum metadata, frozen/live Save and Reopen")
