"""Bounded uniform-grid broad phase with explicit incremental insert/remove."""
from std.collections import Dict, List
from std.math import floor
from moxi.geometry import Rect, Point


struct SpatialIndex(ImplicitlyCopyable):
    var cells: Dict[Int, List[Int]]
    var bounds: Dict[Int, Rect]
    var large: List[Int]
    var writes: Int

    def __init__(out self):
        self.cells = Dict[Int, List[Int]]()
        self.bounds = Dict[Int, Rect]()
        self.large = List[Int]()
        self.writes = 0

    def __init__(out self, *, copy: Self):
        self.cells = copy.cells.copy()
        self.bounds = copy.bounds.copy()
        self.large = copy.large.copy()
        self.writes = copy.writes

    def keys(self, rect: Rect) -> List[Int]:
        var x0 = Int(floor(rect.x / 128))
        var y0 = Int(floor(rect.y / 128))
        var x1 = Int(floor((rect.x + rect.width) / 128))
        var y1 = Int(floor((rect.y + rect.height) / 128))
        var result = List[Int]()
        # Huge crossing paths use one bounded overflow entry, never millions of cells.
        if (x1 - x0 + 1) * (y1 - y0 + 1) <= 256:
            for x in range(x0, x1 + 1):
                for y in range(y0, y1 + 1):
                    result.append(x + y * 4294967296)
        return result^

    def remove(mut self, id: Int):
        if id not in self.bounds:
            return
        var keys = self.keys(self.bounds.get(id, Rect(0, 0, 0, 0)))
        for key in keys:
            var values = self.cells.get(key, List[Int]())
            var kept = List[Int]()
            for value in values:
                if value != id:
                    kept.append(value)
            if len(kept) == 0:
                try:
                    _ = self.cells.pop(key)
                except:
                    pass
            else:
                self.cells[key] = kept^
        var kept = List[Int]()
        for value in self.large:
            if value != id:
                kept.append(value)
        self.large = kept^
        try:
            _ = self.bounds.pop(id)
        except:
            pass
        self.writes += 1

    def update(mut self, id: Int, rect: Rect):
        if id in self.bounds:
            var old = self.bounds.get(id, Rect(0, 0, 0, 0))
            if old.x == rect.x and old.y == rect.y and old.width == rect.width and old.height == rect.height:
                return
            self.remove(id)
        self.bounds[id] = rect
        var keys = self.keys(rect)
        if len(keys) == 0:
            self.large.append(id)
        for key in keys:
            var values = self.cells.get(key, List[Int]())
            values.append(id)
            self.cells[key] = values^
        self.writes += 1

    def query(self, point: Point) -> List[Int]:
        var key = Int(floor(point.x / 128)) + Int(floor(point.y / 128)) * 4294967296
        var result = self.cells.get(key, List[Int]())
        for id in self.large:
            result.append(id)
        return result^

    def retain_prefix(mut self, count: Int):
        var retired = List[Int]()
        for id in self.bounds.keys():
            if id >= count:
                retired.append(id)
        for id in retired:
            self.remove(id)

    def retain_ids(mut self, live: Dict[Int, Point]):
        var retired = List[Int]()
        for id in self.bounds.keys():
            if id not in live:
                retired.append(id)
        for id in retired:
            self.remove(id)
