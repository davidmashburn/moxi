"""Inert composition, semantic content, wrapping, namespaces, and replacement."""

from moxi import NotImplemented as RootNotImplemented, test_check
from moxi import (
    ACTION_NONE, ACTION_PRESS, App, ActionEvent, ClickEvent, Event,
    KEY_ENTER, KEY_TAB, KeyEvent, Point, PointerEvent, POINTER_DOWN_KIND,
    Rect, ROLE_CONTAINER, ROLE_LABEL, ROOT_SCROLL_ID, ScrollEvent,
)
from moxi.not_implemented import (
    NotImplemented, NOT_IMPLEMENTED_FEATURE_ID, NOT_IMPLEMENTED_STATUS_ID,
    NOT_IMPLEMENTED_EXPLANATION_ID,
)
from moxi_demo.not_implemented_demo import (
    NotImplementedDemo, PATTERN_HOST_BUTTON_ID, PATTERN_REPLACE_BUTTON_ID,
    PATTERN_FIRST_SLOT_ID, PATTERN_FIRST_OFFSET, PATTERN_SECOND_OFFSET,
)
from moxi_demo.demo_browser import (
    DemoBrowserState, DEMO_ENTRY_VIEW_BASE, DEMO_TAB_DEMO_ID, DEMO_RESET_BUTTON_ID,
    DEMO_NOT_IMPLEMENTED_ID_OFFSET, DEMO_STORY_PREVIEW_ID,
)
from moxi_demo.demo_style import DEMO_NOT_IMPLEMENTED_ID


