"""Exercise workspace ownership, reorder, close, reset, and root lifetimes."""
from workspace import Workspace, GROUPS, DRAFTS
from moxi import App, BUTTON_KIND, Event, Rect, TEXT_INPUT_VIEW_KIND, TextInputEvent, test_check
from moxi.authoring import HandlerHost, deliver, reset_headless
from moxi.authoring import Screen


comptime ROOT_ADD_GROUP = 1
comptime ROOT_REVERSE_GROUPS = 2
comptime ROOT_CLOSE_FIRST = 3
comptime GROUP_ADD_DRAFT = 1
comptime GROUP_CLOSE_FIRST = 2
comptime GROUP_REVERSE_DRAFTS = 3
comptime GROUP_RESET_DRAFTS = 4
comptime DRAFT_TEXT = 2
comptime DRAFT_APPLY = 3


def require(condition: Bool, message: String):
    if not condition:
        print("FAIL:", message)
    test_check(condition)


def scope(key: Int) -> String:
    var value = String(key)
    var path = String("/k", value.byte_length(), ":", value)
    return path^


def path_button_id[R: Screen & Deinitable](app: App[HandlerHost[R]], path: String) -> Int:
    for control in app.component.ui.controls:
        if control.active and control.kind == BUTTON_KIND and control.path == path:
            return control.id
    require(False, "expected button path " + path)
    return -1


def path_text_id[R: Screen & Deinitable](app: App[HandlerHost[R]], path: String) -> Int:
    for control in app.component.ui.controls:
        if control.active and control.kind == TEXT_INPUT_VIEW_KIND and control.path == path:
            return control.id
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


def check_add_operations():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var add_group = app.component.capture(root_button_id(app, ROOT_ADD_GROUP))
    require(deliver(app, add_group), "add group action")
    require(len(app.component.root.groups.entries) == 3, "new group is owned by workspace")
    require(app.component.root.groups.entries[2].key == 3, "new group gets a fresh key")

    var add_draft = app.component.capture(group_button_id(app, 1, GROUP_ADD_DRAFT))
    require(deliver(app, add_draft), "add draft action")
    require(len(app.component.root.groups.entries[0].value.drafts.entries) == 3, "new draft is owned by group")
    require(app.component.root.groups.entries[0].value.drafts.entries[2].key == 3, "new draft gets a fresh key")
    require(deliver(app, app.component.capture(group_button_id(app, 1, GROUP_REVERSE_DRAFTS))), "reverse three drafts")
    require(app.component.root.groups.entries[0].value.drafts.entries[0].key == 3, "reverse includes newest draft")
    require(app.component.root.groups.entries[0].value.drafts.entries[2].key == 1, "reverse moves first draft to end")
    require(deliver(app, app.component.capture(root_button_id(app, ROOT_REVERSE_GROUPS))), "reverse three groups")
    require(app.component.root.groups.entries[0].key == 3, "reverse includes newest group")
    require(app.component.root.groups.entries[2].key == 1, "reverse moves first group to end")


def check_local_apply_and_nested_reorder():
    var local = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var edit = Event(TextInputEvent("Alpha local", 0, 1000000))
    edit.set_target(draft_text_id(local, 1, 1))
    require(deliver(local, local.component.queue(edit)), "edit stays deliverable")
    require(local.component.root.document.title == "Shared title", "edit stays local until apply")
    require(local.component.root.groups.entries[0].value.drafts.entries[0].value.text == "Alpha local", "draft owns edit")
    require(deliver(local, local.component.capture(draft_apply_id(local, 1, 1))), "apply routes through group and draft")
    require(local.component.root.document.title == "Alpha local", "apply changes shared document")
    require(local.component.root.groups.entries[1].value.drafts.entries[0].value.text == "Beta first", "sibling draft stays local")

    var moved = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var apply = moved.component.capture(draft_apply_id(moved, 1, 1))
    var queued_edit = Event(TextInputEvent("Alpha after move", 0, 1000000))
    queued_edit.set_target(draft_text_id(moved, 1, 1))
    var pending = moved.component.queue(queued_edit)
    var reverse_groups = moved.component.capture(root_button_id(moved, ROOT_REVERSE_GROUPS))
    var reverse_drafts = moved.component.capture(group_button_id(moved, 1, GROUP_REVERSE_DRAFTS))
    require(deliver(moved, reverse_groups), "reorder groups")
    require(deliver(moved, reverse_drafts), "reorder drafts")
    require(deliver(moved, apply), "captured apply follows original draft")
    require(moved.component.root.document.title == "Alpha first", "captured apply uses original draft")
    require(deliver(moved, pending), "queued edit follows original draft")
    require(moved.component.root.groups.entries[1].key == 1, "original group moved with its key")
    require(moved.component.root.groups.entries[1].value.drafts.entries[1].key == 1, "original draft moved with its key")
    require(moved.component.root.groups.entries[1].value.drafts.entries[1].value.text == "Alpha after move", "moved draft receives queued edit")
    require(moved.component.root.groups.entries[1].value.drafts.entries[0].value.text == "Alpha second", "other draft stays independent")
    require(moved.component.root.groups.entries[0].value.drafts.entries[0].value.text == "Beta first", "other group stays independent")
    require(deliver(moved, apply), "captured apply remains usable after edit")
    require(moved.component.root.document.title == "Alpha after move", "captured apply reads current draft, not captured values")


