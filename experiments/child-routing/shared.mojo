"""One parent-owned name, two editors with explicit inputs and change requests.

This intentionally uses the previous HandlerHost unchanged. Its eager refresh
exposes the cost of settling a shared value after child event routing.
"""
from moxi import Component, ComponentSlot, ColumnView, Event, Rect
from runtime import HandlerHost, Screen, UI


struct NameEditor(Screen):
    var value: String
    var requested: String
    var has_request: Bool

    def __init__(out self, value: String):
        self.value = value
        self.requested = ""
        self.has_request = False

    def change(mut self, value: String):
        self.requested = value
        self.has_request = True

    def render(self, mut ui: UI[Self]):
        ui.text_input("Shared name", self.value, Self.change)
        ui.label("Hello, " + self.value)


struct SharedNames(Component):
    var name: String
    var commits: Int
    var first: ComponentSlot[HandlerHost[NameEditor]]
    var second: ComponentSlot[HandlerHost[NameEditor]]

    def __init__(out self):
        self.name = "Ada"
        self.commits = 0
        self.first = ComponentSlot[HandlerHost[NameEditor]](HandlerHost[NameEditor](NameEditor(self.name)), 10, 1000)
        self.second = ComponentSlot[HandlerHost[NameEditor]](HandlerHost[NameEditor](NameEditor(self.name)), 20, 2000)

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 12, 8)
        view.add_component_view_to(-1, self.first.slot_id, self.first.build(bounds), self.first.id_offset)
        view.add_component_view_to(-1, self.second.slot_id, self.second.build(bounds), self.second.id_offset)
        view.layout()
        return view^

    def settle(mut self):
        # One input event routes to one child. Empty strings are valid requests.
        if self.first.component.root.has_request:
            self.name = self.first.component.root.requested
            self.first.component.root.has_request = False
            self.commits += 1
        elif self.second.component.root.has_request:
            self.name = self.second.component.root.requested
            self.second.component.root.has_request = False
            self.commits += 1
        else:
            return
        if self.first.component.root.value != self.name:
            self.first.component.root.value = self.name
            self.first.component.refresh()
        if self.second.component.root.value != self.name:
            self.second.component.root.value = self.name
            self.second.component.refresh()

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        var changed = False
        if self.first.contains(event.target, view):
            changed = self.first.route(event, view)
        elif self.second.contains(event.target, view):
            changed = self.second.route(event, view)
        if changed:
            self.settle()
        return changed

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if self.first.contains(target, view):
            return self.first.clipboard_copy(target, view)
        return self.second.clipboard_copy(target, view)

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        var text: String
        if self.first.contains(target, view):
            text = self.first.clipboard_cut(target, view)
        else:
            text = self.second.clipboard_cut(target, view)
        self.settle()
        return text

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        var changed: Bool
        if self.first.contains(target, view):
            changed = self.first.clipboard_paste(target, text, view)
        else:
            changed = self.second.clipboard_paste(target, text, view)
        self.settle()
        return changed
