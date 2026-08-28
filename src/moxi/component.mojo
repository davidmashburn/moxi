"""Value-based component contract for the current Moxi view surface."""

from .event import ClickEvent
from .geometry import Rect
from .view import ColumnView


trait Component(ImplicitlyCopyable):
    """Own state, build a lightweight view, and handle input."""

    def build(self, bounds: Rect) -> ColumnView:
        """Build the current declarative view tree."""
        ...

    def update(mut self, event: ClickEvent, view: ColumnView) -> Bool:
        """Handle an event and report whether the view needs rebuilding."""
        return False
