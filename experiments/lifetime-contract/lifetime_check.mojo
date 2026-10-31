"""Behavioral checks for value updates versus explicit new lifetimes."""
from adapters import Keyed
from bindings import Action
from domain import Services
from runtime import Pane, Screen, UI, HandlerHost, require, deliver, reset, update_model
from moxi import (App, Rect, Event, ActionEvent, TextInputEvent,
                  CompositionEvent, Point, ClickEvent, KeyEvent, KEY_HOME, KEY_RIGHT,
                  MOD_SHIFT, BUTTON_KIND, TEXT_INPUT_VIEW_KIND)


struct Editor(Pane):
    comptime Context = Services
    var count: Int
    var text: String
    def __init__(out self):
        self.count = 0
        self.text = "draft"
    def increment(mut self):
        self.count += 1
    def set_text(mut self, text: String):
        self.text = text
    def render(self, mut ui: UI[Self, Self.Context], context: Self.Context):
        ui.button("Increment", Self.increment)
        ui.text_input("Draft", self.text, Self.set_text)


struct Root(Screen):
    var children: Keyed[Editor]
    var services: Services
    def __init__(out self):
        self.children = Keyed[Editor]()
        _ = self.children.append(Editor())
        self.services = Services()
    def route(mut self, key: Int, action: Action[Keyed[Editor], Services]):
        action(self.children, self.services)
    def render(self, mut ui: UI[Self]):
        ui.child(self.children, self.services, Self.route, key=1)
    def replace_values(mut self):
        self.children.entries[0].value = Editor()
    def reset_children(mut self):
        self.children.reset()
        _ = self.children.append(Editor())
    def assign_collection(mut self):
        self.children = Keyed[Editor]()
        _ = self.children.append(Editor())


def target(app: App[HandlerHost[Root]], kind: Int = BUTTON_KIND) -> Int:
    for item in app.component.ui.controls:
        if item.active and item.kind == kind:
            return item.id
    require(False, "missing control")
    return -1


def event(id: Int) -> Event:
    var result = Event(ActionEvent(id))
    result.set_target(id)
    return result


def refresh(mut app: App[HandlerHost[Root]]):
    app.component.refresh()
    app.rebuild()


def replace_values(mut root: Root):
    root = Root()


def count(app: App[HandlerHost[Root]]) -> Int:
    return app.component.root.children.entries[0].value.count


def editing(mut app: App[HandlerHost[Root]]):
    var input = target(app, TEXT_INPUT_VIEW_KIND)
    var bounds = app.view.bounds_for(input)
    _ = app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))
    require(app.focus_id() == input, "focus editor")
    var home = Event(KeyEvent(KEY_HOME))
    home.set_target(input)
    _ = app.update(home)
    var select = Event(KeyEvent(KEY_RIGHT, MOD_SHIFT))
    select.set_target(input)
    _ = app.update(select)
    var composition = Event(CompositionEvent("pending", 1, 3))
    composition.set_target(input)
    require(deliver(app, app.component.queue(composition)), "start IME")
    var i = app.component.ui.index(input)
    require(app.component.ui.controls[i].editor.cursor != app.component.ui.controls[i].editor.anchor, "nonempty selection")


def assignment():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var button = target(app)
    var captured = app.component.capture(button)
    var queued = app.component.queue(event(button))
    editing(app)
    var input = target(app, TEXT_INPUT_VIEW_KIND)
    var state = app.component.ui.controls[app.component.ui.index(input)].editor
    app.component.root.replace_values()
    refresh(app)
    require(deliver(app, captured), "value assignment keeps action")
    require(deliver(app, queued), "value assignment keeps event")
    require(count(app) == 2, "actions reach assigned values")
    replace_values(app.component.root)
    refresh(app)
    require(deliver(app, captured) and deliver(app, queued), "whole root assignment keeps identity")
    require(count(app) == 2, "whole root current values")
    require(target(app, TEXT_INPUT_VIEW_KIND) == input and app.focus_id() == input, "assignment preserves ID/focus")
    var current = app.component.ui.controls[app.component.ui.index(input)].editor
    require(current.cursor == state.cursor and current.anchor == state.anchor, "assignment preserves selection")
    require(current.composition == state.composition and current.composition_selection_start == state.composition_selection_start and current.composition_selection_end == state.composition_selection_end, "assignment preserves IME")
    print("PASS assignment preserves current-owner delivery, focus, selection and IME")


