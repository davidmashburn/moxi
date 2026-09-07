"""Shared typed component-slot scenario used by the demo and tests."""

from .app import COUNTER_INCREMENT_ACTION, CounterState
from .component import Component, ComponentSlot, KeyedSubtreeDescriptor
from .event import Event
from .geometry import Rect
from .layout import ALIGN_START
from .style import default_panel_style, default_surface_style
from .view import ColumnView


comptime COMPOSED_TITLE_ID = 1
comptime COMPOSED_COUNTER_SLOT_ID = 10
comptime COMPOSED_COUNTER_ID_OFFSET = 1000


struct ComposedState(Component):
    """A parent component that owns and routes to a typed counter child."""

    var counter: ComponentSlot[CounterState]
    var localized_child_bounds: Rect
    var localized_child_nodes: Int
    var localized_child_commands: Int
    var localized_initialized: Bool

    def __init__(out self):
        self.counter = ComponentSlot(
            CounterState(),
            KeyedSubtreeDescriptor(
                1,
                COMPOSED_COUNTER_SLOT_ID,
                1,
                1,
                COMPOSED_COUNTER_ID_OFFSET,
            ),
        )
        self.localized_child_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.localized_child_nodes = 0
        self.localized_child_commands = 0
        self.localized_initialized = False

    def child_bounds(self, bounds: Rect) -> Rect:
        """Return the counter slot's declared child bounds."""
        var child_width = bounds.width - 64.0
        var child_height = bounds.height - 88.0
        if child_width < 0.0:
            child_width = 0.0
        if child_height < 0.0:
            child_height = 0.0
        return Rect(
            bounds.x + 32.0,
            bounds.y + 72.0,
            child_width,
            child_height,
        )

    def refresh_localized_child(mut self, bounds: Rect):
        """Build the child once for a root/geometry change."""
        self.localized_child_bounds = self.child_bounds(bounds)
        self.localized_initialized = True

    def compose_localized_view(
        self,
        bounds: Rect,
        child: ColumnView,
    ) -> ColumnView:
        """Compose parent chrome around the keyed child view."""
        var root = ColumnView(bounds, 24.0, 12.0)
        var panel_width = bounds.width - 32.0
        var panel_height = bounds.height - 32.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(bounds.x + 16.0, bounds.y + 16.0, panel_width, panel_height),
            default_panel_style(),
        )
        root.set_cross_alignment(ALIGN_START)
        root.add_label(COMPOSED_TITLE_ID, "Typed component slot", 32.0)
        root.add_component_view_to(
            -1,
            COMPOSED_COUNTER_SLOT_ID,
            child,
            self.counter.id_offset,
        )
        root.set_action(
            self.counter.namespaced_id(3),
            COUNTER_INCREMENT_ACTION,
        )
        root.layout()
        return root^

    def supports_localized_execution(self) -> Bool:
        return True

    def localized_view(mut self, bounds: Rect) -> ColumnView:
        var child_bounds = self.child_bounds(bounds)
        if (
            not self.localized_initialized
            or self.localized_child_bounds.x != child_bounds.x
            or self.localized_child_bounds.y != child_bounds.y
            or self.localized_child_bounds.width != child_bounds.width
            or self.localized_child_bounds.height != child_bounds.height
        ):
            self.refresh_localized_child(bounds)
        var child = self.counter.build(self.localized_child_bounds)
        self.localized_child_nodes = child.child_count()
        self.localized_child_commands = self.localized_child_nodes
        return self.compose_localized_view(bounds, child)

    def localized_dispatch(mut self, event: Event, view: ColumnView) -> Int:
        if event.target == -1 or not self.counter.contains(event.target, view):
            return 0
        var changed = self.counter.route(event, view)
        if changed:
            var slot = self.localized_child_bounds
            for index in range(view.child_count()):
                var node = view.child(index)
                if node.id == COMPOSED_COUNTER_SLOT_ID:
                    slot = node.bounds
                    break
            self.localized_child_bounds = slot
            return 2
        return 1

    def localized_last_child_nodes(self) -> Int:
        return self.localized_child_nodes

    def localized_last_child_commands(self) -> Int:
        return self.localized_child_commands

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 24.0, 12.0)
        var panel_width = bounds.width - 32.0
        var panel_height = bounds.height - 32.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(bounds.x + 16.0, bounds.y + 16.0, panel_width, panel_height),
            default_panel_style(),
        )
        root.set_cross_alignment(ALIGN_START)
        root.add_label(COMPOSED_TITLE_ID, "Typed component slot", 32.0)
        root.add_component_view_to(
            -1,
            COMPOSED_COUNTER_SLOT_ID,
            self.counter.build(self.child_bounds(bounds)),
            self.counter.id_offset,
        )
        root.set_action(
            self.counter.namespaced_id(3),
            COUNTER_INCREMENT_ACTION,
        )
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Give targeted events to the child while preserving parent ownership."""
        return self.counter.route(event, view)

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        return self.counter.clipboard_copy(target, view)

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        return self.counter.clipboard_cut(target, view)

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        return self.counter.clipboard_paste(target, text, view)
