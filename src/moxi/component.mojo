"""Value-based component contract for the current Moxi view surface."""

from .event import Event
from .geometry import Rect
from .layout import ROW_AXIS
from .view import CONTAINER_KIND, ColumnView, ViewNode


trait Component(ImplicitlyCopyable):
    """Own state, build a lightweight view, and handle input."""

    def build(self, bounds: Rect) -> ColumnView:
        """Build the current declarative view tree."""
        ...

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Handle an event and report whether the view needs rebuilding."""
        return False

    def scroll_reset_target(self, event: Event) -> Int:
        """Return a scroll container that should return to its start."""
        return -1

    def intercepts_pointer(self, event: Event) -> Bool:
        """Return whether a component-owned layer owns this pointer stream."""
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        """Return text copied from a target, or an empty string if unsupported."""
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        """Return and remove text cut from a target, or an empty string."""
        return ""

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        """Paste text into a target and report whether the view changed."""
        return False


struct ComponentSlot[Child: Component & Deinitable](ImplicitlyCopyable):
    """Own one typed child component embedded in a parent's view tree.

    Child ids are namespaced when the child view is embedded. `route()` maps a
    namespaced event back to the child's original id and supplies a projected
    child view, so the child component remains unaware of its parent tree.
    """

    var component: Self.Child
    var slot_id: Int
    var id_offset: Int

    def __init__(
        out self,
        component: Self.Child,
        slot_id: Int,
        id_offset: Int,
    ):
        self.component = component
        self.slot_id = slot_id
        self.id_offset = id_offset

    def build(self, bounds: Rect) -> ColumnView:
        """Build the child view for the slot's current bounds."""
        return self.component.build(bounds)

    def contains(self, target: Int, view: ColumnView) -> Bool:
        """Return whether a namespaced target belongs to this slot."""
        if target == -1:
            return False
        var parent_id = -1
        var found = False
        for index in range(view.child_count()):
            var node = view.child(index)
            if node.id == target:
                parent_id = node.parent_id
                found = True
                break
        if not found:
            return False

        var hops = 0
        while parent_id != -1:
            if parent_id == self.slot_id:
                return True
            var parent_found = False
            var next_parent = -1
            for index in range(view.child_count()):
                var node = view.child(index)
                if node.id == parent_id:
                    next_parent = node.parent_id
                    parent_found = True
                    break
            if not parent_found:
                return False
            parent_id = next_parent
            hops += 1
            if hops > view.child_count():
                return False
        return False

    def project_view(self, view: ColumnView) -> ColumnView:
        """Project the parent tree back into the child's local id namespace."""
        var slot_node = ViewNode(CONTAINER_KIND, self.slot_id, "", 0.0)
        var found_slot = False
        for index in range(view.child_count()):
            var candidate = view.child(index)
            if candidate.id == self.slot_id and candidate.kind == CONTAINER_KIND:
                slot_node = candidate
                found_slot = True
                break
        if not found_slot:
            return ColumnView(Rect(0.0, 0.0, 0.0, 0.0), 0.0, 0.0)

        var local = ColumnView(
            slot_node.bounds,
            slot_node.container_padding,
            slot_node.container_spacing,
        )
        if slot_node.container_axis == ROW_AXIS:
            local.set_row_layout()
        local.set_main_alignment(slot_node.container_main_alignment)
        local.set_cross_alignment(slot_node.container_cross_alignment)

        for index in range(view.child_count()):
            var node = view.child(index)
            if node.id == self.slot_id or not self.contains(node.id, view):
                continue
            var nested = node
            nested.id -= self.id_offset
            if nested.parent_id == self.slot_id:
                nested.parent_id = -1
            else:
                nested.parent_id -= self.id_offset
            nested.semantics.id = nested.id
            nested.semantics.parent_id = nested.parent_id
            local.add(nested)
        local.layout()
        return local^

    def route(mut self, event: Event, view: ColumnView) -> Bool:
        """Route a parent event to the child component when it is targeted."""
        var local_target = -1
        if event.target != -1:
            if not self.contains(event.target, view):
                return False
            local_target = event.target - self.id_offset
        var routed = event
        routed.set_target(local_target)
        return self.component.update(routed, self.project_view(view))

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        """Delegate a copy request to a namespaced child target."""
        if target == -1 or not self.contains(target, view):
            return ""
        var local = self.project_view(view)
        return self.component.clipboard_copy(target - self.id_offset, local)

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        """Delegate a cut request to a namespaced child target."""
        if target == -1 or not self.contains(target, view):
            return ""
        var local = self.project_view(view)
        return self.component.clipboard_cut(target - self.id_offset, local)

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        """Delegate a paste request to a namespaced child target."""
        if target == -1 or not self.contains(target, view):
            return False
        var local = self.project_view(view)
        return self.component.clipboard_paste(
            target - self.id_offset,
            text,
            local,
        )
