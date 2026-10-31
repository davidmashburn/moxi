from screen import Workbench
from runtime import HandlerHost, require
from moxi import App, Rect, Event, ActionEvent, TextInputEvent

def keyed_target(app: App[HandlerHost[Workbench]], key: Int, position: Int) -> Int:
    var path = "/k" + String(String(key).byte_length()) + ":" + String(key) + "/p" + String(position)
    for item in app.component.ui.controls:
        if item.active and item.path == path:
            return item.id
    require(False, "missing keyed control " + path)
    return -1

def root_toggle_target(app: App[HandlerHost[Workbench]]) -> Int:
    # Root controls are not under a keyed child. The label is not part of the
    # keyed path contract; the root button is the first root control.
    for item in app.component.ui.controls:
        if item.active and item.path == "/p0":
            return item.id
    require(False, "missing root toggle")
    return -1

def action(id: Int) -> Event:
    var event = Event(ActionEvent(id))
    event.set_target(id)
    return event

def main():
    var app = App(HandlerHost(Workbench()), Rect(0, 0, 800, 5000))
    require(not app.component.root.show_third, "third pane starts hidden")
    require(app.component.root.left.draft == "Ada", "left pane intact")
    require(app.component.root.right.draft == "Ada", "right pane intact")

    var toggle_id = root_toggle_target(app)
    require(app.update(action(toggle_id)), "show third pane")
    require(app.component.root.show_third, "third pane shown")
    var first_key = app.component.root.third_key()
    require(app.component.root.third.draft == "Ada", "third starts from current document")

    var third_note = keyed_target(app, first_key, 4)
    var note_event = Event(TextInputEvent("private note", 0, 1000000))
    note_event.set_target(third_note)
    require(app.update(note_event), "third note edit")
    require(app.component.root.third.note == "private note", "third note is private")
    require(app.component.root.services.document.name == "Ada", "note did not write document")

    var third_name = keyed_target(app, first_key, 2)
    var name_event = Event(TextInputEvent("Grace", 0, 1000000))
    name_event.set_target(third_name)
    require(app.update(name_event), "third draft edit")
    require(app.component.root.third.draft == "Grace", "third draft is private")
    require(app.component.root.left.draft == "Ada", "left pane remains private")
    require(app.component.root.right.draft == "Ada", "right pane remains private")
    require(app.component.root.services.document.name == "Ada", "draft did not write document")

    var settings_id = keyed_target(app, 4, 3)
    require(app.update(action(settings_id)), "change shared limit")
    require(app.component.root.services.settings.max_length == 3, "shared setting changed")
    var third_apply = keyed_target(app, first_key, 5)
    require(app.update(action(third_apply)), "third apply checks shared limit")
    require(app.component.root.third.error == "Name is too long", "third observes shared limit")
    require(app.component.root.services.document.name == "Ada", "limit rejected shared write")
    require(app.update(action(settings_id)), "restore shared limit")

    var permission_id = keyed_target(app, 4, 2)
    require(app.update(action(permission_id)), "disable shared permission")
    require(not app.component.root.services.settings.writable, "shared permission changed")
    require(not app.update(action(third_apply)), "third observes disabled Apply")
    require(app.component.root.services.document.name == "Ada", "permission rejected shared write")
    require(app.update(action(permission_id)), "restore shared permission")
    require(app.update(action(third_apply)), "third apply uses shared services")
    require(app.component.root.services.document.name == "Grace", "third applies to shared document")

    var unsaved = Event(TextInputEvent("Unsaved", 0, 1000000))
    unsaved.set_target(third_name)
    require(app.update(unsaved), "third unsaved draft")
    require(app.component.root.third.draft == "Unsaved", "third has state to discard")
    var retained = app.component.ui.controls[app.component.ui.index(third_name)].action.with_input("stale", False)
    require(app.update(action(toggle_id)), "hide third pane")
    require(not app.component.root.show_third, "third pane hidden")
    require(app.component.root.third.draft == "Grace", "hiding discards draft")
    require(app.component.root.third.note == "", "hiding discards note")

    require(app.update(action(toggle_id)), "show third pane again")
    var second_key = app.component.root.third_key()
    require(second_key != first_key, "show creates a new mount key")
    require(app.component.root.third.draft == "Grace", "new mount starts from current document")
    require(app.component.root.third.note == "", "new mount note is fresh")

    var context: NoneType = None
    retained(app.component.root, context)
    require(app.component.root.third.draft == "Grace", "retained callback cannot mutate new pane")
    var stale_event = Event(TextInputEvent("stale event"))
    stale_event.set_target(third_name)
    require(not app.update(stale_event), "old event is rejected")
    require(app.component.root.third.draft == "Grace", "old event cannot mutate new pane")

    print("PASS composition: private third editor, shared settings, hide/show remount, stale callback and event rejection")
