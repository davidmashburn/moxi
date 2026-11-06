"""Authoring lessons inside the existing Component-based Playground."""
from moxi import (App, Rect, Event, FocusEvent, TextInputEvent, CompositionEvent,
    KeyEvent, KEY_END, KEY_LEFT, KEY_TAB, KEY_ENTER, MOD_SHIFT, MOD_COMMAND,
    KEY_C, KEY_X, KEY_V, TEXT_INPUT_VIEW_KIND, BUTTON_KIND, ActionEvent,
    ACTION_PRESS, Point, ScrollEvent, MemoryClipboard, test_check)
from moxi_demo import (DemoBrowserState, DEMO_TAB_DEMO, DEMO_FORM_ID,
    DEMO_COUNTER_ID, DEMO_EDITORS_ID, DEMO_SHARED_ID, DEMO_WORKSPACE_ID,
    DEMO_ENTRY_VIEW_BASE, DEMO_RESET_BUTTON_ID, DEMO_CONTENT_PORTAL_ID)
from moxi_demo.demo_browser import (DEMO_FORM_ID_OFFSET, DEMO_COUNTER_ID_OFFSET,
    DEMO_EDITORS_ID_OFFSET, DEMO_WORKSPACE_SLOT_ID,
    DEMO_STORY_PREVIEW_ID, DEMO_STORY_CODE_ID)


def require(condition: Bool, message: String):
    if not condition:
        print("FAIL:", message)
    test_check(condition)


