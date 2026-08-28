"""Small state/update/view composition used by the first interactive demo."""

from .component import Component
from .event import ClickEvent
from .geometry import Rect
from .view import Button, ColumnView, CounterView, make_counter_column


struct CounterState(Component):
    """A value-based component for the interactive counter scenario."""

    var count: Int

    def __init__(out self):
        self.count = 0

    def update(mut self, event: ClickEvent, button: Button):
        """Increment when a click lands inside the button bounds."""
        if button.bounds.contains(event.position):
            self.count += 1

    def update(mut self, event: ClickEvent, view: CounterView):
        """Increment when the composed view tree routes a click to the button."""
        if view.hit_test(event.position) == view.button.id:
            self.count += 1

    def update(mut self, event: ClickEvent, view: ColumnView) -> Bool:
        """Update the component and report whether its view must be rebuilt."""
        if view.hit_test(event.position) == 3:
            self.count += 1
            return True
        return False

    def build(self, bounds: Rect) -> ColumnView:
        """Build the current declarative view tree for this component."""
        return make_counter_column(self.count, bounds)

    def view(self) -> CounterView:
        """Regenerate the lightweight declarative view from current state."""
        return CounterView(self.count)