def check_close_reset_and_reopen():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var old_apply = app.component.capture(draft_apply_id(app, 1, 1))
    var old_edit_event = Event(TextInputEvent("Closed draft", 0, 1000000))
    old_edit_event.set_target(draft_text_id(app, 1, 1))
    var old_edit = app.component.queue(old_edit_event)
    var surviving_apply = app.component.capture(draft_apply_id(app, 1, 2))
    var sibling_apply = app.component.capture(draft_apply_id(app, 2, 1))
    var close = app.component.capture(group_button_id(app, 1, GROUP_CLOSE_FIRST))
    require(deliver(app, close), "close first draft")
    require(not deliver(app, old_apply), "closed draft rejects captured apply")
    require(not deliver(app, old_edit), "closed draft rejects queued edit")
    require(app.component.root.groups.entries[0].value.drafts.entries[0].key == 2, "second draft survives close")
    require(deliver(app, surviving_apply), "previously captured action survives sibling removal")
    require(app.component.root.document.title == "Alpha second", "surviving action still selects same draft")

    var sibling_event = Event(TextInputEvent("Sibling remains", 0, 1000000))
    sibling_event.set_target(draft_text_id(app, 2, 1))
    require(deliver(app, app.component.queue(sibling_event)), "sibling draft remains actionable")
    require(deliver(app, app.component.capture(draft_apply_id(app, 2, 1))), "sibling apply remains actionable")
    require(app.component.root.document.title == "Sibling remains", "sibling can update shared document")

    var add = app.component.capture(group_button_id(app, 1, GROUP_ADD_DRAFT))
    require(deliver(app, add), "reopen a draft")
    require(app.component.root.groups.entries[0].value.drafts.entries[1].key == 3, "reopened draft gets a fresh key")
    require(not deliver(app, old_apply), "old apply stays stale after reopen")
    require(not deliver(app, old_edit), "old edit stays stale after reopen")

    var reset_apply = app.component.capture(draft_apply_id(app, 1, 2))
    var reset_event = Event(TextInputEvent("Reset owner", 0, 1000000))
    reset_event.set_target(draft_text_id(app, 1, 2))
    var reset_edit = app.component.queue(reset_event)
    var reset = app.component.capture(group_button_id(app, 1, GROUP_RESET_DRAFTS))
    require(deliver(app, reset), "reset group drafts")
    require(not deliver(app, reset_apply), "reset owner rejects captured work")
    require(not deliver(app, reset_edit), "reset owner rejects queued work")
    require(app.component.root.groups.entries[0].value.drafts.entries[0].key == 4, "reset preserves keyed allocator")
    require(deliver(app, sibling_apply), "previously captured sibling survives group reset")
    require(app.component.root.document.title == "Sibling remains", "surviving sibling action uses current draft")



def check_group_removal():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var old_apply = app.component.capture(draft_apply_id(app, 1, 1))
    var old_group_action = app.component.capture(group_button_id(app, 1, GROUP_ADD_DRAFT))
    var event = Event(TextInputEvent("Removed group", 0, 1000000))
    event.set_target(draft_text_id(app, 1, 2))
    var old_edit = app.component.queue(event)
    var sibling_apply = app.component.capture(draft_apply_id(app, 2, 1))
    require(deliver(app, app.component.capture(root_button_id(app, ROOT_CLOSE_FIRST))), "close whole group")
    require(not deliver(app, old_apply), "removed group's draft action is stale")
    require(not deliver(app, old_group_action), "removed group's own action is stale")
    require(not deliver(app, old_edit), "removed group's draft input is stale")
    require(deliver(app, sibling_apply), "captured sibling survives group removal")
    require(app.component.root.document.title == "Beta first", "surviving group applies its own draft")
    require(deliver(app, app.component.capture(root_button_id(app, ROOT_ADD_GROUP))), "reopen group")
    require(app.component.root.groups.entries[1].key == 3, "reopened group has fresh owner key")
    require(app.component.root.groups.entries[1].value.drafts.entries[0].key == 1, "new group can reuse local draft key")
    require(not deliver(app, old_apply), "old apply cannot reach reopened group's same local key")
    require(not deliver(app, old_edit), "old input cannot reach reopened group's same local key")
    require(not deliver(app, old_group_action), "old group action cannot add a draft to reopened group")
    require(len(app.component.root.groups.entries[1].value.drafts.entries) == 2, "reopened group remains unchanged")
    require(deliver(app, app.component.capture(draft_apply_id(app, 3, 1))), "new group is actionable")
    require(app.component.root.document.title == "New first", "new group applies its own draft")


def check_root_reset():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    var old_apply = app.component.capture(draft_apply_id(app, 2, 1))
    var old_event = Event(TextInputEvent("Old root work", 0, 1000000))
    old_event.set_target(draft_text_id(app, 2, 1))
    var old_edit = app.component.queue(old_event)
    reset_headless(app, Workspace())
    require(not deliver(app, old_apply), "root reset rejects captured work")
    require(not deliver(app, old_edit), "root reset rejects queued work")
    require(app.component.root.document.title == "Shared title", "root reset installs fresh document")


def main():
    check_add_operations()
    check_local_apply_and_nested_reorder()
    check_close_reset_and_reopen()
    check_group_removal()
    check_root_reset()
    print("PASS: workspace ownership, nested reorder, close, reset, reopen, and root reset")
