"""Deterministic geometry contracts for the first Moxi layout pass."""

from .geometry import Rect


comptime COLUMN_AXIS = 0
comptime ROW_AXIS = 1

comptime ALIGN_START = 0
comptime ALIGN_CENTER = 1
comptime ALIGN_END = 2
comptime ALIGN_STRETCH = 3

comptime JUSTIFY_START = 0
comptime JUSTIFY_CENTER = 1
comptime JUSTIFY_END = 2
comptime JUSTIFY_SPACE_BETWEEN = 3

# Container modes are deliberately small value-level contracts. A container
# still lives in the same flat view tree, but its layout policy is explicit so
# platform adapters do not need to understand a particular widget toolkit.
comptime LAYOUT_LINEAR = 0
comptime LAYOUT_STACK = 1
comptime LAYOUT_GRID = 2
comptime LAYOUT_SPLIT = 3
comptime LAYOUT_PORTAL = 4


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


struct RowLayout(ImplicitlyCopyable):
    """A simple horizontal layout with uniform padding and spacing."""

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

    def content_height(self) -> Float32:
        var height = self.bounds.height - self.padding * 2.0
        if height < 0.0:
            return 0.0
        return height

    def child_rect(self, left: Float32, width: Float32) -> Rect:
        return Rect(
            left,
            self.bounds.y + self.padding,
            width,
            self.content_height(),
        )
