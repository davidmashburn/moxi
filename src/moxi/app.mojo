"""Small state/update/view composition used by the first interactive demo."""

from .event import ClickEvent
from .view import Button, CounterView


struct CounterState:
    """Application state for the interactive counter scenario."""

    var count: Int

    def __init__(out self):
        self.count = 0

    def update(mut self, event: ClickEvent, button: Button):
        """Increment when a click lands inside the button bounds."""
        if button.bounds.contains(event.position):
            self.count += 1

    def view(self) -> CounterView:
        """Regenerate the lightweight declarative view from current state."""
        return CounterView(self.count)
