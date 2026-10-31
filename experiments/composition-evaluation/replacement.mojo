"""Characterize replacement as a NEW lifetime, separately from ordinary updates.

Known unsafe cases are asserted as counterexamples, not disguised as passing
safety checks. Every case checks both a retained descriptor and an old UI event.
"""
from adapters import Keyed
from domain import Services
from bindings import Action
from runtime import Pane, Screen, UI, HandlerHost, require
from moxi import App, Rect, Event, ActionEvent, BUTTON_KIND

comptime INITIAL_GENERATION = 1
comptime NEXT_GENERATION = 2


struct Counter(Pane):
    comptime Context = Services
    var count: Int
    def __init__(out self):
        self.count = 0
    def increment(mut self):
        self.count += 1
    def render(self, mut ui: UI[Self, Self.Context], context: Self.Context):
        ui.button("Increment", Self.increment)


struct Root(Screen):
    var services: Services
    var children: Keyed[Counter]
    var generation: Int
    def __init__(out self, generation: Int = INITIAL_GENERATION):
        self.services = Services()
        self.children = Keyed[Counter]()
        _ = self.children.append(Counter())
        self.generation = generation
    def reset_children(mut self):
        self.children = Keyed[Counter]()
        _ = self.children.append(Counter())
    def route(mut self, key: Int, action: Action[Keyed[Counter], Services]):
        if key == self.generation:
            action(self.children, self.services)
    def render(self, mut ui: UI[Self]):
        ui.child(self.children, self.services, Self.route, key=self.generation)


def replace_root(mut root: Root, generation: Int = INITIAL_GENERATION):
    root = Root(generation)


def target(app: App[HandlerHost[Root]]) -> Int:
    for item in app.component.ui.controls:
        if item.active and item.kind == BUTTON_KIND:
            return item.id
    require(False, "missing counter button")
    return -1


def event(id: Int) -> Event:
    var result = Event(ActionEvent(id))
    result.set_target(id)
    return result


def refresh(mut app: App[HandlerHost[Root]]):
    app.component.refresh()
    app.rebuild()


def check_old(mut app: App[HandlerHost[Root]], callback: Action[Root], old_id: Int,
              expect_callback_rejected: Bool, expect_event_rejected: Bool, name: String):
    var before = app.component.root.children.entries[0].value.count
    var context: NoneType = None
    callback(app.component.root, context)
    var callback_rejected = app.component.root.children.entries[0].value.count == before
    before = app.component.root.children.entries[0].value.count
    _ = app.update(event(old_id))
    var event_rejected = app.component.root.children.entries[0].value.count == before
    require(callback_rejected == expect_callback_rejected, name + " descriptor observation")
    require(event_rejected == expect_event_rejected, name + " queued event observation")
    var fresh_id = target(app)
    before = app.component.root.children.entries[0].value.count
    require(app.update(event(fresh_id)), "fresh event accepted")
    require(app.component.root.children.entries[0].value.count == before + 1, "fresh event reaches current state")
    print("CASE", name, "callback_rejected", callback_rejected, "event_rejected", event_rejected)


def case_0():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app)
    var callback = app.component.ui.controls[app.component.ui.index(old_id)].action
    # Control: an ordinary update preserves logical identity and old actions work.
    app.component.root.children.entries[0].value.count = 7
    refresh(app)
    check_old(app, callback, old_id, False, False, "same-owner-update")


def case_1():
    var app2 = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app2)
    var callback = app2.component.ui.controls[app2.component.ui.index(old_id)].action
    var old_key = app2.component.root.children.entries[0].key
    app2.component.root.children.remove(old_key)
    refresh(app2)
    var fresh_key = app2.component.root.children.append(Counter())
    require(fresh_key != old_key, "allocator survives remove/append")
    refresh(app2)
    check_old(app2, callback, old_id, True, True, "remove-append")


def case_2():
    var app3 = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app3)
    var callback = app3.component.ui.controls[app3.component.ui.index(old_id)].action
    app3.component.root.reset_children()
    refresh(app3)
    check_old(app3, callback, old_id, False, False, "replace-collection-reused-keys")


def case_3():
    var app4 = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app4)
    var callback = app4.component.ui.controls[app4.component.ui.index(old_id)].action
    replace_root(app4.component.root)
    refresh(app4)
    check_old(app4, callback, old_id, False, False, "replace-root-reused-generation")


def case_4():
    var app5 = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app5)
    var callback = app5.component.ui.controls[app5.component.ui.index(old_id)].action
    # A generation allocated outside the replaced owner works while the host lives.
    replace_root(app5.component.root, NEXT_GENERATION)
    refresh(app5)
    check_old(app5, callback, old_id, True, True, "replace-root-fresh-generation-same-host")


def case_5():
    var app6 = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old_id = target(app6)
    var callback = app6.component.ui.controls[app6.component.ui.index(old_id)].action
    # Reconstructing the entire host resets control IDs even with fresh model keys.
    var app7 = App(HandlerHost(Root(NEXT_GENERATION)), Rect(0, 0, 600, 900))
    check_old(app7, callback, old_id, True, False, "replace-entire-host-reuses-event-id")
    print("PASS 6 lifetime observations; unsafe cases remain explicit counterexamples")



def main():
    case_0()
    case_1()
    case_2()
    case_3()
    case_4()
    case_5()
