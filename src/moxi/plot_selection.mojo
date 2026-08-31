"""Stable-key selection values shared by plots and linked views."""

from std.collections import List


struct PlotSelection:
    """A data-space selection represented by stable row keys.

    ``keys`` remains an ordered public view for deterministic serialization and
    accessibility.  ``slots`` is an internal open-addressed index so hot
    interaction paths can test membership without repeatedly scanning the
    selected rows.
    """

    var keys: List[Int]
    var version: Int
    var slots: List[Int]

    def __init__(out self):
        self.keys = List[Int]()
        self.version = 0
        self.slots = List[Int]()

    def _hash(self, key: Int, capacity: Int) -> Int:
        var value = key % capacity
        if value < 0:
            value = -value
        # Keep the arithmetic bounded before multiplying.  The odd multiplier
        # distributes sequential and sparse stable keys over power-of-two
        # capacities without relying on bit operations in the public API.
        return ((value * 31) + 17) % capacity

    def _insert_index(mut self, key: Int):
        if len(self.slots) == 0:
            return
        var slot = self._hash(key, len(self.slots))
        for _ in range(len(self.slots)):
            if self.slots[slot] == -1:
                self.slots[slot] = key
                return
            slot = (slot + 1) % len(self.slots)

    def _rebuild_index(mut self, capacity: Int):
        var safe_capacity = capacity if capacity >= 8 else 8
        self.slots = List[Int](capacity=safe_capacity)
        for _ in range(safe_capacity):
            self.slots.append(-1)
        for index in range(len(self.keys)):
            self._insert_index(self.keys[index])

    def _ensure_index(mut self, required: Int):
        var capacity = len(self.slots)
        if capacity == 0:
            capacity = 8
        while required * 2 >= capacity:
            capacity *= 2
        if capacity != len(self.slots):
            self._rebuild_index(capacity)

    def _indexed_contains(self, key: Int) -> Bool:
        if key < 0 or len(self.slots) == 0:
            return False
        var slot = self._hash(key, len(self.slots))
        for _ in range(len(self.slots)):
            var stored = self.slots[slot]
            if stored == -1:
                return False
            if stored == key:
                return True
            slot = (slot + 1) % len(self.slots)
        return False

    def clone(self) -> PlotSelection:
        var result = PlotSelection()
        result.keys = self.keys.copy()
        result.version = self.version
        result.slots = self.slots.copy()
        return result^

    def count(self) -> Int:
        return len(self.keys)

    def key_at(self, index: Int) -> Int:
        if index < 0 or index >= len(self.keys):
            return -1
        return self.keys[index]

    def contains(self, key: Int) -> Bool:
        return self._indexed_contains(key)

    def add(mut self, key: Int) -> Bool:
        if key < 0 or self.contains(key):
            return False
        self._ensure_index(len(self.keys) + 1)
        self.keys.append(key)
        self._insert_index(key)
        self.version += 1
        return True

    def remove(mut self, key: Int) -> Bool:
        for index in range(len(self.keys)):
            if self.keys[index] == key:
                _ = self.keys.pop(index)
                if len(self.keys) == 0:
                    self.slots = List[Int]()
                else:
                    # Deletion in a linear-probed table needs tombstones or a
                    # cluster repair.  Rebuilding is cheap for a selection
                    # mutation and keeps contains() branch-free on the hot
                    # hover/brush paths.
                    self._rebuild_index(len(self.slots))
                self.version += 1
                return True
        return False

    def toggle(mut self, key: Int) -> Bool:
        if self.remove(key):
            return False
        _ = self.add(key)
        return True

    def clear(mut self):
        if len(self.keys) == 0:
            return
        self.keys = List[Int]()
        self.slots = List[Int]()
        self.version += 1

    def union(self, other: PlotSelection) -> PlotSelection:
        var result = self.clone()
        for index in range(other.count()):
            _ = result.add(other.key_at(index))
        return result^

    def intersect(self, other: PlotSelection) -> PlotSelection:
        var result = PlotSelection()
        for index in range(self.count()):
            var key = self.key_at(index)
            if other.contains(key):
                _ = result.add(key)
        return result^


def selection_from_keys(keys: List[Int]) -> PlotSelection:
    """Create a de-duplicated selection while preserving input order."""
    var result = PlotSelection()
    for index in range(len(keys)):
        _ = result.add(keys[index])
    return result^
