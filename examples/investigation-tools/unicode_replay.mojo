"""Paint and persistence regressions through the normal native entry point."""
from std.ffi import external_call
from moxi import App
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from screen import InvestigationScreen, NAME_ID, HYPOTHESIS_ID, MODE_ID, COLLECT_ID, QUADRATIC_ID, C1_ID, APPLY_ID, SAVE_ID, REOPEN_ID, INTERNALS_ID
from model import MembershipMode
from panel import panel_json
from replay import check, capture, click, edit, drain

comptime PADDED_COEFFICIENT = "0.00000012345678901234567"


def repeated(glyph: String, count: Int) -> String:
    var text = String("")
    for _ in range(count):
        text += glyph
    return text^


def scroll_edge(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, bottom: Bool) raises:
    if app.view.scroll_max_offset(102) <= 0:
        return
    for _ in range(16):
        var track = app.scrollbar_track_for(102)
        var x = track.x + track.width/2
        var y = track.y + track.height - 2 if bottom else track.y + 2
        external_call["cohort_mouse", NoneType](x, y, Int32(1))
        drain(app, window, renderer, plots)
        external_call["cohort_mouse", NoneType](x, y, Int32(0))
        drain(app, window, renderer, plots)
    var expected = app.view.scroll_max_offset(102) if bottom else Float32(0)
    check(abs(app.scroll_offset_for(102)-expected) < 1, "Native scrollbar reaches the requested end")


def inspect_sizes(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, prefix: String) raises -> Bool:
    var fits = True
    for width in [980, 1140]:
        external_call["investigation_resize", NoneType](Float32(width), Float32(800 if width == 980 else 860))
        drain(app, window, renderer, plots)
        scroll_edge(app, window, renderer, plots, False)
        check(app.root_bounds.width == Float32(width), "Regression uses actual native content size")
        capture(prefix + "-" + String(width) + ".png")
        for text in [app.component.model.name, app.component.model.hypothesis, "Mode: " + app.component.model.mode.value]:
            var label = text
            var visible = external_call["investigation_label_fits", Int32](label.as_c_string_span().ptr()) != 0
            print("PAINT CASE", prefix, width, text.count_codepoints(), "codepoints; complete native raster", visible)
            fits = visible and fits
        var previous = app.view.bounds_for(3)
        for id in [4, MODE_ID, 5, 6, 7, INTERNALS_ID, 8, 9, 105, 50, 200, 201, 202, 203, 204, 205, 206, 207]:
            var bounds = app.view.bounds_for(id)
            check(bounds.height >= 0 and bounds.y >= previous.y+previous.height, "Metadata, mode, provenance, controls and table do not overlap")
            previous = bounds
        scroll_edge(app, window, renderer, plots, True)
        var last = app.view.bounds_for(207)
        var column = app.view.bounds_for(102)
        check(last.y+last.height <= min(column.y+column.height, app.view.bounds_for(54).y)+1, "Scrolling reveals the last observation above status")
        if app.view.scroll_max_offset(102) > 0:
            capture(prefix + "-scrolled-" + String(width) + ".png")
        scroll_edge(app, window, renderer, plots, False)
    return fits


def check_identity(app: App[InvestigationScreen], mode: MembershipMode, name: String, hypothesis: String) raises:
    check(app.component.panel_open and app.component.model.mode == mode, "Saved membership domain type survives reopen")
    check(app.component.model.name == name and app.component.model.hypothesis == hypothesis, "Exact Unicode metadata survives Save/Reopen")
    check(app.component.model.ids() == "[318,429,530,641,752,863]", "Original stable observation IDs survive")
    check(app.component.model.fit.c1 == Float64(PADDED_COEFFICIENT), "Padded coefficient retains the exact Float64 value")


