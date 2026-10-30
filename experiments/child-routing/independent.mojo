"""Two ordinary child components; no root-state handler forwarding."""
from moxi import Component, ComponentSlot, ColumnView, Event, Rect
from runtime import HandlerHost
from form import GreetingForm


struct IndependentForms(Component):
    var first: ComponentSlot[HandlerHost[GreetingForm]]
    var second: ComponentSlot[HandlerHost[GreetingForm]]
    var reverse: Bool

    def __init__(out self):
        self.first = ComponentSlot[HandlerHost[GreetingForm]](HandlerHost[GreetingForm](GreetingForm()), 10, 1000)
        self.second = ComponentSlot[HandlerHost[GreetingForm]](HandlerHost[GreetingForm](GreetingForm()), 20, 2000)
        self.reverse = False

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 12, 8)
        if self.reverse:
            view.add_component_view_to(-1, self.second.slot_id, self.second.build(bounds), self.second.id_offset)
            view.add_component_view_to(-1, self.first.slot_id, self.first.build(bounds), self.first.id_offset)
        else:
            view.add_component_view_to(-1, self.first.slot_id, self.first.build(bounds), self.first.id_offset)
            view.add_component_view_to(-1, self.second.slot_id, self.second.build(bounds), self.second.id_offset)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        # Target membership prevents an untargeted event being broadcast.
        if self.first.contains(event.target, view):
            return self.first.route(event, view)
        if self.second.contains(event.target, view):
            return self.second.route(event, view)
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if self.first.contains(target, view):
            return self.first.clipboard_copy(target, view)
        return self.second.clipboard_copy(target, view)

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if self.first.contains(target, view):
            return self.first.clipboard_cut(target, view)
        return self.second.clipboard_cut(target, view)

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        if self.first.contains(target, view):
            return self.first.clipboard_paste(target, text, view)
        return self.second.clipboard_paste(target, text, view)
