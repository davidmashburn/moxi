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
    """Visible item interval for virtualized collections.

    ``item_extent`` is the recycler's default/estimated extent. A recycler
    with measured heights exposes exact per-item offsets through its slots and
    ``item_offset``/``item_height`` methods.
    """

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
    # Measured item extents are kept separately from the default estimate so
    # callers can measure only what was built. Prefix offsets make every active
    # slot lookup O(1); rebuilding is deferred to each measurement mutation.
    var item_extents: List[Float32]
    var measured: List[Int]
    var prefix_offsets: List[Float32]
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
        self.item_extents = List[Float32](capacity=self.item_count)
        self.measured = List[Int](capacity=self.item_count)
        for _ in range(self.item_count):
            self.item_extents.append(self.item_extent)
            self.measured.append(0)
        self.prefix_offsets = List[Float32](capacity=self.item_count + 1)
        self.prefix_offsets.append(0.0)
        for index in range(self.item_count):
            self.prefix_offsets.append(
                self.prefix_offsets[index] + self.item_extents[index]
            )
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
        var next_extents = List[Float32](capacity=next_count)
        var next_measured = List[Int](capacity=next_count)
        for index in range(next_count):
            if index < len(self.item_extents):
                next_extents.append(self.item_extents[index])
                next_measured.append(self.measured[index])
            else:
                next_extents.append(self.item_extent)
                next_measured.append(0)
        self.item_count = next_count
        self.keys = next_keys^
        self.item_extents = next_extents^
        self.measured = next_measured^
        self._rebuild_prefix_offsets()
        self.active_slots = List[Int]()
        for slot_index in range(len(self.slots)):
            self.slots[slot_index].active = False

    def set_key(mut self, index: Int, key: Int) -> Bool:
        if index < 0 or index >= len(self.keys):
            return False
        if key < 0:
            return False
        for existing in range(len(self.keys)):
            if existing != index and self.keys[existing] == key:
                return False
        self.keys[index] = key
        return True

    def set_item_extent(mut self, extent: Float32):
        self.item_extent = extent if extent > 0.0 else 1.0
        for index in range(len(self.item_extents)):
            if self.measured[index] == 0:
                self.item_extents[index] = self.item_extent
        self._rebuild_prefix_offsets()

    def _rebuild_prefix_offsets(mut self):
        """Rebuild cumulative offsets after a batch of measurements."""
        self.prefix_offsets = List[Float32](capacity=self.item_count + 1)
        self.prefix_offsets.append(0.0)
        for index in range(self.item_count):
            self.prefix_offsets.append(
                self.prefix_offsets[index] + self.item_extents[index]
            )

    def set_item_height(mut self, index: Int, height: Float32) -> Bool:
        """Record one measured item height and update content offsets."""
        if index < 0 or index >= self.item_count or height <= 0.0:
            return False
        self.item_extents[index] = height
        self.measured[index] = 1
        self._rebuild_prefix_offsets()
        return True

    def clear_item_height(mut self, index: Int) -> Bool:
        """Forget one measurement and return that item to the default extent."""
        if index < 0 or index >= self.item_count:
            return False
        self.item_extents[index] = self.item_extent
        self.measured[index] = 0
        self._rebuild_prefix_offsets()
        return True

    def item_height(self, index: Int) -> Float32:
        if index < 0 or index >= self.item_count:
            return 0.0
        return self.item_extents[index]

    def item_offset(self, index: Int) -> Float32:
        if index <= 0:
            return 0.0
        if index >= self.item_count:
            return self.content_extent()
        return self.prefix_offsets[index]

    def item_index_at_offset(self, offset: Float32) -> Int:
        """Find the item containing an offset with binary-search prefix math."""
        if self.item_count <= 0:
            return 0
        var value = offset if offset > 0.0 else 0.0
        var content = self.content_extent()
        if value >= content:
            return self.item_count - 1
        var low = 0
        var high = self.item_count
        while low < high:
            var middle = (low + high) // 2
            if self.prefix_offsets[middle + 1] <= value:
                low = middle + 1
            else:
                high = middle
        return low

    def set_item_height_preserving_offset(
        mut self,
        index: Int,
        height: Float32,
        offset: Float32,
    ) -> Float32:
        """Measure an item while keeping the current content anchor stable."""
        if index < 0 or index >= self.item_count or height <= 0.0:
            return offset if offset > 0.0 else 0.0
        var anchor = self.item_index_at_offset(offset)
        var previous_height = self.item_height(index)
        if not self.set_item_height(index, height):
            return offset if offset > 0.0 else 0.0
        var result = offset if offset > 0.0 else 0.0
        if index < anchor:
            result += height - previous_height
        return result if result > 0.0 else 0.0

    def visible_range_for(
        self,
        offset: Float32,
        viewport_extent: Float32,
        overscan: Int = -1,
    ) -> VirtualRange:
        var extra = self.overscan if overscan < 0 else overscan
        return variable_visible_range(
            self.prefix_offsets,
            self.item_count,
            offset,
            viewport_extent,
            extra,
            self.item_extent,
        )

    def set_overscan(mut self, value: Int):
        self.overscan = value if value > 0 else 0

    def content_extent(self) -> Float32:
        return self.prefix_offsets[len(self.prefix_offsets) - 1]

    def max_offset(self, viewport_extent: Float32) -> Float32:
        var maximum = self.content_extent() - (
            viewport_extent if viewport_extent > 0.0 else 0.0
        )
        return maximum if maximum > 0.0 else 0.0

    def clamp_offset(self, offset: Float32, viewport_extent: Float32) -> Float32:
        var result = offset if offset > 0.0 else 0.0
        var maximum = self.max_offset(viewport_extent)
        if result > maximum:
            result = maximum
        return result

    def ensure_visible(
        self,
        item_index: Int,
        viewport_extent: Float32,
        offset: Float32,
    ) -> Float32:
        """Return the smallest clamped offset that reveals one item."""
        var result = self.clamp_offset(offset, viewport_extent)
        if item_index < 0 or item_index >= self.item_count:
            return result
        var top = self.item_offset(item_index)
        var bottom = top + self.item_height(item_index)
        var viewport = viewport_extent if viewport_extent > 0.0 else 0.0
        if top < result:
            result = top
        elif bottom > result + viewport:
            result = bottom - viewport
        return self.clamp_offset(result, viewport_extent)

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
        var safe_offset = self.clamp_offset(offset, viewport_extent)
        var next_range = self.visible_range_for(
            safe_offset, viewport_extent, self.overscan
        )
        # Release keys that left the overscan window before allocating the
        # next window. This is what makes scrolling reuse slots instead of
        # growing the pool until every item has appeared once.
        for slot_index in range(len(self.slots)):
            if not self.slots[slot_index].active:
                continue
            var retained = False
            for item_index in range(next_range.start, next_range.end):
                if self.slots[slot_index].key == self.keys[item_index]:
                    retained = True
                    break
            if not retained:
                self.slots[slot_index].active = False
                self.last_released_count += 1
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
                0.0 if self.vertical else self.item_offset(item_index),
                self.item_offset(item_index) if self.vertical else 0.0,
                cross_extent if self.vertical else self.item_height(item_index),
                self.item_height(item_index) if self.vertical else cross_extent,
            )
            self.slots[slot_index].key = key
            self.slots[slot_index].index = item_index
            self.slots[slot_index].bounds = bounds
            self.slots[slot_index].active = True
            next_active.append(slot_index)

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


