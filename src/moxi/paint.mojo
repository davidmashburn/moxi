"""Backend-neutral paint commands."""

from .geometry import Rect


struct PaintCommand:
    """The first command emitted by the Moxi runtime."""

    var text: String
    var bounds: Rect

    def __init__(out self, text: String, bounds: Rect):
        self.text = text
        self.bounds = bounds


trait Renderer:
    """A platform backend consumes commands without owning view state."""

    def draw_label(self, command: PaintCommand):
        pass
