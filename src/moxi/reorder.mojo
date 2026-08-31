"""Renderer-independent stable-key reorder gesture state."""

from .collection_state import ReorderResult
from .event import (
    KEY_ESCAPE,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    KeyEvent,
    PointerEvent,
)
from .geometry import Point


comptime REORDER_IDLE = 0
comptime REORDER_ARMED = 1
comptime REORDER_DRAGGING = 2
comptime REORDER_CANCELLED = 3
comptime REORDER_DROPPED = 4
comptime REORDER_NO_INDEX = -1


struct ReorderInteraction(ImplicitlyCopyable):
    """One pointer-owned reorder gesture.

    This state machine deliberately does not mutate a collection. Once a
    pointer crosses ``threshold`` it can emit a stable-key ``ReorderResult``;
    the caller decides whether and when to apply that command to a
    ``CollectionSelection``.
    """

    var phase: Int
    var pointer_id: Int
    var key: Int
    var from_index: Int
    var to_index: Int
    var start: Point
    var current: Point
    var threshold: Float32
    var item_count: Int

    def __init__(
        out self,
        threshold: Float32 = 4.0,
        item_count: Int = REORDER_NO_INDEX,
    ):
        self.phase = REORDER_IDLE
        self.pointer_id = 0
        self.key = REORDER_NO_INDEX
        self.from_index = REORDER_NO_INDEX
        self.to_index = REORDER_NO_INDEX
        self.start = Point(0.0, 0.0)
        self.current = self.start
        self.threshold = threshold if threshold >= 0.0 else 0.0
        self.item_count = item_count if item_count >= 0 else REORDER_NO_INDEX

    def _valid_index(self, index: Int) -> Bool:
        if index < 0:
            return False
        if self.item_count >= 0 and index >= self.item_count:
            return False
        return True

    def _owns_pointer(self, pointer_id: Int) -> Bool:
        if self.phase != REORDER_ARMED and self.phase != REORDER_DRAGGING:
            return False
        return self.pointer_id == pointer_id

    def set_threshold(mut self, threshold: Float32) -> Bool:
        if self.phase != REORDER_IDLE:
            return False
        var next = threshold if threshold >= 0.0 else 0.0
        if self.threshold == next:
            return False
        self.threshold = next
        return True

    def set_item_count(mut self, item_count: Int) -> Bool:
        if self.phase != REORDER_IDLE:
            return False
        var next = item_count if item_count >= 0 else REORDER_NO_INDEX
        if self.item_count == next:
            return False
        self.item_count = next
        return True

    def begin(
        mut self,
        key: Int,
        index: Int,
        position: Point,
        pointer_id: Int = 0,
    ) -> Bool:
        """Arm a valid row; movement promotes the gesture to dragging."""
        if self.phase != REORDER_IDLE:
            return False
        if key < 0 or not self._valid_index(index) or pointer_id < 0:
            return False
        self.phase = REORDER_ARMED
        self.pointer_id = pointer_id
        self.key = key
        self.from_index = index
        self.to_index = index
        self.start = position
        self.current = position
        return True

    def begin_event(
        mut self,
        key: Int,
        index: Int,
        event: PointerEvent,
    ) -> Bool:
        if event.kind != POINTER_DOWN_KIND:
            return False
        return self.begin(key, index, event.position, event.pointer_id)

    def update(mut self, pointer_id: Int, position: Point) -> Bool:
        """Update the owned pointer and report whether dragging is active."""
        if not self._owns_pointer(pointer_id):
            return False
        self.current = position
        if self.phase == REORDER_ARMED:
            var dx = position.x - self.start.x
            var dy = position.y - self.start.y
            var distance_squared = dx * dx + dy * dy
            var threshold_squared = self.threshold * self.threshold
            if distance_squared < threshold_squared:
                return False
            self.phase = REORDER_DRAGGING
        return True

    def update_event(mut self, event: PointerEvent) -> Bool:
        if event.kind != POINTER_MOVE_KIND:
            return False
        return self.update(event.pointer_id, event.position)

    def set_destination(mut self, pointer_id: Int, index: Int) -> Bool:
        """Track a valid destination while the gesture is dragging."""
        if self.phase != REORDER_DRAGGING or not self._owns_pointer(pointer_id):
            return False
        if not self._valid_index(index) or self.to_index == index:
            return False
        self.to_index = index
        return True

    def drop(mut self, pointer_id: Int, index: Int) -> ReorderResult:
        """Finish the gesture and return a command, without applying it."""
        if not self._owns_pointer(pointer_id):
            return ReorderResult()
        if not self._valid_index(index):
            self.phase = REORDER_CANCELLED
            self.to_index = REORDER_NO_INDEX
            return ReorderResult()

        self.to_index = index
        if self.phase == REORDER_ARMED:
            self.phase = REORDER_DROPPED
            return ReorderResult()

        self.phase = REORDER_DROPPED
        if self.from_index == self.to_index:
            return ReorderResult()
        return ReorderResult(
            True,
            self.key,
            self.from_index,
            self.to_index,
        )

    def drop_event(
        mut self,
        event: PointerEvent,
        index: Int,
    ) -> ReorderResult:
        if event.kind != POINTER_UP_KIND:
            return ReorderResult()
        return self.drop(event.pointer_id, index)

    def cancel(mut self) -> Bool:
        """Cancel the current gesture without emitting a mutation."""
        if self.phase != REORDER_ARMED and self.phase != REORDER_DRAGGING:
            return False
        self.phase = REORDER_CANCELLED
        self.to_index = REORDER_NO_INDEX
        return True

    def cancel_pointer(mut self, pointer_id: Int) -> Bool:
        if not self._owns_pointer(pointer_id):
            return False
        return self.cancel()

    def cancel_event(mut self, event: PointerEvent) -> Bool:
        if event.kind != POINTER_CANCEL_KIND:
            return False
        return self.cancel_pointer(event.pointer_id)

    def handle_key(mut self, event: KeyEvent) -> Bool:
        if event.key != KEY_ESCAPE:
            return False
        return self.cancel()

    def reset(mut self):
        """Return a terminal or idle gesture to its reusable idle state."""
        self.phase = REORDER_IDLE
        self.pointer_id = 0
        self.key = REORDER_NO_INDEX
        self.from_index = REORDER_NO_INDEX
        self.to_index = REORDER_NO_INDEX
        self.start = Point(0.0, 0.0)
        self.current = self.start

    def is_armed(self) -> Bool:
        return self.phase == REORDER_ARMED

    def is_dragging(self) -> Bool:
        return self.phase == REORDER_DRAGGING

    def is_cancelled(self) -> Bool:
        return self.phase == REORDER_CANCELLED

    def is_dropped(self) -> Bool:
        return self.phase == REORDER_DROPPED

    def is_terminal(self) -> Bool:
        return self.is_cancelled() or self.is_dropped()
