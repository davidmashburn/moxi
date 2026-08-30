"""Stable-key selection values shared by plots and linked views."""

from std.collections import List


struct PlotSelection:
    """A data-space selection represented by stable row keys."""

    var keys: List[Int]
    var version: Int

    def __init__(out self):
        self.keys = List[Int]()
        self.version = 0

    def clone(self) -> PlotSelection:
        var result = PlotSelection()
        result.keys = self.keys.copy()
        result.version = self.version
        return result^

    def count(self) -> Int:
        return len(self.keys)

    def key_at(self, index: Int) -> Int:
        if index < 0 or index >= len(self.keys):
            return -1
        return self.keys[index]

    def contains(self, key: Int) -> Bool:
        if key < 0:
            return False
        for index in range(len(self.keys)):
            if self.keys[index] == key:
                return True
        return False

    def add(mut self, key: Int) -> Bool:
        if key < 0 or self.contains(key):
            return False
        self.keys.append(key)
        self.version += 1
        return True

    def remove(mut self, key: Int) -> Bool:
        for index in range(len(self.keys)):
            if self.keys[index] == key:
                _ = self.keys.pop(index)
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
