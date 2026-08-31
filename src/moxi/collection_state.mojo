"""Stable-key collection state independent of rendering and platform handles."""

from std.collections import List

from .event import (
    KEY_A,
    KEY_DOWN,
    KEY_END,
    KEY_ENTER,
    KEY_HOME,
    KEY_SPACE,
    KEY_UP,
    MOD_COMMAND,
    MOD_CONTROL,
    MOD_SHIFT,
)
from .plot_selection import PlotSelection


comptime COLLECTION_NONE = -1
comptime COLLECTION_SINGLE = 0
comptime COLLECTION_MULTIPLE = 1
comptime COLUMN_SORT_NONE = 0
comptime COLUMN_SORT_ASCENDING = 1
comptime COLUMN_SORT_DESCENDING = 2


struct CollectionColumn(ImplicitlyCopyable):
    """Stable table-column metadata independent of header painting."""

    var id: Int
    var title: String
    var width: Float32
    var min_width: Float32
    var max_width: Float32
    var visible: Bool
    var sortable: Bool
    var resizable: Bool
    var sort_order: Int

    def __init__(
        out self,
        id: Int,
        title: String = "",
        width: Float32 = 120.0,
        min_width: Float32 = 24.0,
        max_width: Float32 = 1000.0,
    ):
        self.id = id
        self.title = title
        self.min_width = min_width if min_width > 0.0 else 1.0
        self.max_width = (
            max_width if max_width >= self.min_width else self.min_width
        )
        self.width = width
        self.visible = True
        self.sortable = True
        self.resizable = True
        self.sort_order = COLUMN_SORT_NONE
        _ = self.set_width(width)

    def set_width(mut self, width: Float32) -> Bool:
        var next = width if width > 0.0 else self.min_width
        if next < self.min_width:
            next = self.min_width
        if next > self.max_width:
            next = self.max_width
        if self.width == next:
            return False
        self.width = next
        return True

    def set_sort(mut self, order: Int) -> Bool:
        var next = order
        if next < COLUMN_SORT_NONE or next > COLUMN_SORT_DESCENDING:
            next = COLUMN_SORT_NONE
        if self.sort_order == next:
            return False
        self.sort_order = next
        return True


def _contains_key(keys: List[Int], key: Int) -> Bool:
    for index in range(len(keys)):
        if keys[index] == key:
            return True
    return False


struct ReorderResult(ImplicitlyCopyable):
    """The stable identity and final index produced by a reorder command."""

    var changed: Bool
    var key: Int
    var from_index: Int
    var to_index: Int

    def __init__(
        out self,
        changed: Bool = False,
        key: Int = -1,
        from_index: Int = -1,
        to_index: Int = -1,
    ):
        self.changed = changed
        self.key = key
        self.from_index = from_index
        self.to_index = to_index


