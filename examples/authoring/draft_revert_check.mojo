"""Check shared-draft dirty status, current-title revert, and nested routing."""
from shared import Desk
from workspace import Workspace, GROUPS, DRAFTS
from moxi import App, BUTTON_KIND, Event, Rect, TEXT_INPUT_VIEW_KIND, TextInputEvent, test_check
from moxi.authoring import HandlerHost, Screen, deliver


comptime ROOT_REVERSE_GROUPS = 2
comptime GROUP_REVERSE_DRAFTS = 3
comptime DRAFT_TEXT = 2
comptime DRAFT_APPLY = 3
comptime DRAFT_REVERT = 4


def require(condition: Bool, message: String):
    if not condition:
        print("FAIL:", message)
    test_check(condition)


def control[R: Screen & Deinitable](app: App[HandlerHost[R]], kind: Int, ordinal: Int) -> Int:
    var seen = 0
    for item in app.component.ui.controls:
        if item.active and item.kind == kind:
            if seen == ordinal:
                return item.id
            seen += 1
    require(False, "expected control exists")
    return -1


def scope(key: Int) -> String:
    var value = String(key)
    var path = String("/k", value.byte_length(), ":", value)
    return path^


def path_button_id[R: Screen & Deinitable](app: App[HandlerHost[R]], path: String) -> Int:
    for item in app.component.ui.controls:
        if item.active and item.kind == BUTTON_KIND and item.path == path:
            return item.id
    require(False, "expected button path " + path)
    return -1


def path_text_id[R: Screen & Deinitable](app: App[HandlerHost[R]], path: String) -> Int:
    for item in app.component.ui.controls:
        if item.active and item.kind == TEXT_INPUT_VIEW_KIND and item.path == path:
            return item.id
    require(False, "expected text path " + path)
    return -1


def root_button_id[R: Screen & Deinitable](app: App[HandlerHost[R]], position: Int) -> Int:
    return path_button_id(app, "/p" + String(position))


def group_button_id[R: Screen & Deinitable](app: App[HandlerHost[R]], group_key: Int, position: Int) -> Int:
    var path = scope(GROUPS) + scope(group_key) + "/p" + String(position)
    return path_button_id(app, path)


def draft_control_path(group_key: Int, draft_key: Int, position: Int) -> String:
    var path = scope(GROUPS) + scope(group_key) + scope(DRAFTS) + scope(draft_key)
    path += "/p" + String(position)
    return path^


def draft_text_id[R: Screen & Deinitable](app: App[HandlerHost[R]], group_key: Int, draft_key: Int) -> Int:
    return path_text_id(app, draft_control_path(group_key, draft_key, DRAFT_TEXT))


def draft_apply_id[R: Screen & Deinitable](app: App[HandlerHost[R]], group_key: Int, draft_key: Int) -> Int:
    return path_button_id(app, draft_control_path(group_key, draft_key, DRAFT_APPLY))


def draft_revert_id[R: Screen & Deinitable](app: App[HandlerHost[R]], group_key: Int, draft_key: Int) -> Int:
    return path_button_id(app, draft_control_path(group_key, draft_key, DRAFT_REVERT))


def require_status[R: Screen & Deinitable](app: App[HandlerHost[R]], text: String, expected: Int):
    # Parent verification supplements the unfamiliar author's state checks with
    # rendered text. A sibling save must refresh readers of shared context.
    var found = 0
    for index in range(app.view.child_count()):
        if app.view.child(index).text == text:
            found += 1
    require(found == expected, "rendered status: " + text)


