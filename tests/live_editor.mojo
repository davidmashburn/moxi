"""Exercise the normal browser draft/run path with the real asynchronous compiler."""
from std.ffi import external_call
from moxi import (
    App, Rect, Event, ActionEvent, ACTION_PRESS, KeyEvent, KEY_A, KEY_ENTER,
    MOD_COMMAND, MOD_CONTROL, FocusEvent, TextInputEvent, ScrollEvent, Point, test_check,
)
from moxi.macos import MacOSLiveEditor, MacOSLiveScript
from moxi_demo.demo_browser import (
    DemoBrowserState, DEMO_ENTRY_VIEW_BASE, DEMO_RUN_BUTTON_ID, DEMO_RESET_BUTTON_ID,
    DEMO_STORY_CODE_TEXT_ID, DEMO_SOURCE_TEXT_ID, DEMO_TAB_SOURCE_ID,
    DEMO_TAB_DEMO_ID, DEMO_TAB_DEMO, DEMO_NAV_PORTAL_ID, DEMO_CONTENT_PORTAL_ID,
    DEMO_CATEGORY_BUTTON_BASE, DEMO_SEARCH_ID,
)
from moxi_demo.demo_style import DEMO_LIVE_SCRIPT_ID, DEMO_COUNTER_ID, DEMO_CATEGORY_COMPONENTS
from moxi_demo.source_editor import DemoBuildPhase, EDITABLE_DEMO_SOURCE
from moxi_demo.live_editor_host import live_surface_clip, sync_live_editor


def check(condition: Bool, scenario: String):
    if not condition:
        print("FAIL", scenario)
    test_check(condition)


def check_scroll(app: App[DemoBrowserState], expected: Float32, scenario: String):
    var actual = app.view.scroll_offset_for(DEMO_NAV_PORTAL_ID)
    if actual != expected:
        print("Catalog scroll:", actual, "expected:", expected,
              "stored:", app.scroll_offset_for(DEMO_NAV_PORTAL_ID),
              "maximum:", app.view.scroll_max_offset(DEMO_NAV_PORTAL_ID))
    check(actual == expected, scenario)