struct CollectionSelection:
    """Focus and selection for a stable-key list or table.

    The ordered ``keys`` list is the collection's current identity order.
    ``selected`` stores stable keys, so a reorder or refresh does not turn a
    selected row into a different row merely because its visible index moved.
    """

    var keys: List[Int]
    var selected: PlotSelection
    var focus_key: Int
    var anchor_key: Int
    var multiple: Bool

    def __init__(out self, item_count: Int = 0, multiple: Bool = False):
        self.keys = List[Int]()
        self.selected = PlotSelection()
        self.focus_key = -1
        self.anchor_key = -1
        self.multiple = multiple
        if item_count > 0:
            var initial = List[Int](capacity=item_count)
            for index in range(item_count):
                initial.append(index)
            _ = self.set_keys(initial)

    def item_count(self) -> Int:
        return len(self.keys)

    def key_at(self, index: Int) -> Int:
        if index < 0 or index >= len(self.keys):
            return COLLECTION_NONE
        return self.keys[index]

    def index_of_key(self, key: Int) -> Int:
        if key < 0:
            return COLLECTION_NONE
        for index in range(len(self.keys)):
            if self.keys[index] == key:
                return index
        return COLLECTION_NONE

    def focus_index(self) -> Int:
        return self.index_of_key(self.focus_key)

    def selected_count(self) -> Int:
        return self.selected.count()

    def selected_key_at(self, index: Int) -> Int:
        return self.selected.key_at(index)

    def is_selected(self, key: Int) -> Bool:
        return self.selected.contains(key)

    def set_multiple(mut self, multiple: Bool) -> Bool:
        if self.multiple == multiple:
            return False
        self.multiple = multiple
        if not multiple and self.selected.count() > 1:
            var first = self.selected.key_at(0)
            self.selected.clear()
            _ = self.selected.add(first)
        return True

    def set_keys(mut self, keys: List[Int]) -> Bool:
        """Reconcile identities while retaining valid selection and focus."""
        var old_keys = self.keys.copy()
        var old_selected = self.selected.clone()
        var old_focus = self.focus_key
        var old_anchor = self.anchor_key
        var old_focus_index = self.index_of_key(old_focus)

        self.keys = List[Int](capacity=len(keys))
        for index in range(len(keys)):
            var key = keys[index]
            if key >= 0 and not _contains_key(self.keys, key):
                self.keys.append(key)

        self.selected = PlotSelection()
        for index in range(old_selected.count()):
            var key = old_selected.key_at(index)
            if self.index_of_key(key) != COLLECTION_NONE:
                _ = self.selected.add(key)
                if not self.multiple:
                    break

        if len(self.keys) == 0:
            self.focus_key = COLLECTION_NONE
            self.anchor_key = COLLECTION_NONE
        else:
            if self.index_of_key(old_focus) != COLLECTION_NONE:
                self.focus_key = old_focus
            else:
                var fallback = old_focus_index
                if fallback < 0:
                    fallback = 0
                if fallback >= len(self.keys):
                    fallback = len(self.keys) - 1
                self.focus_key = self.keys[fallback]
            if self.index_of_key(old_anchor) != COLLECTION_NONE:
                self.anchor_key = old_anchor
            else:
                self.anchor_key = self.focus_key

        var changed = len(old_keys) != len(self.keys)
        if not changed:
            for index in range(len(self.keys)):
                if old_keys[index] != self.keys[index]:
                    changed = True
                    break
        if old_focus != self.focus_key or old_anchor != self.anchor_key:
            changed = True
        if old_selected.count() != self.selected.count():
            changed = True
        if not changed:
            for index in range(self.selected.count()):
                if not old_selected.contains(self.selected.key_at(index)):
                    changed = True
                    break
        return changed

    def set_item_count(mut self, item_count: Int) -> Bool:
        var count = item_count if item_count > 0 else 0
        var next_keys = List[Int](capacity=count)
        for index in range(count):
            next_keys.append(index)
        return self.set_keys(next_keys)

    def clear_selection(mut self) -> Bool:
        var changed = self.selected.count() > 0 or self.anchor_key != COLLECTION_NONE
        self.selected.clear()
        self.anchor_key = COLLECTION_NONE
        return changed

    def _select_range(mut self, start: Int, end: Int):
        var first = start
        var last = end
        if first > last:
            var swap = first
            first = last
            last = swap
        for index in range(first, last + 1):
            _ = self.selected.add(self.keys[index])

    def select_key(
        mut self,
        key: Int,
        extend: Bool = False,
        toggle: Bool = False,
    ) -> Bool:
        var index = self.index_of_key(key)
        if index == COLLECTION_NONE:
            return False
        var before_version = self.selected.version
        var before_focus = self.focus_key
        var before_anchor = self.anchor_key

        self.focus_key = key
        if toggle and self.multiple:
            if self.selected.contains(key):
                _ = self.selected.remove(key)
            else:
                _ = self.selected.add(key)
            self.anchor_key = key
        elif extend and self.multiple:
            var anchor_index = self.index_of_key(self.anchor_key)
            if anchor_index == COLLECTION_NONE:
                anchor_index = index
                self.anchor_key = key
            self.selected.clear()
            self._select_range(anchor_index, index)
        else:
            if (
                self.selected.count() == 1
                and self.selected.contains(key)
                and before_focus == key
                and not self.multiple
            ):
                self.anchor_key = key
            else:
                self.selected.clear()
                _ = self.selected.add(key)
            self.anchor_key = key

        return (
            before_version != self.selected.version
            or before_focus != self.focus_key
            or before_anchor != self.anchor_key
        )

    def select_index(
        mut self,
        index: Int,
        extend: Bool = False,
        toggle: Bool = False,
    ) -> Bool:
        return self.select_key(self.key_at(index), extend, toggle)

    def select_all(mut self) -> Bool:
        if not self.multiple or len(self.keys) == 0:
            return False
        var before = self.selected.count()
        self.selected.clear()
        for index in range(len(self.keys)):
            _ = self.selected.add(self.keys[index])
        if self.focus_key == COLLECTION_NONE:
            self.focus_key = self.keys[0]
        self.anchor_key = self.focus_key
        return before != self.selected.count()

    def move_focus_to(mut self, index: Int, extend: Bool = False) -> Bool:
        if index < 0 or index >= len(self.keys):
            return False
        if extend and self.multiple:
            return self.select_index(index, True, False)
        if self.focus_key == self.keys[index]:
            return False
        self.focus_key = self.keys[index]
        return True

    def move_focus(mut self, delta: Int, extend: Bool = False) -> Bool:
        if len(self.keys) == 0:
            return False
        var current = self.focus_index()
        if current == COLLECTION_NONE:
            current = 0 if delta >= 0 else len(self.keys) - 1
        var target = current + delta
        if target < 0:
            target = 0
        if target >= len(self.keys):
            target = len(self.keys) - 1
        return self.move_focus_to(target, extend)

    def handle_key(mut self, key: Int, modifiers: Int = 0) -> Bool:
        """Apply common list keyboard navigation without owning an event loop."""
        if len(self.keys) == 0:
            return False
        var current = self.focus_index()
        if current == COLLECTION_NONE:
            current = 0
        var target = current
        if key == KEY_UP:
            target -= 1
        elif key == KEY_DOWN:
            target += 1
        elif key == KEY_HOME:
            target = 0
        elif key == KEY_END:
            target = len(self.keys) - 1
        elif key == KEY_A and (modifiers & (MOD_COMMAND | MOD_CONTROL)) != 0:
            return self.select_all()
        elif key == KEY_SPACE:
            return self.select_index(current, False, self.multiple)
        elif key == KEY_ENTER:
            return self.select_index(current)
        else:
            return False

        if target < 0:
            target = 0
        if target >= len(self.keys):
            target = len(self.keys) - 1
        var command_navigation = (modifiers & (MOD_COMMAND | MOD_CONTROL)) != 0
        if command_navigation:
            return self.move_focus_to(target)
        return self.select_index(target, (modifiers & MOD_SHIFT) != 0, False)

    def reorder(mut self, from_index: Int, to_index: Int) -> ReorderResult:
        """Move one item to a final index while preserving stable selection."""
        if (
            from_index < 0
            or from_index >= len(self.keys)
            or len(self.keys) < 2
        ):
            return ReorderResult()
        var destination = to_index
        if destination < 0:
            destination = 0
        if destination >= len(self.keys):
            destination = len(self.keys) - 1
        if from_index == destination:
            return ReorderResult()

        var moved_key = self.keys[from_index]
        var remaining = List[Int](capacity=len(self.keys) - 1)
        for index in range(len(self.keys)):
            if index != from_index:
                remaining.append(self.keys[index])

        var next_keys = List[Int](capacity=len(self.keys))
        for index in range(len(remaining) + 1):
            if index == destination:
                next_keys.append(moved_key)
            if index < len(remaining):
                next_keys.append(remaining[index])
        self.keys = next_keys^
        return ReorderResult(True, moved_key, from_index, destination)


