"""Deterministic geometry contracts for the first Moxi layout pass."""

from .geometry import Rect


struct ColumnLayout(ImplicitlyCopyable):
    """A simple vertical layout with uniform padding and spacing."""

    var bounds: Rect
    var padding: Float32
    var spacing: Float32

    def __init__(
        out self,
        bounds: Rect,
        padding: Float32,
        spacing: Float32,
    ):
        self.bounds = bounds
        self.padding = padding
        self.spacing = spacing

    def content_width(self) -> Float32:
        var width = self.bounds.width - self.padding * 2.0
        if width < 0.0:
            return 0.0
        return width

    def child_rect(self, top: Float32, height: Float32) -> Rect:
        return Rect(
            self.bounds.x + self.padding,
            top,
            self.content_width(),
            height,
        )
