"""Behavior checks through Moxi App routing, not a parallel JS simulation."""
from moxi import (
    App, TextInputState, ClickEvent, Event, KeyEvent, TextInputEvent,
    CompositionEvent, Point, Rect, ViewNode, test_check,
    KEY_A, KEY_LEFT, KEY_BACKSPACE, KEY_SPACE, KEY_TAB, MOD_COMMAND,
)
from moxi.authoring import Screen, HandlerHost, deliver, reset_headless
from Counters import Counters
from GreetingForm import GreetingForm


def target[R: Screen & Deinitable](app: App[HandlerHost[R]], source_id: Int) -> Int:
    # Test-only lookup of compiler source keys. Generated models never inspect
    # host controls or assign runtime IDs.
    var key = "tag" + String(source_id)
    var path = "/k" + String(key.byte_length()) + ":" + key + "/p0"
    for control in app.component.ui.controls:
        if control.path == path:
            return control.id
    test_check(False)
    return -1


def node[R: Screen & Deinitable](app: App[HandlerHost[R]], source_id: Int) -> ViewNode:
    var id = target(app, source_id)
    for i in range(app.view.child_count()):
        if app.view.child(i).id == id:
            return app.view.child(i)
    test_check(False)
    return app.view.child(0)


def editor[R: Screen & Deinitable](app: App[HandlerHost[R]], source_id: Int) -> TextInputState:
    return app.component.ui.controls[app.component.ui.index(target(app, source_id))].editor


def click[R: Screen & Deinitable](mut app: App[HandlerHost[R]], source_id: Int) -> Bool:
    var bounds = app.view.bounds_for(target(app, source_id))
    return app.update(ClickEvent(Point(bounds.x + 8.0, bounds.y + 8.0)))


def replace[R: Screen & Deinitable](mut app: App[HandlerHost[R]], source_id: Int, text: String):
    _ = click(app, source_id)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent(text)))


def main():
    var counters = App(HandlerHost(Counters()), Rect(0, 0, 520, 520))
    test_check(counters.paint().count() > 0)
    test_check(click(counters, 2))
    test_check(node(counters, 2).text == "Clicked 1 times")
    test_check(node(counters, 3).text == "Clicked 0 times")
    test_check(click(counters, 5))
    test_check(node(counters, 5).text == "Clicked 1 times")
    test_check(node(counters, 6).text == "Clicked 1 times")
    test_check(click(counters, 6))
    test_check(node(counters, 5).text == "Clicked 2 times")
    test_check(node(counters, 2).text == "Clicked 1 times")
    # Space follows native focus to the second shared counter.
    test_check(counters.update(Event(KeyEvent(KEY_SPACE))))
    test_check(node(counters, 5).text == "Clicked 3 times")
    var fresh = App(HandlerHost(Counters()), Rect(0, 0, 520, 520))
    test_check(node(fresh, 5).text == "Clicked 0 times")
    print("PASS independent counters, shared bindings, keyboard activation, fresh root")

    var form = App(HandlerHost(GreetingForm()), Rect(0, 0, 520, 600))
    test_check(form.view.child_count() == 7)
    test_check(node(form, 2).semantics.label == "Name")
    test_check(node(form, 3).semantics.label == "Use nickname")
    test_check(node(form, 3).text == "")
    test_check(node(form, 7).text == "Hello, Ada")
    test_check(form.paint().count() > 0)
    replace(form, 2, "  Grace  ")
    test_check(form.focus_id() == target(form, 2))
    test_check(node(form, 7).text == "Hello, Grace")
    # A rebuild keeps editing selection and focus, rather than recreating the editor.
    _ = form.update(Event(KeyEvent(KEY_LEFT)))
    var cursor = editor(form, 2).cursor
    var anchor = editor(form, 2).anchor
    _ = form.resize(Rect(0, 0, 540, 620))
    test_check(editor(form, 2).cursor == cursor)
    test_check(editor(form, 2).anchor == anchor)
    test_check(form.focus_id() == target(form, 2))
    _ = click(form, 8)
    test_check(node(form, 10).text == "Saved: Grace")
    print("PASS child return, derived preview, trim, immediate Save, focus/cursor on rebuild")

    _ = click(form, 3)
    test_check(node(form, 7).text == "Name required")
    test_check(not node(form, 8).enabled)
    test_check(not click(form, 8))
    test_check(node(form, 10).text == "Saved: Grace")
    replace(form, 6, "  Mox  ")
    _ = click(form, 8)
    test_check(node(form, 10).text == "Saved: Mox")
    var retired_input = target(form, 6)
    _ = click(form, 3)
    test_check(node(form, 7).text == "Hello, Grace")
    # Hidden control IDs must not accept stale events.
    var stale = Event(TextInputEvent("bad"))
    stale.set_target(retired_input)
    test_check(not form.component.update(stale, form.view))
    _ = click(form, 3)
    test_check(target(form, 6) != retired_input)
    test_check(not form.component.update(stale, form.view))
    test_check(node(form, 6).text == "  Mox  ")
    test_check(node(form, 7).text == "Hello, Mox")
    _ = click(form, 9)
    test_check(form.view.child_count() == 7)
    test_check(node(form, 2).text == "Ada")
    _ = click(form, 3)
    test_check(node(form, 6).text == "")
    print("PASS disabled Save, conditional mount, parent state survives hiding, reset, stale-event rejection")

    _ = click(form, 9)
    replace(form, 2, "λ🙂")
    _ = form.update(Event(KeyEvent(KEY_BACKSPACE)))
    test_check(node(form, 2).text == "λ")
    _ = form.update(Event(CompositionEvent("に", 0, 1)))
    test_check(editor(form, 2).has_composition())
    test_check(node(form, 7).text == "Hello, λ")
    _ = form.update(Event(TextInputEvent("日")))
    test_check(node(form, 2).text == "λ日")
    test_check(not editor(form, 2).has_composition())
    _ = form.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    test_check(form.component.clipboard_copy(target(form, 2), form.view) == "λ日")
    test_check(form.component.clipboard_cut(target(form, 2), form.view) == "λ日")
    test_check(form.component.build(Rect(0, 0, 520, 600)).child(4).text == "Name required")
    test_check(form.component.clipboard_paste(target(form, 2), "Zoë", form.view))
    _ = form.resize(Rect(0, 0, 560, 640))
    test_check(node(form, 7).text == "Hello, Zoë")
    _ = form.update(Event(KeyEvent(KEY_TAB)))
    test_check(form.focus_id() == target(form, 3))
    print("PASS Unicode editing, composition/commit, clipboard hooks, Tab focus")
    var old_action = form.component.capture(target(form, 9))
    reset_headless(form, GreetingForm())
    replace(form, 2, "New owner")
    test_check(not deliver(form, old_action))
    test_check(node(form, 2).text == "New owner")
    print("PASS production root reset rejects captured work from the previous owner")
    print("All tags authoring behavior checks passed")