struct TreeNodeRecord(ImplicitlyCopyable):
    """Stable hierarchy metadata; content and row views remain caller-owned."""

    var key: Int
    var parent_key: Int
    var expanded: Bool

    def __init__(
        out self,
        key: Int,
        parent_key: Int = COLLECTION_NONE,
        expanded: Bool = False,
    ):
        self.key = key
        self.parent_key = parent_key
        self.expanded = expanded


struct TreeCollectionState:
    """A stable-key tree with visible-order selection and disclosure state."""

    var nodes: List[TreeNodeRecord]
    var selection: CollectionSelection

    def __init__(out self, multiple: Bool = False):
        self.nodes = List[TreeNodeRecord]()
        self.selection = CollectionSelection(0, multiple)

    def node_count(self) -> Int:
        return len(self.nodes)

    def _node_index(self, key: Int) -> Int:
        for index in range(len(self.nodes)):
            if self.nodes[index].key == key:
                return index
        return COLLECTION_NONE

    def is_expanded(self, key: Int) -> Bool:
        var index = self._node_index(key)
        if index == COLLECTION_NONE:
            return False
        return self.nodes[index].expanded

    def visible_keys(self) -> List[Int]:
        """Flatten nodes in insertion order, hiding collapsed descendants."""
        var result = List[Int]()
        for index in range(len(self.nodes)):
            var node = self.nodes[index]
            if node.parent_key == COLLECTION_NONE:
                result.append(node.key)
            elif _contains_key(result, node.parent_key) and self.is_expanded(
                node.parent_key
            ):
                result.append(node.key)
        return result^

    def _refresh_selection(mut self):
        var visible = self.visible_keys()
        _ = self.selection.set_keys(visible)

    def add_node(
        mut self,
        key: Int,
        parent_key: Int = COLLECTION_NONE,
        expanded: Bool = False,
    ) -> Bool:
        if key < 0 or self._node_index(key) != COLLECTION_NONE:
            return False
        if (
            parent_key != COLLECTION_NONE
            and self._node_index(parent_key) == COLLECTION_NONE
        ):
            return False
        self.nodes.append(TreeNodeRecord(key, parent_key, expanded))
        self._refresh_selection()
        return True

    def set_expanded(mut self, key: Int, expanded: Bool) -> Bool:
        var index = self._node_index(key)
        if index == COLLECTION_NONE or self.nodes[index].expanded == expanded:
            return False
        self.nodes[index].expanded = expanded
        self._refresh_selection()
        return True

    def toggle_expanded(mut self, key: Int) -> Bool:
        var index = self._node_index(key)
        if index == COLLECTION_NONE:
            return False
        return self.set_expanded(key, not self.nodes[index].expanded)

    def select_key(
        mut self,
        key: Int,
        extend: Bool = False,
        toggle: Bool = False,
    ) -> Bool:
        return self.selection.select_key(key, extend, toggle)

    def handle_key(mut self, key: Int, modifiers: Int = 0) -> Bool:
        return self.selection.handle_key(key, modifiers)
