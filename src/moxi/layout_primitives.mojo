"""Reusable layout math independent of the view and platform layers."""

from std.collections import List

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


struct VirtualRecycleItem(ImplicitlyCopyable):
    """One retained slot assigned to a visible stable-key item."""

    var key: Int
    var index: Int
    var bounds: Rect
    var active: Bool

    def __init__(out self, key: Int = -1, index: Int = -1):
        self.key = key
        self.index = index
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.active = False


struct VirtualRecycler:
    """Stable-key recycler for lists that build only their overscan window.

    The caller owns the item builder. It asks for the active slots after
    `update()` and renders/builds only those items. Slot identity survives
    scrolling and stable-key reordering, while off-screen slots are reused.
    """

    var item_count: Int
    var item_extent: Float32
    var overscan: Int
    var vertical: Bool
    var keys: List[Int]
    var slots: List[VirtualRecycleItem]
    var active_slots: List[Int]
    var visible_range: VirtualRange
    var last_created_count: Int
    var last_reused_count: Int
    var last_recycled_count: Int
    var last_released_count: Int

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
        self.keys = List[Int](capacity=self.item_count)
        for index in range(self.item_count):
            self.keys.append(index)
        self.slots = List[VirtualRecycleItem]()
        self.active_slots = List[Int]()
        self.visible_range = VirtualRange(0, 0, self.item_extent)
        self.last_created_count = 0
        self.last_reused_count = 0
        self.last_recycled_count = 0
        self.last_released_count = 0

    def set_item_count(mut self, count: Int):
        var next_count = count if count > 0 else 0
        var next_keys = List[Int](capacity=next_count)
        for index in range(next_count):
            if index < len(self.keys):
                next_keys.append(self.keys[index])
            else:
                next_keys.append(index)
        self.item_count = next_count
        self.keys = next_keys^
        self.active_slots = List[Int]()
        for slot_index in range(len(self.slots)):
            self.slots[slot_index].active = False

    def set_key(mut self, index: Int, key: Int) -> Bool:
        if index < 0 or index >= len(self.keys):
            return False
        self.keys[index] = key
        return True

    def set_item_extent(mut self, extent: Float32):
        self.item_extent = extent if extent > 0.0 else 1.0

    def set_overscan(mut self, value: Int):
        self.overscan = value if value > 0 else 0

    def _slot_for_key(self, key: Int) -> Int:
        for slot_index in range(len(self.slots)):
            if self.slots[slot_index].active and self.slots[slot_index].key == key:
                return slot_index
        return -1

    def _free_slot(self) -> Int:
        for slot_index in range(len(self.slots)):
            if not self.slots[slot_index].active:
                return slot_index
        return -1

    def update(
        mut self,
        offset: Float32,
        viewport_extent: Float32,
        cross_extent: Float32,
    ) -> VirtualRange:
        """Reassign visible keys to a bounded retained slot pool."""
        self.last_created_count = 0
        self.last_reused_count = 0
        self.last_recycled_count = 0
        self.last_released_count = 0
        var next_active = List[Int]()
        var next_range = visible_range(
            self.item_count,
            self.item_extent,
            offset,
            viewport_extent,
            self.overscan,
        )
        for item_index in range(next_range.start, next_range.end):
            var key = self.keys[item_index]
            var slot_index = self._slot_for_key(key)
            if slot_index != -1:
                self.last_reused_count += 1
            else:
                slot_index = self._free_slot()
                if slot_index == -1:
                    self.slots.append(VirtualRecycleItem(key, item_index))
                    slot_index = len(self.slots) - 1
                    self.last_created_count += 1
                else:
                    self.last_recycled_count += 1
            var bounds = Rect(
                0.0 if self.vertical else self.item_extent * Float32(item_index),
                self.item_extent * Float32(item_index) if self.vertical else 0.0,
                cross_extent if self.vertical else self.item_extent,
                self.item_extent if self.vertical else cross_extent,
            )
            self.slots[slot_index].key = key
            self.slots[slot_index].index = item_index
            self.slots[slot_index].bounds = bounds
            self.slots[slot_index].active = True
            next_active.append(slot_index)

        for slot_index in range(len(self.slots)):
            var was_active = self.slots[slot_index].active
            var retained = False
            for next_index in range(len(next_active)):
                if next_active[next_index] == slot_index:
                    retained = True
                    break
            if was_active and not retained:
                self.slots[slot_index].active = False
                self.last_released_count += 1
        self.active_slots = next_active^
        self.visible_range = next_range
        return next_range

    def active_count(self) -> Int:
        return len(self.active_slots)

    def slot_count(self) -> Int:
        return len(self.slots)

    def active_slot(self, index: Int) -> VirtualRecycleItem:
        if index < 0 or index >= len(self.active_slots):
            return VirtualRecycleItem()
        return self.slots[self.active_slots[index]]

    def slot_for_item(self, item_index: Int) -> VirtualRecycleItem:
        for index in range(len(self.active_slots)):
            var slot = self.slots[self.active_slots[index]]
            if slot.index == item_index:
                return slot
        return VirtualRecycleItem()


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
