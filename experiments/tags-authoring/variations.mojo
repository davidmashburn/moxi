"""The same compiler handles source changes; no runtime changes between cases."""
from moxi import App, Event, KeyEvent, TextInputEvent, Rect, KEY_LEFT, test_check
from check import click, node, replace
from Validation import Validation
from Ownership import Ownership
from Lifecycle import Lifecycle
from Editors import Editors


def main():
    var validation = App[Validation](Validation(), Rect(0, 0, 520, 600))
    replace(validation, 2, "blocked")
    test_check(node(validation.view, 7).text == "Name required")
    test_check(not node(validation.view, 8).enabled)
    test_check(not click(validation, 8))
    replace(validation, 2, "allowed")
    test_check(node(validation.view, 8).enabled)
    _ = click(validation, 8)
    test_check(node(validation.view, 10).text == "Saved: allowed")
    print("PASS change validation once: preview and Save both follow it")

    var ownership = App[Ownership](Ownership(), Rect(0, 0, 520, 600))
    _ = click(ownership, 5)
    test_check(node(ownership.view, 5).text == "Clicked 1 times")
    test_check(node(ownership.view, 6).text == "Clicked 0 times")
    _ = click(ownership, 6)
    test_check(node(ownership.view, 5).text == "Clicked 1 times")
    test_check(node(ownership.view, 6).text == "Clicked 1 times")
    print("PASS change one prop from binding to initial value: counters become independent")

    var lifecycle = App[Lifecycle](Lifecycle(), Rect(0, 0, 520, 600))
    _ = click(lifecycle, 2)
    _ = click(lifecycle, 2)
    test_check(node(lifecycle.view, 2).text == "Clicked 2 times")
    _ = click(lifecycle, 1)
    test_check(lifecycle.view.child_count() == 1)
    _ = click(lifecycle, 1)
    test_check(node(lifecycle.view, 2).text == "Clicked 0 times")
    print("PASS move reusable counter into conditional: child local state resets on remount")

    var editors = App[Editors](Editors(), Rect(0, 0, 520, 600))
    _ = click(editors, 2)
    _ = editors.update(Event(KeyEvent(KEY_LEFT)))
    test_check(editors.component.editor2.cursor == 2)
    test_check(editors.component.editor4.cursor == 3)
    _ = editors.update(Event(TextInputEvent("x")))
    test_check(node(editors.view, 2).text == "Adxa")
    test_check(node(editors.view, 4).text == "Adxa")
    test_check(editors.focus_id() == 2)
    print("PASS share one text value between two child fields: text syncs, editor cursors stay separate")
    print("All authoring variation checks passed")
