"""Reusable layout math independent of the view and platform layers."""

from .geometry import Rect


def clamp_fraction(value: Float32) -> Float32:
    """Clamp a split or progress fraction to the inclusive unit interval."""
    if value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


def split_extent(total: Float32, fraction: Float32, spacing: Float32) -> Float32:
    """Return the first pane extent after reserving the divider spacing."""
    var available = total - spacing
    if available < 0.0:
        available = 0.0
    return available * clamp_fraction(fraction)


struct GridCell(ImplicitlyCopyable):
    """One deterministic cell in a regular grid."""

    var row: Int
    var column: Int
    var bounds: Rect

    def __init__(out self, row: Int, column: Int, bounds: Rect):
        self.row = row
        self.column = column
        self.bounds = bounds


def grid_cell(
    bounds: Rect,
    index: Int,
    columns: Int,
    spacing: Float32,
) -> GridCell:
    """Place an item in an equal-sized grid cell.

    The helper intentionally leaves row height to the caller because a grid
    container may choose a viewport height, intrinsic height, or an explicit
    constraint. The default view implementation uses equal rows.
    """
    var safe_columns = columns
    if safe_columns < 1:
        safe_columns = 1
    var row = index // safe_columns
    var column = index % safe_columns
    var width = bounds.width - spacing * Float32(safe_columns - 1)
    if width < 0.0:
        width = 0.0
    width = width / Float32(safe_columns)
    return GridCell(row, column, Rect(0.0, 0.0, width, 0.0))


struct ScrollState(ImplicitlyCopyable):
    """Portable scroll offset and viewport/content extents."""

    var offset_x: Float32
    var offset_y: Float32
    var viewport_width: Float32
    var viewport_height: Float32
    var content_width: Float32
    var content_height: Float32

    def __init__(out self):
        self.offset_x = 0.0
        self.offset_y = 0.0
        self.viewport_width = 0.0
        self.viewport_height = 0.0
        self.content_width = 0.0
        self.content_height = 0.0

    def max_offset_x(self) -> Float32:
        var result = self.content_width - self.viewport_width
        if result < 0.0:
            result = 0.0
        return result

    def max_offset_y(self) -> Float32:
        var result = self.content_height - self.viewport_height
        if result < 0.0:
            result = 0.0
        return result

    def set_viewport(mut self, width: Float32, height: Float32):
        self.viewport_width = width if width > 0.0 else 0.0
        self.viewport_height = height if height > 0.0 else 0.0
        self.clamp()

    def set_content(mut self, width: Float32, height: Float32):
        self.content_width = width if width > 0.0 else 0.0
        self.content_height = height if height > 0.0 else 0.0
        self.clamp()

    def set_offset(mut self, x: Float32, y: Float32):
        self.offset_x = x
        self.offset_y = y
        self.clamp()

    def scroll_by(mut self, dx: Float32, dy: Float32):
        self.offset_x += dx
        self.offset_y += dy
        self.clamp()

    def clamp(mut self):
        if self.offset_x < 0.0:
            self.offset_x = 0.0
        if self.offset_y < 0.0:
            self.offset_y = 0.0
        if self.offset_x > self.max_offset_x():
            self.offset_x = self.max_offset_x()
        if self.offset_y > self.max_offset_y():
            self.offset_y = self.max_offset_y()


struct VirtualRange(ImplicitlyCopyable):
    """Visible item interval for fixed-extent virtualized collections."""

    var start: Int
    var end: Int
    var item_extent: Float32

    def __init__(out self, start: Int, end: Int, item_extent: Float32):
        self.start = start
        self.end = end
        self.item_extent = item_extent

    def count(self) -> Int:
        if self.end <= self.start:
            return 0
        return self.end - self.start


struct VirtualListState(ImplicitlyCopyable):
    """Viewport state for a fixed-extent list that need not build all items."""

    var item_count: Int
    var item_extent: Float32
    var overscan: Int
    var vertical: Bool
    var scroll: ScrollState

    def __init__(
        out self,
        item_count: Int = 0,
        item_extent: Float32 = 1.0,
        overscan: Int = 1,
        vertical: Bool = True,
    ):
        self.item_count = item_count if item_count > 0 else 0
        self.item_extent = item_extent if item_extent > 0.0 else 1.0
        self.overscan = overscan if overscan > 0 else 0
        self.vertical = vertical
        self.scroll = ScrollState()
        self.update_content()

    def update_content(mut self):
        var extent = self.item_extent * Float32(self.item_count)
        if self.vertical:
            self.scroll.set_content(0.0, extent)
        else:
            self.scroll.set_content(extent, 0.0)

    def set_item_count(mut self, count: Int):
        self.item_count = count if count > 0 else 0
        self.update_content()

    def set_item_extent(mut self, extent: Float32):
        self.item_extent = extent if extent > 0.0 else 1.0
        self.update_content()

    def set_viewport(mut self, width: Float32, height: Float32):
        self.scroll.set_viewport(width, height)

    def scroll_by(mut self, dx: Float32, dy: Float32):
        self.scroll.scroll_by(dx, dy)

    def visible(self) -> VirtualRange:
        if self.vertical:
            return visible_range(
                self.item_count,
                self.item_extent,
                self.scroll.offset_y,
                self.scroll.viewport_height,
                self.overscan,
            )
        return visible_range(
            self.item_count,
            self.item_extent,
            self.scroll.offset_x,
            self.scroll.viewport_width,
            self.overscan,
        )


def visible_range(
    item_count: Int,
    item_extent: Float32,
    offset: Float32,
    viewport_extent: Float32,
    overscan: Int = 1,
) -> VirtualRange:
    """Compute a clamped half-open visible range without allocating items."""
    var count = item_count if item_count > 0 else 0
    var extent = item_extent if item_extent > 0.0 else 1.0
    var safe_offset = offset if offset > 0.0 else 0.0
    var safe_viewport = viewport_extent if viewport_extent > 0.0 else 0.0
    var start = Int(safe_offset / extent)
    var end = Int((safe_offset + safe_viewport) / extent) + 1
    var extra = overscan if overscan > 0 else 0
    start -= extra
    end += extra
    if start < 0:
        start = 0
    if start > count:
        start = count
    if end > count:
        end = count
    if end < start:
        end = start
    return VirtualRange(start, end, extent)
