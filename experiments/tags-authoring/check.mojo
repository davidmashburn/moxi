"""Behavior checks through Moxi App routing, not a parallel JS simulation."""
from moxi import (
    App, Component, ColumnView, ClickEvent, Event, KeyEvent, TextInputEvent,
    CompositionEvent, Point, Rect, ViewNode, test_check,
    KEY_A, KEY_LEFT, KEY_BACKSPACE, KEY_SPACE, KEY_TAB, MOD_COMMAND,
)
from Counters import Counters
from GreetingForm import GreetingForm


def node(view: ColumnView, id: Int) -> ViewNode:
    for i in range(view.child_count()):
        if view.child(i).id == id:
            return view.child(i)
    test_check(False)
    return view.child(0)


def click[C: Component & Deinitable](mut app: App[C], id: Int) -> Bool:
    var bounds = app.view.bounds_for(id)
    return app.update(ClickEvent(Point(bounds.x + 8.0, bounds.y + 8.0)))


def replace[C: Component & Deinitable](mut app: App[C], id: Int, text: String):
    _ = click(app, id)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent(text)))


def main():
    var counters = App[Counters](Counters(), Rect(0, 0, 520, 520))
    test_check(counters.paint().count() > 0)
    test_check(click(counters, 2))
    test_check(node(counters.view, 2).text == "Clicked 1 times")
    test_check(node(counters.view, 3).text == "Clicked 0 times")
    test_check(click(counters, 5))
    test_check(node(counters.view, 5).text == "Clicked 1 times")
    test_check(node(counters.view, 6).text == "Clicked 1 times")
    test_check(click(counters, 6))
    test_check(node(counters.view, 5).text == "Clicked 2 times")
    test_check(node(counters.view, 2).text == "Clicked 1 times")
    # Space follows native focus to the second shared counter.
    test_check(counters.update(Event(KeyEvent(KEY_SPACE))))
    test_check(node(counters.view, 5).text == "Clicked 3 times")
    var fresh = App[Counters](Counters(), Rect(0, 0, 520, 520))
    test_check(node(fresh.view, 5).text == "Clicked 0 times")
    print("PASS independent counters, shared bindings, keyboard activation, fresh root")

    var form = App[GreetingForm](GreetingForm(), Rect(0, 0, 520, 600))
    test_check(form.view.child_count() == 7)
    test_check(node(form.view, 7).text == "Hello, Ada")
    test_check(form.paint().count() > 0)
    replace(form, 2, "  Grace  ")
    test_check(form.focus_id() == 2)
    test_check(node(form.view, 7).text == "Hello, Grace")
    # A rebuild keeps editing selection and focus, rather than recreating the editor.
    _ = form.update(Event(KeyEvent(KEY_LEFT)))
    var cursor = form.component.editor2.cursor
    var anchor = form.component.editor2.anchor
    _ = form.resize(Rect(0, 0, 540, 620))
    test_check(form.component.editor2.cursor == cursor)
    test_check(form.component.editor2.anchor == anchor)
    test_check(form.focus_id() == 2)
    _ = click(form, 8)
    test_check(node(form.view, 10).text == "Saved: Grace")
    print("PASS child return, derived preview, trim, immediate Save, focus/cursor on rebuild")

    _ = click(form, 3)
    test_check(node(form.view, 7).text == "Name required")
    test_check(not node(form.view, 8).enabled)
    test_check(not click(form, 8))
    test_check(node(form.view, 10).text == "Saved: Grace")
    replace(form, 6, "  Mox  ")
    _ = click(form, 8)
    test_check(node(form.view, 10).text == "Saved: Mox")
    _ = click(form, 3)
    test_check(node(form.view, 7).text == "Hello, Grace")
    # Hidden control IDs must not accept stale events.
    var stale = Event(TextInputEvent("bad"))
    stale.set_target(6)
    test_check(not form.component.update(stale, form.view))
    _ = click(form, 3)
    test_check(node(form.view, 6).text == "  Mox  ")
    test_check(node(form.view, 7).text == "Hello, Mox")
    _ = click(form, 9)
    test_check(form.view.child_count() == 7)
    test_check(node(form.view, 2).text == "Ada")
    _ = click(form, 3)
    test_check(node(form.view, 6).text == "")
    print("PASS disabled Save, conditional mount, parent state survives hiding, reset, stale-event rejection")

    _ = click(form, 9)
    replace(form, 2, "λ🙂")
    _ = form.update(Event(KeyEvent(KEY_BACKSPACE)))
    test_check(node(form.view, 2).text == "λ")
    _ = form.update(Event(CompositionEvent("に", 0, 1)))
    test_check(form.component.editor2.has_composition())
    test_check(node(form.view, 7).text == "Hello, λ")
    _ = form.update(Event(TextInputEvent("日")))
    test_check(node(form.view, 2).text == "λ日")
    test_check(not form.component.editor2.has_composition())
    _ = form.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    test_check(form.component.clipboard_copy(2, form.view) == "λ日")
    test_check(form.component.clipboard_cut(2, form.view) == "λ日")
    test_check(form.component.build(Rect(0, 0, 520, 600)).child(4).text == "Name required")
    test_check(form.component.clipboard_paste(2, "Zoë", form.view))
    _ = form.resize(Rect(0, 0, 560, 640))
    test_check(node(form.view, 7).text == "Hello, Zoë")
    _ = form.update(Event(KeyEvent(KEY_TAB)))
    test_check(form.focus_id() == 3)
    print("PASS Unicode editing, composition/commit, clipboard hooks, Tab focus")
    print("All tags authoring behavior checks passed")
