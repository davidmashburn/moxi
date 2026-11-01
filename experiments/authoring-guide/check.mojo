"""Exercise the guide's promises through captured actions and targeted input."""
from counter import Counter
from editors import Workspace
from shared import Desk
from moxi import App, Event, Rect, TextInputEvent, BUTTON_KIND, TEXT_INPUT_VIEW_KIND
from runtime import HandlerHost, Screen, deliver, require, reset, update_model


def control[R: Screen & Deinitable](app: App[HandlerHost[R]], kind: Int, ordinal: Int) -> Int:
    var seen = 0
    for item in app.component.ui.controls:
        if item.active and item.kind == kind:
            if seen == ordinal:
                return item.id
            seen += 1
    require(False, "expected control exists")
    return -1


def replace_values(mut counter: Counter):
    counter = Counter()


def main():
    var counter = App(HandlerHost(Counter()), Rect(0, 0, 320, 200))
    var increment = counter.component.capture(control(counter, BUTTON_KIND, 0))
    require(deliver(counter, increment), "button invokes model method")
    require(counter.component.root.count == 1, "increment is visible")
    update_model(counter, replace_values)
    require(deliver(counter, increment), "assignment preserves lifetime")
    require(counter.component.root.count == 1, "old action uses current values")
    reset(counter, Counter())
    require(not deliver(counter, increment), "root reset rejects previous action")
    require(counter.component.root.count == 0, "rejected action cannot mutate new root")

    var editors = App(HandlerHost(Workspace()), Rect(0, 0, 400, 300))
    var first_id = control(editors, TEXT_INPUT_VIEW_KIND, 0)
    var edit = Event(TextInputEvent("Changed first", 0, 1000000))
    edit.set_target(first_id)
    var pending = editors.component.queue(edit)
    update_model(editors, Workspace.reverse)
    require(deliver(editors, pending), "queued edit follows entry through reorder")
    require(editors.component.root.editors.entries[1].value.draft == "Changed first", "original first changed")
    require(editors.component.root.editors.entries[0].value.draft == "Second", "other editor unchanged")
    update_model(editors, Workspace.new_drafts)
    require(not deliver(editors, pending), "collection reset retires old control")
    require(editors.component.root.editors.entries[1].value.draft == "New second", "new drafts unchanged")

    var desk = App(HandlerHost(Desk()), Rect(0, 0, 500, 400))
    var edit_left = Event(TextInputEvent("New title", 0, 1000000))
    edit_left.set_target(control(desk, TEXT_INPUT_VIEW_KIND, 0))
    require(deliver(desk, desk.component.queue(edit_left)), "edit left local draft")
    require(desk.component.root.document.title == "Shared title", "typing does not save")
    require(deliver(desk, desk.component.capture(control(desk, BUTTON_KIND, 0))), "apply left draft")
    require(desk.component.root.document.title == "New title", "route updates parent's document")
    require(desk.component.root.right.text == "Shared title", "other local draft remains private")
    print("PASS: counter, keyed editors, shared document, assignment and reset")