def check_shared_desk():
    var app = App(HandlerHost(Desk()), Rect(0, 0, 500, 400))
    require(not app.component.root.left.is_dirty(app.component.root.document), "left starts clean")
    require(not app.component.root.right.is_dirty(app.component.root.document), "right starts clean")

    require_status(app, "Saved: Shared title | Status: Clean", 2)

    var left_revert = app.component.capture(control(app, BUTTON_KIND, 1))
    var right_edit = Event(TextInputEvent("New title", 0, 1000000))
    right_edit.set_target(control(app, TEXT_INPUT_VIEW_KIND, 1))
    require(deliver(app, app.component.queue(right_edit)), "edit right local draft")
    require(app.component.root.document.title == "Shared title", "editing stays local")
    require(app.component.root.left.text == "Shared title", "left text is unchanged before apply")
    require(app.component.root.right.text == "New title", "right owns its edit")

    require_status(app, "Saved: Shared title | Status: Dirty", 1)
    require_status(app, "Saved: Shared title | Status: Clean", 1)

    var right_apply = app.component.capture(control(app, BUTTON_KIND, 2))
    require(deliver(app, right_apply), "apply right draft")
    require(app.component.root.document.title == "New title", "apply changes shared document")
    require(app.component.root.left.text == "Shared title", "apply does not change sibling text")
    require(app.component.root.left.is_dirty(app.component.root.document), "document change dirties sibling")

    require_status(app, "Saved: New title | Status: Dirty", 1)
    require_status(app, "Saved: New title | Status: Clean", 1)

    require(deliver(app, left_revert), "revert uses current shared title")
    require(app.component.root.document.title == "New title", "revert does not change document")
    require(app.component.root.left.text == "New title", "revert replaces local text")
    require(app.component.root.right.text == "New title", "revert does not change sibling draft")
    require(not app.component.root.left.is_dirty(app.component.root.document), "reverted draft is clean")
    require_status(app, "Saved: New title | Status: Clean", 2)


def check_nested_reorder():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var alpha_edit = Event(TextInputEvent("Shared title", 0, 1000000))
    alpha_edit.set_target(draft_text_id(app, 1, 1))
    require(deliver(app, app.component.queue(alpha_edit)), "edit nested draft")
    require(not app.component.root.groups.entries[0].value.drafts.entries[0].value.is_dirty(app.component.root.document), "nested draft starts clean")

    var alpha_revert = app.component.capture(draft_revert_id(app, 1, 1))
    var beta_edit = Event(TextInputEvent("Beta current", 0, 1000000))
    beta_edit.set_target(draft_text_id(app, 2, 2))
    require(deliver(app, app.component.queue(beta_edit)), "edit sibling nested draft")
    var beta_apply = app.component.capture(draft_apply_id(app, 2, 2))
    var reverse_groups = app.component.capture(root_button_id(app, ROOT_REVERSE_GROUPS))
    var reverse_drafts = app.component.capture(group_button_id(app, 1, GROUP_REVERSE_DRAFTS))
    require(deliver(app, reverse_groups), "reorder groups")
    require(deliver(app, reverse_drafts), "reorder drafts")
    require(deliver(app, beta_apply), "apply reordered sibling draft")
    require(app.component.root.document.title == "Beta current", "reordered apply changes document")
    require(app.component.root.groups.entries[1].value.drafts.entries[1].value.text == "Shared title", "reordered target text is unchanged")
    require(app.component.root.groups.entries[1].value.drafts.entries[1].value.is_dirty(app.component.root.document), "current document dirties reordered target")

    require(deliver(app, alpha_revert), "revert follows nested reorder")
    require(app.component.root.document.title == "Beta current", "nested revert does not change document")
    require(app.component.root.groups.entries[1].value.drafts.entries[1].value.text == "Beta current", "nested revert uses current title")
    require(app.component.root.groups.entries[0].value.drafts.entries[1].value.text == "Beta current", "nested revert leaves sibling text unchanged")
    require(not app.component.root.groups.entries[1].value.drafts.entries[1].value.is_dirty(app.component.root.document), "nested reverted draft is clean")


def main():
    check_shared_desk()
    check_nested_reorder()
    print("PASS: shared dirty status, current-title revert, and nested reorder")