def action(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event


def replace_source(mut app: App[DemoBrowserState], target: Int, text: String) raises:
    var focus = Event(FocusEvent(target))
    _ = app.dispatch(focus)
    var select = Event(KeyEvent(KEY_A, MOD_COMMAND))
    select.set_target(target)
    test_check(app.dispatch(select))
    test_check(app.component.clipboard_paste(target, text, app.view))
    app.rebuild()


def finish(mut app: App[DemoBrowserState], mut editor: MacOSLiveEditor, mut live: MacOSLiveScript) raises:
    var ticks = 0
    while app.component.source_editor.building() and ticks < 30000:
        _ = app.tick(0.01)
        _ = sync_live_editor(app, editor, live)
        _ = external_call["usleep", Int32](UInt32(10000))
        ticks += 1
    test_check(not app.component.source_editor.building())
    test_check(ticks > 1)
    print("  UI ticks during compile:", ticks)


def frame_count() -> Int32:
    return external_call["moxi_dev_render_live_script", Int32](Float32(0), Float32(0), Float32(400), Float32(300))


def main() raises:
    var app = App[DemoBrowserState](DemoBrowserState(), Rect(0, 0, 1380, 900))
    var editor = MacOSLiveEditor()
    var live = MacOSLiveScript()
    var original = app.component.source_editor.original
    test_check(app.component.source_editor.available)
    test_check("moxi_live_frame" in original)

    var query = Event(TextInputEvent("mojo"))
    query.set_target(DEMO_SEARCH_ID)
    test_check(app.dispatch(query))

    test_check(app.dispatch(action(DEMO_CATEGORY_BUTTON_BASE + DEMO_CATEGORY_COMPONENTS)))
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_LIVE_SCRIPT_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    var nav = app.view.bounds_for(DEMO_NAV_PORTAL_ID)
    var scroll = Event(ScrollEvent(Point(nav.x + 10, nav.y + 10), Point(0, 80)))
    _ = app.dispatch(scroll)
    var offset = app.view.scroll_offset_for(DEMO_NAV_PORTAL_ID)
    test_check(offset > 0.0)

    test_check(app.dispatch(action(DEMO_RUN_BUTTON_ID)))
    test_check(not app.component.source_editor.request_run())
    _ = sync_live_editor(app, editor, live)
    test_check(app.component.source_editor.building())
    test_check(not editor.start(original))
    test_check(not app.component.source_editor.revert())
    # Normal catalog/tab actions must work while the compiler is running.
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_COUNTER_ID)))
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_LIVE_SCRIPT_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    finish(app, editor, live)
    test_check(live.loaded)
    test_check(frame_count() == 24)
    test_check(app.component.category == DEMO_CATEGORY_COMPONENTS)
    test_check(app.component.search.text == "mojo")
    test_check(app.view.scroll_offset_for(DEMO_NAV_PORTAL_ID) == offset)
    print("PASS original source, asynchronous run and catalog navigation")

    # Edit the Source tab; the Demo editor shares the same draft.
    test_check(app.dispatch(action(DEMO_TAB_SOURCE_ID)))
    check_scroll(app, offset, "Source tab retains catalog scroll")
    var edited = original.replace("range(22)", "range(8)")
    replace_source(app, DEMO_SOURCE_TEXT_ID, edited)
    check_scroll(app, offset, "Source edit retains catalog scroll")
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    check_scroll(app, offset, "Demo tab retains catalog scroll")
    test_check(app.component.source_editor.input.text() == edited)
    # Run is global even while search owns focus; it must not reset the list.
    _ = app.dispatch(Event(FocusEvent(DEMO_SEARCH_ID)))
    var run = Event(KeyEvent(KEY_ENTER, MOD_COMMAND))
    run.set_target(DEMO_STORY_CODE_TEXT_ID)
    test_check(app.dispatch(run))
    check_scroll(app, offset, "Run from search retains catalog scroll")
    _ = sync_live_editor(app, editor, live)
    # Continue editing during the build; the completed snapshot must be identified.
    replace_source(app, DEMO_STORY_CODE_TEXT_ID, edited + "\n# next draft\n")
    check_scroll(app, offset, "In-flight edit retains catalog scroll")
    finish(app, editor, live)
    check_scroll(app, offset, "Edited build retains catalog scroll")
    test_check(frame_count() == 10)
    test_check(app.component.source_editor.loaded_source == edited)
    test_check("draft changed" in app.component.source_editor.status())
    print("PASS edited scene and immutable in-flight snapshot")

    replace_source(app, DEMO_STORY_CODE_TEXT_ID, edited + "\ndef broken(:\n")
    run = Event(KeyEvent(KEY_ENTER, MOD_CONTROL))
    run.set_target(DEMO_STORY_CODE_TEXT_ID)
    test_check(app.dispatch(run))
    _ = sync_live_editor(app, editor, live)
    finish(app, editor, live)
    check_scroll(app, offset, "Compiler failure retains catalog scroll")
    test_check(app.component.source_editor.phase.value == DemoBuildPhase.FAILED.value)
    test_check("error:" in app.component.source_editor.diagnostics)
    test_check(".mojo:" in app.component.source_editor.diagnostics)
    test_check(frame_count() == 10)
    print("PASS compiler diagnostics and previous scene retention")

    replace_source(app, DEMO_STORY_CODE_TEXT_ID, "def unrelated():\n    pass\n")
    test_check(app.dispatch(action(DEMO_RUN_BUTTON_ID)))
    _ = sync_live_editor(app, editor, live)
    finish(app, editor, live)
    check_scroll(app, offset, "ABI failure retains catalog scroll")
    test_check(app.component.source_editor.phase.value == DemoBuildPhase.FAILED.value)
    test_check("moxi_live_frame" in app.component.source_editor.diagnostics)
    test_check(frame_count() == 10)
    print("PASS ABI failure retains scene")

    test_check(app.dispatch(action(DEMO_RESET_BUTTON_ID)))
    test_check(app.component.source_editor.input.text() == original)
    _ = sync_live_editor(app, editor, live)
    finish(app, editor, live)
    check(frame_count() == 24, "Revert restores original scene")
    check(app.component.source_editor.phase.value == DemoBuildPhase.READY.value, "Revert succeeds (compiler warnings allowed)")
    check("original source" in app.component.source_editor.status(), "Revert identifies original source")
    check(app.component.tab == DEMO_TAB_DEMO, "Revert retains tab")
    check(app.component.category == DEMO_CATEGORY_COMPONENTS, "Revert retains category")
    check(app.component.search.text == "mojo", "Revert retains query")
    check_scroll(app, offset, "Revert retains catalog scroll")
    with open(EDITABLE_DEMO_SOURCE, "r") as source:
        check(source.read() == original, "Checked-in source unchanged")
    # A narrow, scrolled page must not let the live canvas cover the shell.
    _ = app.resize(Rect(0, 0, 978, 760))
    var portal = app.view.bounds_for(DEMO_CONTENT_PORTAL_ID)
    var initial_surface = app.component.selected_surface_bounds(app.view)
    var scroll_distance = initial_surface.y - portal.y + initial_surface.height * 0.5
    var page_scroll = Event(ScrollEvent(Point(portal.x + portal.width - 10, portal.y + 10), Point(0, scroll_distance)))
    _ = app.dispatch(page_scroll)
    check(app.view.scroll_offset_for(DEMO_CONTENT_PORTAL_ID) > 0.0, "Narrow page scrolls")
    _ = app.paint()
    var surface = app.component.selected_surface_bounds(app.view)
    var clip = live_surface_clip(app)
    check(surface.y < portal.y, "Scrolled canvas extends above viewport")
    check(clip.y >= portal.y and clip.height < surface.height, "Live scene retains viewport clip")
    live.clear()
    print("PASS revert, clean status and unchanged example file")
    print("Moxi live-editor regression passed")
