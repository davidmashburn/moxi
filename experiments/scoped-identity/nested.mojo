"""Typed keys in both route overloads, with nested reuse and current-owner copies."""
from bindings import Action
from mount_key import MountKey, key_path
from runtime import Pane, Screen, UI, HandlerHost, require
from moxi import App, Rect, Event, ActionEvent

comptime LEFT_SLOT = 1
comptime RIGHT_SLOT = 2
comptime LEAF_SLOT = 7

struct Services(ImplicitlyCopyable):
    var routes: Int
    def __init__(out self):
        self.routes = 0

struct Leaf(Pane):
    comptime Context = Services
    var count: Int
    def __init__(out self):
        self.count = 0
    def bump(mut self):
        self.count += 1
    def render(self, mut ui: UI[Self, Services], context: Services):
        ui.button("Bump", Self.bump)

struct Group(Pane):
    comptime Context = Services
    var leaf: Leaf
    var epoch: Int
    def __init__(out self):
        self.leaf = Leaf()
        self.epoch = 1
    def key(self) -> MountKey:
        return MountKey(LEAF_SLOT, self.epoch)
    def reset(mut self):
        self.epoch += 1
        self.leaf = Leaf()
    def route(mut self, mut context: Services, key: MountKey, action: Action[Leaf, Services]):
        if key == self.key():
            context.routes += 1
            action(self.leaf, context)
    def render(self, mut ui: UI[Self, Services], context: Services):
        ui.child(self.leaf, context, Self.route, key=self.key())

struct Root(Screen):
    var services: Services
    var left: Group
    var right: Group
    var reverse: Bool
    def __init__(out self):
        self.services = Services()
        self.left = Group()
        self.right = Group()
        self.reverse = False
    def reverse_children(mut self):
        self.reverse = True
    def reset_left(mut self):
        self.left.reset()
    def route_left(mut self, key: MountKey, action: Action[Group, Services]):
        if key == MountKey(LEFT_SLOT, 0):
            action(self.left, self.services)
    def route_right(mut self, key: MountKey, action: Action[Group, Services]):
        if key == MountKey(RIGHT_SLOT, 0):
            action(self.right, self.services)
    def render(self, mut ui: UI[Self]):
        if self.reverse:
            ui.child(self.right, self.services, Self.route_right, key=MountKey(RIGHT_SLOT, 0))
            ui.child(self.left, self.services, Self.route_left, key=MountKey(LEFT_SLOT, 0))
        else:
            ui.child(self.left, self.services, Self.route_left, key=MountKey(LEFT_SLOT, 0))
            ui.child(self.right, self.services, Self.route_right, key=MountKey(RIGHT_SLOT, 0))


def target(app: App[HandlerHost[Root]], path: String) -> Int:
    for item in app.component.ui.controls:
        if item.active and item.path == path:
            return item.id
    require(False, "missing nested target: " + path)
    return -1


def click(mut app: App[HandlerHost[Root]], id: Int) -> Bool:
    var event = Event(ActionEvent(id))
    event.set_target(id)
    return app.update(event)


def main():
    # Independent literals verify namespace encoding; the selectors below do
    # not call the implementation's path encoder.
    require(key_path(8) == "8", "legacy wire identity preserved")
    require(key_path(MountKey(8, 102)) == "m:8:102", "slot and generation separated")
    require(key_path(MountKey(81, 2)) != key_path(MountKey(8, 12)), "coordinate boundaries")
    require(key_path(MountKey(8, 0)) != key_path(8), "typed and legacy namespaces disjoint")
    require(MountKey(1, 2) != MountKey(2, 1), "coordinate order matters")
    require(MountKey(1, 2) == MountKey(1, 2), "equal mount identity")
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var left = target(app, "/k5:m:1:0/k5:m:7:1/p0")
    var right = target(app, "/k5:m:2:0/k5:m:7:1/p0")
    require(left != right, "same child slot/generation under different parents")
    require(click(app, left), "left event")
    require(app.component.root.left.leaf.count == 1, "left current owner")
    require(app.component.root.right.leaf.count == 0, "right isolation")
    require(app.component.root.services.routes == 1, "nested route receives current context")
    var retained = app.component.ui.controls[app.component.ui.index(left)].action
    app.component.root.reverse_children()
    app.component.refresh()
    app.rebuild()
    require(target(app, "/k5:m:1:0/k5:m:7:1/p0") == left, "reorder keeps left ID")
    require(target(app, "/k5:m:2:0/k5:m:7:1/p0") == right, "reorder keeps right ID")
    var copied_root = app.component.root
    var context: NoneType = None
    retained(copied_root, context)
    require(copied_root.left.leaf.count == 2, "descriptor reaches supplied copy")
    require(copied_root.services.routes == 2, "copied root supplies copied context")
    require(app.component.root.services.routes == 1, "original context unchanged")
    require(app.component.root.left.leaf.count == 1, "descriptor stores no original owner address")
    app.component.root.reset_left()
    app.component.refresh()
    app.rebuild()
    retained(app.component.root, context)
    require(app.component.root.left.leaf.count == 0, "nested generation rejects retained action")
    require(app.component.root.services.routes == 1, "rejected route leaves context unchanged")
    require(not click(app, left), "old nested event rejected")
    var fresh = target(app, "/k5:m:1:0/k5:m:7:2/p0")
    require(fresh != left, "remount allocates fresh control")
    require(click(app, fresh), "fresh nested event accepted")
    require(app.component.root.left.leaf.count == 1, "fresh nested action owner")
    require(click(app, right), "unaffected sibling still accepts its ID")
    print("PASS typed key encoding, both route overloads, nested reuse, reorder, current-owner copy, stale action/event rejection")