def replay_unicode(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer, reopen: Bool, live: Bool) raises:
    var mode = MembershipMode.LIVE if live else MembershipMode.FROZEN
    var sentinel_name = repeated("😀", 63) + "Z"
    var sentinel_hypothesis = repeated("😀", 139) + "Z"
    if reopen:
        click(app, window, renderer, plots, REOPEN_ID)
        check_identity(app, mode, sentinel_name, sentinel_hypothesis)
        var before = panel_json(app.component.model)
        var fits = inspect_sizes(app, window, renderer, plots, "fresh-emoji")
        click(app, window, renderer, plots, APPLY_ID)
        check(panel_json(app.component.model) == before, "Fresh-process no-op Apply preserves the complete panel")
        check(fits, "Fresh-process emoji sentinels must paint completely at both sizes")
        print("PASS Unicode fresh reopen:", mode.value)
        return

    click(app, window, renderer, plots, COLLECT_ID)
    if live:
        click(app, window, renderer, plots, MODE_ID)
    click(app, window, renderer, plots, QUADRATIC_ID)
    var fits = True
    for width in [980, 1140]:
        external_call["investigation_resize", NoneType](Float32(width), Float32(800 if width == 980 else 860))
        drain(app, window, renderer, plots)
        edit(app, window, renderer, plots, C1_ID, repeated(" ", 140) + PADDED_COEFFICIENT)
        var padded = app.component.c1_input.text
        print("PADDED active ink", width, external_call["investigation_input_ink", Int32](padded.as_c_string_span().ptr()))
        capture("padded-active-" + String(width) + ".png")
        var replacement = String("7")
        external_call["investigation_edit_last_character", NoneType](replacement.as_c_string_span().ptr())
        drain(app, window, renderer, plots)
        check(app.component.c1_input.text == repeated(" ", 140) + PADDED_COEFFICIENT, "Native End/delete/reinsert preserves the padded coefficient")
        print("PADDED edited ink", width, external_call["investigation_input_ink", Int32](padded.as_c_string_span().ptr()))
        capture("padded-edited-" + String(width) + ".png")
        click(app, window, renderer, plots, APPLY_ID)
        check(app.component.model.fit.c1 == Float64(PADDED_COEFFICIENT), "Apply accepts whitespace padding without numeric loss")
        var applied = app.component.c1_input.text
        var ink = external_call["investigation_input_ink", Int32](applied.as_c_string_span().ptr())
        print("PADDED applied ink", width, ink)
        fits = ink > 100 and fits
        capture("padded-applied-" + String(width) + ".png")
        # After commit, the example should expose the canonical Float64 spelling
        # rather than an arbitrarily padded lexical form that paints blank.
        print("PADDED", width, "canonical after Apply", app.component.c1_input.text == String(app.component.model.fit.c1))
        fits = app.component.c1_input.text == String(app.component.model.fit.c1) and fits

    # Saving an equivalent padded spelling must also leave a visible canonical
    # value; pending edits with a different value remain covered by check_layout.
    edit(app, window, renderer, plots, C1_ID, repeated(" ", 140) + PADDED_COEFFICIENT)
    click(app, window, renderer, plots, SAVE_ID)
    var saved_coefficient = app.component.c1_input.text
    print("PADDED saved ink", 1140, external_call["investigation_input_ink", Int32](saved_coefficient.as_c_string_span().ptr()))
    capture("padded-saved-1140.png")
    check(saved_coefficient == String(app.component.model.fit.c1), "Save canonicalizes an equivalent padded coefficient without numeric loss")
    click(app, window, renderer, plots, INTERNALS_ID)

    # Include wordless runs, fallback fonts, explicit Unicode line separators,
    # combining marks, RTL text and the empty hypothesis. Emoji is last so each
    # membership mode also gets a genuinely fresh-process sentinel reopen.
    var names = [sentinel_name, repeated("W", 64), repeated("漢", 63) + "Z", "A" + repeated("\u2028", 62) + "Z", repeated("a\u0301", 31) + "Z", "عربي 漢字 e\u0301 🧑🏽‍🔬 Z", "A", sentinel_name]
    var hypotheses = [sentinel_hypothesis, repeated("W", 140), repeated("漢", 139) + "Z", repeated("\u2028", 139) + "Z", repeated("a\u0301", 69) + "Z", "עברית عربي 漢字 👨‍👩‍👧‍👦 e\u0301 Z", "", sentinel_hypothesis]
    for index in range(len(names)):
        edit(app, window, renderer, plots, NAME_ID, names[index])
        edit(app, window, renderer, plots, HYPOTHESIS_ID, hypotheses[index])
        click(app, window, renderer, plots, SAVE_ID)
        check_identity(app, mode, names[index], hypotheses[index])
        var before = panel_json(app.component.model)
        fits = inspect_sizes(app, window, renderer, plots, "case" + String(index) + "-saved") and fits
        click(app, window, renderer, plots, REOPEN_ID)
        check(panel_json(app.component.model) == before, "Save/Reopen preserves the entire declarative configuration byte for byte")
        check_identity(app, mode, names[index], hypotheses[index])
        fits = inspect_sizes(app, window, renderer, plots, "case" + String(index) + "-reopened") and fits
        if index < len(names)-1:
            scroll_edge(app, window, renderer, plots, True)
            click(app, window, renderer, plots, INTERNALS_ID)
    check(fits, "All accepted representative Unicode must paint completely, and applied coefficients must be canonical")
    print("PASS Unicode create:", mode.value, "full native paint, exact persistence, two sizes, padded coefficient")
