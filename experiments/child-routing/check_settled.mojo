"""Shared ownership: dispatch, settle inputs, then render each affected child."""
from moxi import (
    App, ComponentSlot, Event, KeyEvent, TextInputEvent, CompositionEvent,
    Rect, test_check, KEY_A, KEY_C, KEY_X, KEY_V, KEY_LEFT, KEY_TAB, MOD_COMMAND,
)
from deferred import DeferredHost
from shared import NameEditor
from settled import SettledNames
from check import click, replace, occurrences


def target(slot: ComponentSlot[DeferredHost[NameEditor]]) -> Int:
    for control in slot.component.ui.controls:
        if control.active and control.path == "/p1":
            return slot.namespaced_id(control.id)
    test_check(False)
    return -1


def cursor_at(host: DeferredHost[NameEditor], id: Int) -> Int:
    var index = host.ui.index(id)
    return host.ui.controls[index].editor.cursor


def main():
    var app = App[SettledNames](SettledNames(), Rect(0, 0, 520, 600))
    var first = target(app.component.first)
    var second = target(app.component.second)
    click[SettledNames](app, first)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    var a = app.component.first.component.renders
    var b = app.component.second.component.renders
    _ = app.update(Event(TextInputEvent("Grace")))
    test_check(app.component.name == "Grace")
    test_check(app.component.commits == 1)
    test_check(occurrences(app.view, "Hello, Grace") == 2)
    test_check(app.component.first.component.renders == a + 1)
    test_check(app.component.second.component.renders == b + 1)
    test_check(cursor_at(app.component.first.component, first - 1000) == 5)
    _ = app.update(Event(TextInputEvent("!")))
    test_check(app.component.name == "Grace!")
    test_check(occurrences(app.view, "Hello, Grace!") == 2)
    test_check(cursor_at(app.component.first.component, first - 1000) == 6)
    print("PASS settled shared edits: one commit, one render per affected child, correct cursor and next keystroke")

    a = app.component.first.component.renders
    b = app.component.second.component.renders
    var commits = app.component.commits
    _ = app.update(Event(KeyEvent(KEY_LEFT)))
    test_check(cursor_at(app.component.first.component, first - 1000) == 5)
    test_check(app.component.commits == commits)
    test_check(app.component.first.component.renders == a + 1)
    test_check(app.component.second.component.renders == b)
    var first_cursor = cursor_at(app.component.first.component, first - 1000)
    _ = app.update(Event(KeyEvent(KEY_TAB)))
    test_check(app.focus_id() == second)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent("Second")))
    test_check(app.component.name == "Second")
    test_check(occurrences(app.view, "Hello, Second") == 2)
    test_check(cursor_at(app.component.second.component, second - 2000) == 6)
    test_check(cursor_at(app.component.first.component, first - 1000) == first_cursor)
    print("PASS cursor-only update leaves sibling unrendered; Tab and edits from either child preserve independent cursors")

    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(KeyEvent(KEY_C, MOD_COMMAND)))
    test_check(app.clipboard_text() == "Second")
    commits = app.component.commits
    a = app.component.first.component.renders
    b = app.component.second.component.renders
    _ = app.update(Event(KeyEvent(KEY_X, MOD_COMMAND)))
    test_check(app.component.name == "")
    test_check(occurrences(app.view, "Hello, ") == 2)
    test_check(app.component.commits == commits + 1)
    test_check(app.component.first.component.renders == a + 1)
    test_check(app.component.second.component.renders == b + 1)
    _ = app.update(Event(KeyEvent(KEY_V, MOD_COMMAND)))
    test_check(app.component.name == "Second")
    test_check(app.component.commits == commits + 2)
    test_check(cursor_at(app.component.second.component, second - 2000) == 6)
    replace[SettledNames](app, first, "λ🙂")
    test_check(occurrences(app.view, "Hello, λ🙂") == 2)
    commits = app.component.commits
    a = app.component.first.component.renders
    b = app.component.second.component.renders
    _ = app.update(Event(CompositionEvent("に", 0, 1)))
    test_check(app.component.name == "λ🙂")
    test_check(app.component.commits == commits)
    test_check(app.component.first.component.renders == a + 1)
    test_check(app.component.second.component.renders == b)
    _ = app.update(Event(TextInputEvent("日")))
    test_check(app.component.name == "λ🙂日")
    test_check(occurrences(app.view, "Hello, λ🙂日") == 2)
    test_check(not app.component.first.component.root.has_request)
    test_check(not app.component.second.component.root.has_request)
    print("PASS shared empty value, App cut/paste, Unicode, synthetic composition and consumed requests")

    a = app.component.first.component.renders
    b = app.component.second.component.renders
    commits = app.component.commits
    app.rebuild()
    _ = app.resize(Rect(0, 0, 580, 650))
    _ = app.paint()
    test_check(app.component.first.component.renders == a)
    test_check(app.component.second.component.renders == b)
    test_check(app.component.commits == commits)
    var copy = app.component
    var event = Event(TextInputEvent("!"))
    event.set_target(first)
    _ = copy.update(event, app.view)
    test_check(copy.name == "λ🙂日!")
    test_check(app.component.name == "λ🙂日")
    print("PASS rebuild/resize/paint do not replay shared changes; copied components isolate parent and child state")
