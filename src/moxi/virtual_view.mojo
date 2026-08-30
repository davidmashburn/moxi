"""View-building adapter on top of the stable-key virtual recycler."""

from .geometry import Rect
from .layout_primitives import VirtualRecycler
from .view import ColumnView, ViewNode


trait VirtualItemBuilder(ImplicitlyCopyable & Deinitable):
    """Typed builder for one visible item; no erased callback is stored."""

    def build(self, index: Int, key: Int, bounds: Rect) -> ViewNode:
        ...


struct VirtualizedList[Builder: VirtualItemBuilder]:
    """Build only the recycler's visible/overscan items into a view."""

    var builder: Self.Builder
    var recycler: VirtualRecycler
    var offset: Float32

    def __init__(
        out self,
        builder: Self.Builder,
        item_count: Int,
        item_extent: Float32,
        overscan: Int = 1,
    ):
        self.builder = builder
        self.recycler = VirtualRecycler(item_count, item_extent, overscan, True)
        self.offset = 0.0

    def set_item_count(mut self, count: Int):
        self.recycler.set_item_count(count)

    def set_key(mut self, index: Int, key: Int) -> Bool:
        return self.recycler.set_key(index, key)

    def set_offset(mut self, offset: Float32):
        self.offset = offset if offset > 0.0 else 0.0

    def ensure_visible(mut self, item_index: Int, viewport_extent: Float32) -> Float32:
        self.offset = self.recycler.ensure_visible(
            item_index,
            viewport_extent,
            self.offset,
        )
        return self.offset

    def build(mut self, bounds: Rect) -> ColumnView:
        """Return a view containing only the active window of item nodes."""
        self.offset = self.recycler.clamp_offset(self.offset, bounds.height)
        _ = self.recycler.update(self.offset, bounds.height, bounds.width)
        var view = ColumnView(bounds, 0.0, 0.0)
        for active_index in range(self.recycler.active_count()):
            var slot = self.recycler.active_slot(active_index)
            var node = self.builder.build(slot.index, slot.key, slot.bounds)
            node.bounds = Rect(
                bounds.x + slot.bounds.x,
                bounds.y + slot.bounds.y - self.offset,
                bounds.width,
                slot.bounds.height,
            )
            view.add(node)
        # `ColumnView` still owns the normal layout contract; overwrite the
        # positioned visible nodes afterward because their content-space
        # offsets are determined by the recycler, not sibling flow.
        view.layout()
        for active_index in range(self.recycler.active_count()):
            var slot = self.recycler.active_slot(active_index)
            view.children[active_index].bounds = Rect(
                bounds.x + slot.bounds.x,
                bounds.y + slot.bounds.y - self.offset,
                bounds.width,
                slot.bounds.height,
            )
        return view^