def action(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event


def target(app: App[DemoBrowserState], kind: Int, label: String, occurrence: Int = 0) -> Int:
    var found = 0
    for i in range(app.view.child_count()):
        var item = app.view.child(i)
        if item.kind == kind and (item.text == label or item.semantics.label == label):
            if found == occurrence:
                return item.id
            found += 1
    return -1


def select(mut app: App[DemoBrowserState], page: Int):
    app.component.selected_id = page
    app.component.tab = DEMO_TAB_DEMO
    app.rebuild()


def main() raises:
    var app = App(DemoBrowserState(), Rect(0, 0, 1180, 760))
    select(app, DEMO_FORM_ID)
    var input = target(app, TEXT_INPUT_VIEW_KIND, "Name")
    var submit = target(app, BUTTON_KIND, "Submit")
    require(input > 0 and submit > 0, "input > 0 and submit > 0")
    for i in range(app.view.child_count()):
        var item = app.view.child(i)
        if item.id == input:
            require(item.semantics.label == "Name", "item.semantics.label == \"Name\"")
            require(item.semantics.hint == "Enter your name", "item.semantics.hint == \"Enter your name\"")
    require(app.dispatch(Event(FocusEvent(input))), "app.dispatch(Event(FocusEvent(input)))")
    require(app.dispatch(Event(TextInputEvent("Moxi🙂"))), "app.dispatch(Event(TextInputEvent(\"Moxi🙂\")))")
    require(app.component.form.component.root.name == "Moxi🙂", "app.component.form.component.root.name == \"Moxi🙂\"")
    _ = app.dispatch(Event(KeyEvent(KEY_END)))
    require(app.dispatch(Event(KeyEvent(KEY_LEFT, MOD_SHIFT))), "app.dispatch(Event(KeyEvent(KEY_LEFT, MOD_SHIFT)))")
    var clipboard = MemoryClipboard()
    _ = app.dispatch_with_clipboard(Event(KeyEvent(KEY_C, MOD_COMMAND)), clipboard)
    require(clipboard.text == "🙂", "clipboard.text == \"🙂\"")
    require(app.dispatch_with_clipboard(Event(KeyEvent(KEY_X, MOD_COMMAND)), clipboard), "app.dispatch_with_clipboard(Event(KeyEvent(KEY_X, MOD_COMMAND)), clipboard)")
    require(app.component.form.component.root.name == "Moxi", "app.component.form.component.root.name == \"Moxi\"")
    require(app.dispatch_with_clipboard(Event(KeyEvent(KEY_V, MOD_COMMAND)), clipboard), "app.dispatch_with_clipboard(Event(KeyEvent(KEY_V, MOD_COMMAND)), clipboard)")
    require(app.component.form.component.root.name == "Moxi🙂", "app.component.form.component.root.name == \"Moxi🙂\"")
    require(app.dispatch(Event(CompositionEvent("かな", 1, 2))), "app.dispatch(Event(CompositionEvent(\"\u304b\u306a\", 1, 2)))")
    var local_input = input - DEMO_FORM_ID_OFFSET
    var index = app.component.form.component.ui.index(local_input)
    require(app.component.form.component.ui.controls[index].editor.composition == "かな", "app.component.form.component.ui.controls[index].editor.composition == \"\u304b\u306a\"")
    require(app.component.form.component.root.name == "Moxi🙂", "app.component.form.component.root.name == \"Moxi🙂\"")
    # Leaving and remounting retains editor selection/composition and values.
    select(app, DEMO_COUNTER_ID)
    var old_text = Event(TextInputEvent("hidden"))
    old_text.set_target(input)
    require(not app.dispatch(old_text), "not app.dispatch(old_text)")
    select(app, DEMO_FORM_ID)
    require(target(app, TEXT_INPUT_VIEW_KIND, "Name") == input, "target(app, TEXT_INPUT_VIEW_KIND, \"Name\") == input")
    require(app.component.form.component.ui.controls[index].editor.composition == "かな", "app.component.form.component.ui.controls[index].editor.composition == \"\u304b\u306a\"")
    require(app.dispatch(Event(FocusEvent(input))), "app.dispatch(Event(FocusEvent(input)))")
    require(app.dispatch(Event(KeyEvent(KEY_TAB))), "app.dispatch(Event(KeyEvent(KEY_TAB)))")
    require(app.focus_id() == submit, "app.focus_id() == submit")
    require(app.dispatch(Event(KeyEvent(KEY_ENTER))), "app.dispatch(Event(KeyEvent(KEY_ENTER)))")
    require(app.component.form.component.root.submissions == 1, "app.component.form.component.root.submissions == 1")
    var captured = app.component.form.component.capture(submit - DEMO_FORM_ID_OFFSET)
    require(app.dispatch(action(DEMO_RESET_BUTTON_ID)), "app.dispatch(action(DEMO_RESET_BUTTON_ID))")
    require(app.component.form.component.root.name == "", "app.component.form.component.root.name == \"\"")
    require(app.component.form.component.root.submissions == 0, "app.component.form.component.root.submissions == 0")
    require(not app.component.form.component.deliver_action(captured), "not app.component.form.component.deliver_action(captured)")
    require(not app.dispatch(old_text), "not app.dispatch(old_text)")
    require(not app.dispatch(action(submit)), "not app.dispatch(action(submit))")
    require(target(app, TEXT_INPUT_VIEW_KIND, "Name") != input, "target(app, TEXT_INPUT_VIEW_KIND, \"Name\") != input")

    select(app, DEMO_EDITORS_ID)
    input = target(app, TEXT_INPUT_VIEW_KIND, "Draft")
    require(app.dispatch(Event(FocusEvent(input))), "app.dispatch(Event(FocusEvent(input)))")
    _ = app.dispatch(Event(KeyEvent(KEY_END)))
    require(app.dispatch(Event(TextInputEvent(" edited"))), "app.dispatch(Event(TextInputEvent(\" edited\")))")
    require(app.dispatch(Event(KeyEvent(KEY_LEFT, MOD_SHIFT))), "app.dispatch(Event(KeyEvent(KEY_LEFT, MOD_SHIFT)))")
    var editor_index = app.component.editors.component.ui.index(input - DEMO_EDITORS_ID_OFFSET)
    var before = app.component.editors.component.ui.controls[editor_index].editor
    require(app.dispatch(action(target(app, BUTTON_KIND, "Reverse"))), "app.dispatch(action(target(app, BUTTON_KIND, \"Reverse\")))")
    require(app.component.editors.component.root.editors.entries[1].value.draft == "First edited", "app.component.editors.component.root.editors.entries[1].value.draft == \"First edited\"")
    editor_index = app.component.editors.component.ui.index(input - DEMO_EDITORS_ID_OFFSET)
    require(app.component.editors.component.ui.controls[editor_index].editor.cursor == before.cursor, "app.component.editors.component.ui.controls[editor_index].editor.cursor == before.cursor")
    require(app.component.editors.component.ui.controls[editor_index].editor.anchor == before.anchor, "app.component.editors.component.ui.controls[editor_index].editor.anchor == before.anchor")
    require(app.dispatch(action(target(app, BUTTON_KIND, "New drafts"))), "app.dispatch(action(target(app, BUTTON_KIND, \"New drafts\")))")
    require(not app.dispatch(Event(FocusEvent(input))), "not app.dispatch(Event(FocusEvent(input)))")

    select(app, DEMO_SHARED_ID)
    input = target(app, TEXT_INPUT_VIEW_KIND, "Local draft")
    require(app.dispatch(Event(FocusEvent(input))), "app.dispatch(Event(FocusEvent(input)))")
    _ = app.dispatch(Event(KeyEvent(KEY_END)))
    require(app.dispatch(Event(TextInputEvent(" changed"))), "app.dispatch(Event(TextInputEvent(\" changed\")))")
    require(app.dispatch(action(target(app, BUTTON_KIND, "Apply"))), "app.dispatch(action(target(app, BUTTON_KIND, \"Apply\")))")
    require(app.component.shared.component.root.document.title == "Shared title changed", "app.component.shared.component.root.document.title == \"Shared title changed\"")
    require(app.component.shared.component.root.right.text == "Shared title", "app.component.shared.component.root.right.text == \"Shared title\"")
    require(app.dispatch(action(target(app, BUTTON_KIND, "Revert", 1))), "app.dispatch(action(target(app, BUTTON_KIND, \"Revert\", 1)))")
    require(app.component.shared.component.root.right.text == "Shared title changed", "app.component.shared.component.root.right.text == \"Shared title changed\"")

    select(app, DEMO_WORKSPACE_ID)
    var first_key = app.component.workspace.component.root.groups.entries[0].key
    var first_draft_key = app.component.workspace.component.root.groups.entries[0].value.drafts.entries[0].key
    require(app.dispatch(action(target(app, BUTTON_KIND, "Reverse groups"))), "app.dispatch(action(target(app, BUTTON_KIND, \"Reverse groups\")))")
    require(app.component.workspace.component.root.groups.entries[1].key == first_key, "app.component.workspace.component.root.groups.entries[1].key == first_key")
    require(app.component.workspace.component.root.groups.entries[1].value.drafts.entries[0].key == first_draft_key, "app.component.workspace.component.root.groups.entries[1].value.drafts.entries[0].key == first_draft_key")
    # The entire nested lesson must be reachable through the existing portal.
    require(app.view.scroll_max_offset(DEMO_CONTENT_PORTAL_ID) > 0, "app.view.scroll_max_offset(DEMO_CONTENT_PORTAL_ID) > 0")
    var portal = app.view.bounds_for(DEMO_CONTENT_PORTAL_ID)
    require(app.dispatch(Event(ScrollEvent(Point(portal.x + 5, portal.y + 5), Point(0, 10000)))), "app.dispatch(Event(ScrollEvent(Point(portal.x + 5, portal.y + 5), Point(0, 10000))))")
    var bottom_revert = target(app, BUTTON_KIND, "Revert", 3)
    require(app.view.is_focusable(bottom_revert), "app.view.is_focusable(bottom_revert)")
    require(app.dispatch(action(bottom_revert)), "app.dispatch(action(bottom_revert))")

    # Tall lessons use the outer portal alone, and narrow previews stack
    # above their source instead of squeezing the editable fields.
    for width in [1180, 900]:
        _ = app.resize(Rect(0, 0, Float32(width), 760))
        require(app.view.scroll_max_offset(DEMO_WORKSPACE_SLOT_ID) == 0,
                "Workspace must not add an inner scrollbar")
        require(app.view.scroll_max_offset(DEMO_STORY_PREVIEW_ID) == 0,
                "Preview must not add an inner scrollbar")
        var preview = app.view.bounds_for(DEMO_STORY_PREVIEW_ID)
        var code = app.view.bounds_for(DEMO_STORY_CODE_ID)
        if width == 900:
            require(code.y >= preview.y + preview.height,
                    "Narrow source panel must sit below the preview")
        else:
            require(code.x >= preview.x + preview.width,
                    "Wide source panel must sit beside the preview")

    # IDs remain disjoint after passing the old 1000-ID slot boundaries.
    for _ in range(250):
        var model = app.component.counter.component.root
        app.component.counter.component.reset_model(model)
    for control in app.component.counter.component.ui.controls:
        require(control.id > 1000, "control.id > 1000")
        for other in app.component.form.component.ui.controls:
            require(control.id + DEMO_COUNTER_ID_OFFSET != other.id + DEMO_FORM_ID_OFFSET, "control.id + DEMO_COUNTER_ID_OFFSET != other.id + DEMO_FORM_ID_OFFSET")
    app.rebuild()
    print("PASS embedded authoring editing, identity, clipboard, and scrolling")