def collection_reset():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var button = target(app)
    var captured = app.component.capture(button)
    var queued = app.component.queue(event(button))
    var old_key = app.component.root.children.entries[0].key
    var old_input = target(app, TEXT_INPUT_VIEW_KIND)
    var text = Event(TextInputEvent("stale text", 0, 1000000))
    text.set_target(old_input)
    var queued_text = app.component.queue(text)
    var ime = Event(CompositionEvent("stale IME", 1, 2))
    ime.set_target(old_input)
    var queued_ime = app.component.queue(ime)
    editing(app)
    update_model(app, Root.reset_children)
    require(count(app) == 0, "collection reset publishes a new owner before delivery")
    require(not deliver(app, captured) and not deliver(app, queued), "collection reset rejects old delivery after refresh")
    require(app.component.root.children.entries[0].key != old_key, "reset keeps allocator")
    require(not deliver(app, queued_text) and not deliver(app, queued_ime), "old text and IME cannot reach new child")
    require(app.component.root.children.entries[0].value.text == "draft", "stale editor payloads leave new value intact")
    require(app.focus_id() == target(app), "collection reset uses normal fresh-view autofocus")
    var input = target(app, TEXT_INPUT_VIEW_KIND)
    require(not app.component.ui.controls[app.component.ui.index(input)].editor.has_composition(), "collection reset discards IME")
    require(deliver(app, app.component.queue(event(target(app)))), "fresh collection event")
    require(count(app) == 1, "fresh collection owner")
    # Explicitly characterize assignment as same identity, even for Keyed values.
    var no_target = app.component.queue(Event(TextInputEvent("must not follow new focus")))
    require(not deliver(app, no_target), "unresolved queued input is rejected")
    var key = Event(KeyEvent(KEY_RIGHT))
    key.set_target(target(app, TEXT_INPUT_VIEW_KIND))
    require(not deliver(app, app.component.queue(key)), "focus-rerouted key input is rejected")
    var second = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var same = second.component.capture(target(second))
    second.component.root.assign_collection()
    refresh(second)
    require(deliver(second, same) and count(second) == 1, "collection assignment is not reset")
    print("PASS collection reset allocates fresh keys; assignment retains same identity")


def root_reset():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app)
    var captured = app.component.capture(old_id)
    var queued = app.component.queue(event(old_id))
    editing(app)
    reset(app, Root())
    require(not deliver(app, captured) and not deliver(app, queued), "root reset rejects captured work")
    require(not app.update(event(old_id)), "root reset also rejects old raw ID")
    require(count(app) == 0 and target(app) > old_id, "new root with fresh IDs")
    require(app.focus_id() == target(app), "root reset uses normal fresh-view autofocus")
    var input = target(app, TEXT_INPUT_VIEW_KIND)
    require(not app.component.ui.controls[app.component.ui.index(input)].editor.has_composition(), "root reset clears IME")
    require(deliver(app, app.component.capture(target(app))), "new root action")
    require(deliver(app, app.component.queue(event(target(app)))), "new root event")
    require(count(app) == 2, "new root receives fresh work")
    var live_records = len(app.component.ui.controls)
    require(live_records == 5, "two scopes and three leaf declarations")
    for _ in range(100):
        reset(app, Root())
        require(not deliver(app, captured) and not deliver(app, queued), "stale work stays invalid through churn")
        require(len(app.component.ui.controls) == live_records, "root reset bounds records")
    print("PASS root reset rejects stale work, clears editing state, bounds records")


def hosts_and_copies():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var captured = app.component.capture(target(app))
    var queued = app.component.queue(event(target(app)))
    var another = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    require(target(another) == target(app), "deliberate numeric ID reuse")
    editing(another)
    var input = target(another, TEXT_INPUT_VIEW_KIND)
    require(not deliver(another, captured) and not deliver(another, queued), "foreign host work rejected")
    require(count(another) == 0 and another.focus_id() == input, "foreign work cannot mutate or steal focus")
    require(deliver(app, captured) and deliver(app, queued) and count(app) == 2, "original host remains live")
    var copied = App(app.component, Rect(0, 0, 600, 900))
    require(not deliver(copied, captured) and not deliver(copied, queued), "host copy has an independent delivery scope")
    require(deliver(copied, copied.component.capture(target(copied))), "copy captures its own action")
    require(count(copied) == 3 and count(app) == 2, "copy's own action uses current copy values")
    reset(copied, Root())
    require(not deliver(copied, captured) and not deliver(copied, queued), "reset copy forks identity")
    require(deliver(app, captured) and count(app) == 3, "copy reset leaves original scope live")
    # Raw events cannot prove provenance and remain a deliberate negative control.
    require(another.update(event(target(app))) and count(another) == 1, "raw cross-host event remains unsafe")
    print("PASS host provenance, deliberate ID reuse, independent copy reset; raw event limit visible")


def main():
    assignment()
    collection_reset()
    root_reset()
    hosts_and_copies()
