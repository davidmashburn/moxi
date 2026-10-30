"""Shared state settles before rendering either child.

Deliberately parallel to shared.mojo for comparison; no production API changes.
"""
from moxi import Component, ComponentSlot, ColumnView, Event, Rect
from deferred import DeferredHost
from shared import NameEditor


struct SettledNames(Component):
    var name: String
    var commits: Int
    var first: ComponentSlot[DeferredHost[NameEditor]]
    var second: ComponentSlot[DeferredHost[NameEditor]]

    def __init__(out self):
        self.name = "Ada"
        self.commits = 0
        self.first = ComponentSlot[DeferredHost[NameEditor]](DeferredHost[NameEditor](NameEditor(self.name)), 10, 1000)
        self.second = ComponentSlot[DeferredHost[NameEditor]](DeferredHost[NameEditor](NameEditor(self.name)), 20, 2000)

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 12, 8)
        view.add_component_view_to(-1, self.first.slot_id, self.first.build(bounds), self.first.id_offset)
        view.add_component_view_to(-1, self.second.slot_id, self.second.build(bounds), self.second.id_offset)
        view.layout()
        return view^

    def settle(mut self, first_changed: Bool, second_changed: Bool):
        # One input event routes to one child. Empty strings are valid requests.
        if self.first.component.root.has_request:
            self.name = self.first.component.root.requested
            self.first.component.root.has_request = False
            self.commits += 1
        elif self.second.component.root.has_request:
            self.name = self.second.component.root.requested
            self.second.component.root.has_request = False
            self.commits += 1
        if first_changed or self.first.component.root.value != self.name:
            self.first.component.root.value = self.name
            self.first.component.refresh()
        if second_changed or self.second.component.root.value != self.name:
            self.second.component.root.value = self.name
            self.second.component.refresh()

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        var changed = False
        if self.first.contains(event.target, view):
            changed = self.first.route(event, view)
        elif self.second.contains(event.target, view):
            changed = self.second.route(event, view)
        if changed:
            self.settle(self.first.contains(event.target, view), self.second.contains(event.target, view))
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
        if text != "":
            self.settle(self.first.contains(target, view), self.second.contains(target, view))
        return text

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        var changed: Bool
        if self.first.contains(target, view):
            changed = self.first.clipboard_paste(target, text, view)
        else:
            changed = self.second.clipboard_paste(target, text, view)
        if changed:
            self.settle(self.first.contains(target, view), self.second.contains(target, view))
        return changed