def variable_visible_range(
    prefix_offsets: List[Float32],
    item_count: Int,
    offset: Float32,
    viewport_extent: Float32,
    overscan: Int = 1,
    estimated_extent: Float32 = 1.0,
) -> VirtualRange:
    """Compute a variable-height visible range from cumulative offsets.

    This helper mirrors the recycler's binary-search policy for consumers that
    maintain their own measurements. ``prefix_offsets`` must contain one more
    value than the item count, beginning at zero.
    """
    var count = item_count if item_count > 0 else 0
    var extent = estimated_extent if estimated_extent > 0.0 else 1.0
    if count <= 0 or len(prefix_offsets) < count + 1:
        return VirtualRange(0, 0, extent)
    var safe_offset = offset if offset > 0.0 else 0.0
    var content = prefix_offsets[count]
    if safe_offset >= content:
        safe_offset = content
    var start_low = 0
    var start_high = count
    while start_low < start_high:
        var middle = (start_low + start_high) // 2
        if prefix_offsets[middle + 1] <= safe_offset:
            start_low = middle + 1
        else:
            start_high = middle
    var safe_viewport = viewport_extent if viewport_extent > 0.0 else 0.0
    var bottom = safe_offset + safe_viewport
    var end_index = count - 1
    if bottom < content:
        var end_low = 0
        var end_high = count
        while end_low < end_high:
            var middle = (end_low + end_high) // 2
            if prefix_offsets[middle + 1] <= bottom:
                end_low = middle + 1
            else:
                end_high = middle
        end_index = end_low
    var start = start_low
    var end = end_index + 1
    var extra = overscan if overscan > 0 else 0
    start -= extra
    end += extra
    if start < 0:
        start = 0
    if end > count:
        end = count
    if end < start:
        end = start
    return VirtualRange(start, end, extent)
