"""Backend-neutral dirty-region tracking for incremental rendering."""

from .geometry import Rect


comptime INVALIDATE_NONE = 0
comptime INVALIDATE_CONTENT = 1
comptime INVALIDATE_LAYOUT = 2
comptime INVALIDATE_STRUCTURE = 4
comptime INVALIDATE_ACCESSIBILITY = 8
comptime INVALIDATE_ALL = 15


def union_rects(left: Rect, right: Rect) -> Rect:
    var x = left.x
    if right.x < x:
        x = right.x
    var y = left.y
    if right.y < y:
        y = right.y
    var right_edge = left.x + left.width
    if right.x + right.width > right_edge:
        right_edge = right.x + right.width
    var bottom_edge = left.y + left.height
    if right.y + right.height > bottom_edge:
        bottom_edge = right.y + right.height
    return Rect(x, y, right_edge - x, bottom_edge - y)


struct Invalidation(ImplicitlyCopyable):
    """A merged set of frame invalidation reasons and its dirty rectangle."""

    var flags: Int
    var bounds: Rect

    def __init__(out self):
        self.flags = INVALIDATE_NONE
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)

    def invalidate(mut self, flags: Int, bounds: Rect):
        """Merge a reason and region into the pending invalidation."""
        if flags == INVALIDATE_NONE:
            return
        if self.flags == INVALIDATE_NONE:
            self.bounds = bounds
        else:
            self.bounds = union_rects(self.bounds, bounds)
        self.flags |= flags

    def has(self, flag: Int) -> Bool:
        return (self.flags & flag) != 0

    def is_empty(self) -> Bool:
        return self.flags == INVALIDATE_NONE

    def clear(mut self):
        """Mark the pending region as consumed."""
        self.flags = INVALIDATE_NONE
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)

