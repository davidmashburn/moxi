"""High-level component lifecycle for mounting, updating, and rendering."""

from .component import Component
from .event import ClickEvent
from .geometry import Point, Rect
from .paint import PaintCommands, Renderer
from .runtime import ColumnRuntime
from .view import ColumnView


struct App[ComponentType: Component & Deinitable]:
    """Own a component, its current view, and its retained runtime."""

    var component: Self.ComponentType
    var root_bounds: Rect
    var view: ColumnView
    var runtime: ColumnRuntime

    def __init__(out self, component: Self.ComponentType, bounds: Rect):
        self.component = component
        self.root_bounds = bounds
        self.runtime = ColumnRuntime()
        self.view = self.component.build(bounds)
        self.runtime.reconcile(self.view)

    def update(mut self, event: ClickEvent) -> Bool:
        """Send an event through the component and rebuild when it changes."""
        if self.component.update(event, self.view):
            self.rebuild()
            return True
        return False

    def resize(mut self, bounds: Rect) -> Bool:
        """Update the root geometry and rebuild if the size changed."""
        if (
            self.root_bounds.x == bounds.x
            and self.root_bounds.y == bounds.y
            and self.root_bounds.width == bounds.width
            and self.root_bounds.height == bounds.height
        ):
            return False
        self.root_bounds = bounds
        self.rebuild()
        return True

    def rebuild(mut self):
        """Rebuild the declarative view and reconcile retained children."""
        self.view = self.component.build(self.root_bounds)
        self.runtime.reconcile(self.view)

    def paint(self) -> PaintCommands:
        """Return the current backend-neutral frame command stream."""
        return self.runtime.paint()

    def render[RendererType: Renderer](self, renderer: RendererType) raises:
        """Paint the current frame through any Moxi renderer."""
        var commands = self.paint()
        renderer.begin_frame()
        for index in range(commands.count()):
            renderer.draw(commands.command(index))

    def hit_test(self, position: Point) -> Int:
        """Return the button id under a point, or -1."""
        return self.runtime.hit_test(position)