def action(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event


def require(condition: Bool, message: String):
    if not condition:
        print("FAIL:", message)
    test_check(condition)


def main():
    var default = RootNotImplemented("Export")
    var ordinary = Rect(0.0, 0.0, 600.0, 400.0)
    var default_view = default.build(ordinary)
    require(default_view.child_count() == 2, "default_view.child_count() == 2")
    require(default_view.child(0).text == "Export", "default_view.child(0).text == \"Export\"")
    require(default_view.child(1).text == "Not implemented yet", "default_view.child(1).text == \"Not implemented yet\"")
    var component = NotImplemented(
        "A long unfinished feature heading",
        "The host intentionally selected unfinished functionality. This explanation must remain readable when the panel becomes narrow, without offering an action or announcing progress.",
    )
    var app = App[NotImplemented](component, ordinary)
    require(app.view_is_valid(), "app.view_is_valid()")
    var snapshot = app.accessibility()
    require(snapshot.node_for_id(NOT_IMPLEMENTED_FEATURE_ID).label == component.feature_name, "snapshot.node_for_id(NOT_IMPLEMENTED_FEATURE_ID).label == component.feature_name")
    require(snapshot.node_for_id(NOT_IMPLEMENTED_STATUS_ID).label == "Not implemented yet", "snapshot.node_for_id(NOT_IMPLEMENTED_STATUS_ID).label == \"Not implemented yet\"")
    require(snapshot.node_for_id(NOT_IMPLEMENTED_EXPLANATION_ID).label == component.explanation, "snapshot.node_for_id(NOT_IMPLEMENTED_EXPLANATION_ID).label == component.explanation")
    var before = component.build(ordinary)
    var rebuilt = component.build(ordinary)
    for index in range(before.child_count()):
        var node = before.child(index)
        var again = rebuilt.child(index)
        require(node.id == again.id and node.text == again.text, "node.id == again.id and node.text == again.text")
        require(node.bounds.x == again.bounds.x and node.bounds.y == again.bounds.y, "node.bounds.x == again.bounds.x and node.bounds.y == again.bounds.y")
        require(node.bounds.width == again.bounds.width and node.bounds.height == again.bounds.height, "node.bounds.width == again.bounds.width and node.bounds.height == again.bounds.height")
        require(node.wrap_text and not node.focusable, "node.wrap_text and not node.focusable")
        require(node.semantics.role == ROLE_LABEL, "node.semantics.role == ROLE_LABEL")
        require(node.semantics.actions == ACTION_NONE, "node.semantics.actions == ACTION_NONE")
        require(not component.update(action(node.id), before), "not component.update(action(node.id), before)")
        var key = Event(KeyEvent(KEY_ENTER))
        key.set_target(node.id)
        require(not component.update(key, before), "not component.update(key, before)")
        var pointer = Event(PointerEvent(POINTER_DOWN_KIND, Point(20.0, 20.0)))
        pointer.set_target(node.id)
        require(not component.update(pointer, before), "not component.update(pointer, before)")
        require(not app.dispatch(action(node.id)), "not app.dispatch(action(node.id))")
    require(not app.dispatch(Event(ClickEvent(Point(25.0, 25.0)))), "not app.dispatch(Event(ClickEvent(Point(25.0, 25.0))))")
    _ = app.dispatch(Event(KeyEvent(KEY_TAB)))
    require(app.focus_id() == -1, "app.focus_id() == -1")
    require(app.pending_request_count() == 0, "app.pending_request_count() == 0")
    require(not app.animation_frames_requested, "not app.animation_frames_requested")
    require(app.resize(Rect(0.0, 0.0, 180.0, 100.0)), "app.resize(Rect(0.0, 0.0, 180.0, 100.0))")
    require(app.view.bounds_for(NOT_IMPLEMENTED_EXPLANATION_ID).height > before.bounds_for(NOT_IMPLEMENTED_EXPLANATION_ID).height, "app.view.bounds_for(NOT_IMPLEMENTED_EXPLANATION_ID).height > before.bounds_for(NOT_IMPLEMENTED_EXPLANATION_ID).height")
    require(app.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0, "app.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0")
    require(app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 10000.0)))), "app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 10000.0))))")
    var last = app.view.bounds_for(NOT_IMPLEMENTED_EXPLANATION_ID)
    require(last.y + last.height <= 100.0, "last.y + last.height <= 100.0")
    require(app.resize(ordinary), "app.resize(ordinary)")
    require(app.view.child(0).id == NOT_IMPLEMENTED_FEATURE_ID, "app.view.child(0).id == NOT_IMPLEMENTED_FEATURE_ID")

    var host = App[NotImplementedDemo](NotImplementedDemo(), Rect(0.0, 0.0, 600.0, 700.0))
    require(host.view_is_valid(), "host.view_is_valid()")
    require(host.accessibility().node_for_id(PATTERN_FIRST_SLOT_ID).role == ROLE_CONTAINER, "host.accessibility().node_for_id(PATTERN_FIRST_SLOT_ID).role == ROLE_CONTAINER")
    require(host.accessibility().node_for_id(PATTERN_FIRST_OFFSET + NOT_IMPLEMENTED_FEATURE_ID).label == "Counter", "host.accessibility().node_for_id(PATTERN_FIRST_OFFSET + NOT_IMPLEMENTED_FEATURE_ID).label == \"Counter\"")
    require(host.accessibility().node_for_id(PATTERN_SECOND_OFFSET + NOT_IMPLEMENTED_FEATURE_ID).label == "Report export", "host.accessibility().node_for_id(PATTERN_SECOND_OFFSET + NOT_IMPLEMENTED_FEATURE_ID).label == \"Report export\"")
    for i in range(host.view.child_count()):
        for j in range(i + 1, host.view.child_count()):
            require(host.view.child(i).id != host.view.child(j).id, "host.view.child(i).id != host.view.child(j).id")
    require(host.focus_id() == PATTERN_HOST_BUTTON_ID, "host.focus_id() == PATTERN_HOST_BUTTON_ID")
    require(host.dispatch(Event(KeyEvent(KEY_ENTER))), "host.dispatch(Event(KeyEvent(KEY_ENTER)))")
    require(host.component.host_clicks == 1, "host.component.host_clicks == 1")
    _ = host.dispatch(Event(KeyEvent(KEY_TAB)))
    require(host.focus_id() == PATTERN_REPLACE_BUTTON_ID, "host.focus_id() == PATTERN_REPLACE_BUTTON_ID")
    require(not host.dispatch(action(PATTERN_FIRST_OFFSET + NOT_IMPLEMENTED_STATUS_ID)), "not host.dispatch(action(PATTERN_FIRST_OFFSET + NOT_IMPLEMENTED_STATUS_ID))")
    require(not host.dispatch(action(PATTERN_SECOND_OFFSET + NOT_IMPLEMENTED_STATUS_ID)), "not host.dispatch(action(PATTERN_SECOND_OFFSET + NOT_IMPLEMENTED_STATUS_ID))")
    require(host.component.host_clicks == 1, "host.component.host_clicks == 1")
    require(host.dispatch(Event(KeyEvent(KEY_ENTER))), "host.dispatch(Event(KeyEvent(KEY_ENTER)))")
    require(host.component.show_implemented_counter, "host.component.show_implemented_counter")
    require(host.view_is_valid(), "host.view_is_valid()")
    require(host.dispatch(action(PATTERN_FIRST_OFFSET + 3)), "host.dispatch(action(PATTERN_FIRST_OFFSET + 3))")
    require(host.component.counter.component.count == 1, "host.component.counter.component.count == 1")
    require(host.dispatch(action(PATTERN_REPLACE_BUTTON_ID)), "host.dispatch(action(PATTERN_REPLACE_BUTTON_ID))")
    require(not host.component.show_implemented_counter, "not host.component.show_implemented_counter")
    require(host.accessibility().node_for_id(PATTERN_FIRST_OFFSET + NOT_IMPLEMENTED_STATUS_ID).label == "Not implemented yet", "host.accessibility().node_for_id(PATTERN_FIRST_OFFSET + NOT_IMPLEMENTED_STATUS_ID).label == \"Not implemented yet\"")
    require(host.component.host_clicks == 1, "host.component.host_clicks == 1")
    require(host.resize(Rect(0.0, 0.0, 280.0, 240.0)), "host.resize(Rect(0.0, 0.0, 280.0, 240.0))")
    require(host.view_is_valid(), "host.view_is_valid()")
    require(host.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0, "host.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0")
    require(host.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 10000.0)))), "host.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 10000.0))))")
    var recovery = host.view.bounds_for(PATTERN_REPLACE_BUTTON_ID)
    require(recovery.y + recovery.height <= 240.0, "recovery.y + recovery.height <= 240.0")

    var browser = App[DemoBrowserState](DemoBrowserState(), Rect(0.0, 0.0, 1100.0, 760.0))
    require(browser.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_NOT_IMPLEMENTED_ID)), "browser.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_NOT_IMPLEMENTED_ID))")
    require(browser.dispatch(action(DEMO_TAB_DEMO_ID)), "browser.dispatch(action(DEMO_TAB_DEMO_ID))")
    require(browser.view_is_valid(), "browser.view_is_valid()")
    require(browser.dispatch(action(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_HOST_BUTTON_ID)), "browser.dispatch(action(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_HOST_BUTTON_ID))")
    require(browser.component.not_implemented.component.host_clicks == 1, "browser.component.not_implemented.component.host_clicks == 1")
    require(browser.dispatch(action(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_REPLACE_BUTTON_ID)), "browser.dispatch(action(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_REPLACE_BUTTON_ID))")
    require(browser.component.not_implemented.component.show_implemented_counter, "browser.component.not_implemented.component.show_implemented_counter")
    require(browser.dispatch(action(DEMO_RESET_BUTTON_ID)), "browser.dispatch(action(DEMO_RESET_BUTTON_ID))")
    require(not browser.component.not_implemented.component.show_implemented_counter, "not browser.component.not_implemented.component.show_implemented_counter")
    require(browser.component.not_implemented.component.host_clicks == 0, "browser.component.not_implemented.component.host_clicks == 0")
    require(browser.resize(Rect(0.0, 0.0, 760.0, 500.0)), "Playground resize")
    require(browser.view_is_valid(), "narrow Playground tree")
    var preview = browser.view.bounds_for(DEMO_STORY_PREVIEW_ID)
    var bottom = browser.view.bounds_for(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_REPLACE_BUTTON_ID)
    require(bottom.y + bottom.height <= preview.y + preview.height, "recovery fits inside narrow Playground preview")
    require(browser.dispatch(action(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_REPLACE_BUTTON_ID)), "narrow Playground replacement")
    require(browser.view_is_valid(), "narrow Playground implemented tree")
    preview = browser.view.bounds_for(DEMO_STORY_PREVIEW_ID)
    bottom = browser.view.bounds_for(DEMO_NOT_IMPLEMENTED_ID_OFFSET + PATTERN_REPLACE_BUTTON_ID)
    require(bottom.y + bottom.height <= preview.y + preview.height, "implemented recovery fits inside preview")
    print("Moxi NotImplemented test passed")
