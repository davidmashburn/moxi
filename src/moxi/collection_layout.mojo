"""Variable extent, two-axis viewport planning with staged realization.

Metadata is proportional to source size; realization is bounded by the viewport,
overscan, frozen tracks and explicitly pinned editor rows. No UI instances or
lifecycle callbacks are created until the caller publishes the global frame.
"""
from std.collections import List, Dict
from std.memory import ArcPointer
from std.math import isfinite
from .geometry import Rect


def _collection_extent(value: Float64) raises:
    if not isfinite(value) or value < 0:
        raise Error("Collection extents must be finite and nonnegative")


struct ExtentIndex:
    """Fenwick prefix index: extent changes, offsets and lookup are O(log n).

    Source permutations are atomic O(n) rebuilds and preserve keyed measurements.
    """
    var keys: List[Int]
    var _values: List[Float64]
    var _measured: List[Bool]
    var _tree: List[Float64]
    var _indices: Dict[Int, Int]
    var revision: Int

    def __init__(out self):
        self.keys = List[Int]()
        self._values = List[Float64]()
        self._measured = List[Bool]()
        self._tree = List[Float64]()
        self._tree.append(0)
        self._indices = Dict[Int, Int]()
        self.revision = 0

    def count(self) -> Int:
        return len(self.keys)

    def index(self, key: Int) -> Int:
        return self._indices.get(key, -1)

    def extent(self, index: Int) raises -> Float64:
        if index < 0 or index >= self.count():
            raise Error("Unknown extent index")
        return self._values[index]

    def sync(mut self, keys: List[Int], estimates: List[Float64]) raises:
        if len(keys) != len(estimates):
            raise Error("Collection keys and estimates must have equal lengths")
        var indices = Dict[Int, Int]()
        var values = List[Float64]()
        var measured = List[Bool]()
        var identical = self.count() == len(keys)
        for i in range(len(keys)):
            _collection_extent(estimates[i])
            if keys[i] <= 0 or keys[i] in indices:
                raise Error("Collection keys must be positive and unique")
            indices[keys[i]] = i
            var old = self.index(keys[i])
            var value = estimates[i]
            var retained = old >= 0 and self._measured[old]
            if retained:
                value = self._values[old]
            values.append(value)
            measured.append(retained)
            if old != i or (old >= 0 and self._values[old] != value):
                identical = False
        if identical:
            return
        var tree = List[Float64]()
        tree.append(0)
        for value in values:
            tree.append(value)
        for i in range(1, len(tree)):
            var parent = i + (i & -i)
            if parent < len(tree):
                tree[parent] += tree[i]
            if not isfinite(tree[i]):
                raise Error("Collection extent total overflow")
        self.keys = keys.copy()
        self._values = values^
        self._measured = measured^
        self._tree = tree^
        self._indices = indices^
        self.revision += 1

    def update(mut self, key: Int, value: Float64) raises:
        _collection_extent(value)
        var index = self.index(key)
        if index < 0:
            raise Error("Unknown collection key")
        if not isfinite(self.total() - self._values[index] + value):
            raise Error("Collection extent total overflow")
        self._measured[index] = True
        if self._values[index] == value:
            return
        var delta = value - self._values[index]
        self._values[index] = value
        var i = index + 1
        while i < len(self._tree):
            self._tree[i] += delta
            i += i & -i
        self.revision += 1

    def invalidate_measurements(mut self, estimate: Float64) raises:
        _collection_extent(estimate)
        var estimates = List[Float64]()
        for i in range(self.count()):
            self._measured[i] = False
            estimates.append(estimate)
        var keys = self.keys.copy()
        self.sync(keys, estimates)

    def offset(self, index: Int) -> Float64:
        var i = max(0, min(index, self.count()))
        var total: Float64 = 0
        while i > 0:
            total += self._tree[i]
            i -= i & -i
        return total

    def total(self) -> Float64:
        return self.offset(self.count())

    def at(self, offset: Float64) -> Int:
        """Half-open lookup skips zero-sized tracks; returns count at the end."""
        if self.count() == 0 or offset >= self.total():
            return self.count()
        var position = max(Float64(0), offset)
        var bit = 1
        while bit * 2 <= self.count():
            bit *= 2
        var index = 0
        var sum: Float64 = 0
        while bit > 0:
            var next = index + bit
            if next <= self.count() and sum + self._tree[next] <= position:
                index = next
                sum += self._tree[next]
            bit //= 2
        return min(index, self.count())


struct ScrollAnchor(ImplicitlyCopyable):
    var key: Int
    var within: Float64
    def __init__(out self, key: Int = -1, within: Float64 = 0):
        self.key = key
        self.within = within


struct RealizedCell(ImplicitlyCopyable):
    var row_key: Int
    var column_key: Int
    var row: Int
    var column: Int
    var mount: Int
    var rect: Rect
    var clip: Rect
    var frozen: Bool
    var pinned: Bool

    def __init__(out self, row_key: Int, column_key: Int, row: Int, column: Int,
                 mount: Int, rect: Rect, clip: Rect, frozen: Bool, pinned: Bool):
        self.row_key = row_key
        self.column_key = column_key
        self.row = row
        self.column = column
        self.mount = mount
        self.rect = rect
        self.clip = clip
        self.frozen = frozen
        self.pinned = pinned


struct ViewportPlan:
    var cells: List[RealizedCell]
    var offset_x: Float64
    var offset_y: Float64
    var _owner: ArcPointer[Int]
    var _generation: Int
    var _rows_revision: Int
    var _columns_revision: Int
    var _pin_revision: Int
    var _next_mount: Int

    def __init__(out self, owner: ArcPointer[Int], generation: Int, rows: Int,
                 columns: Int, pins: Int, next_mount: Int):
        self.cells = List[RealizedCell]()
        self.offset_x = 0
        self.offset_y = 0
        self._owner = owner
        self._generation = generation
        self._rows_revision = rows
        self._columns_revision = columns
        self._pin_revision = pins
        self._next_mount = next_mount


struct CollectionViewport:
    var rows: ExtentIndex
    var columns: ExtentIndex
    var focused_row: Int
    var _pins: List[Int]
    var _pin_revision: Int
    var _owner: ArcPointer[Int]
    var _active: List[RealizedCell]
    var _generation: Int
    var _next_mount: Int
    var created: Int
    var reused: Int

    def __init__(out self):
        self.rows = ExtentIndex()
        self.columns = ExtentIndex()
        self.focused_row = -1
        self._pins = List[Int]()
        self._pin_revision = 0
        self._owner = ArcPointer(0)
        self._active = List[RealizedCell]()
        self._generation = 0
        self._next_mount = 1
        self.created = 0
        self.reused = 0

    def sync_rows(mut self, keys: List[Int], estimates: List[Float64]) raises:
        self.rows.sync(keys, estimates)
        if self.rows.index(self.focused_row) < 0:
            self.focused_row = -1
        var pins = List[Int]()
        for key in self._pins:
            if self.rows.index(key) >= 0:
                pins.append(key)
        if len(pins) != len(self._pins):
            self._pins = pins^
            self._pin_revision += 1

    def pin_editor(mut self, row_key: Int) raises:
        if self.rows.index(row_key) < 0:
            raise Error("Cannot pin a removed editor row")
        for key in self._pins:
            if key == row_key:
                return
        if len(self._pins) >= 4:
            raise Error("Viewport editor pin limit is four rows")
        self._pins.append(row_key)
        self._pin_revision += 1

    def unpin_editor(mut self, row_key: Int):
        var pins = List[Int]()
        for key in self._pins:
            if key != row_key:
                pins.append(key)
        if len(pins) != len(self._pins):
            self._pins = pins^
            self._pin_revision += 1

    def anchor(self, offset: Float64, frozen_rows: Int = 0) -> ScrollAnchor:
        var logical = offset + self.rows.offset(frozen_rows)
        var index = self.rows.at(logical)
        if index >= self.rows.count():
            return ScrollAnchor()
        return ScrollAnchor(self.rows.keys[index], logical - self.rows.offset(index))

    def restore(self, anchor: ScrollAnchor, fallback: Float64,
                viewport_height: Float64, frozen_rows: Int = 0) -> Float64:
        var index = self.rows.index(anchor.key)
        var offset = fallback
        if index >= 0:
            offset = self.rows.offset(index) + min(anchor.within, self.rows._values[index]) - self.rows.offset(frozen_rows)
        return max(Float64(0), min(offset, max(Float64(0), self.rows.total() - viewport_height)))

    def measure_row(mut self, key: Int, extent: Float64, offset: Float64,
                    viewport_height: Float64, frozen_rows: Int = 0) raises -> Float64:
        var anchor = self.anchor(offset, frozen_rows)
        self.rows.update(key, extent)
        return self.restore(anchor, offset, viewport_height, frozen_rows)

    def focus(mut self, row_key: Int, offset: Float64, viewport_height: Float64,
              frozen_rows: Int = 0) raises -> Float64:
        var index = self.rows.index(row_key)
        if index < 0:
            raise Error("Cannot focus a removed row")
        self.focused_row = row_key
        if index < frozen_rows:
            return offset
        var top = self.rows.offset(index)
        var bottom = self.rows.offset(index + 1)
        var result = offset
        var frozen = self.rows.offset(frozen_rows)
        if top < offset + frozen:
            result = top - frozen
        elif bottom > offset + viewport_height:
            result = bottom - viewport_height
        return max(Float64(0), min(result, max(Float64(0), self.rows.total() - viewport_height)))

    def stage(self, viewport: Rect, offset_x: Float64 = 0, offset_y: Float64 = 0,
              overscan: Int = 2, frozen_rows: Int = 0, frozen_columns: Int = 0,
              rtl: Bool = False) raises -> ViewportPlan:
        _collection_extent(Float64(viewport.width))
        _collection_extent(Float64(viewport.height))
        if not isfinite(viewport.x) or not isfinite(viewport.y) or not isfinite(offset_x) or not isfinite(offset_y) or overscan < 0:
            raise Error("Invalid viewport geometry or overscan")
        if frozen_rows < 0 or frozen_rows > self.rows.count() or frozen_columns < 0 or frozen_columns > self.columns.count():
            raise Error("Invalid frozen track counts")
        var plan = ViewportPlan(self._owner, self._generation, self.rows.revision,
                                self.columns.revision, self._pin_revision, self._next_mount)
        plan.offset_x = max(Float64(0), min(offset_x, max(Float64(0), self.columns.total() - Float64(viewport.width))))
        plan.offset_y = max(Float64(0), min(offset_y, max(Float64(0), self.rows.total() - Float64(viewport.height))))
        if viewport.width == 0 or viewport.height == 0 or self.rows.count() == 0 or self.columns.count() == 0:
            return plan^
        var frozen_h = min(Float64(viewport.height), self.rows.offset(frozen_rows))
        var frozen_w = min(Float64(viewport.width), self.columns.offset(frozen_columns))
        var row_indices = List[Int]()
        var column_indices = List[Int]()
        for i in range(min(frozen_rows, self.rows.at(Float64(viewport.height)) + 1)):
            if self.rows._values[i] > 0:
                row_indices.append(i)
        var row_start = max(frozen_rows, self.rows.at(plan.offset_y + frozen_h) - overscan)
        var row_end = min(self.rows.count(), self.rows.at(plan.offset_y + Float64(viewport.height)) + 1 + overscan)
        if frozen_h < Float64(viewport.height):
            for i in range(row_start, row_end):
                if self.rows._values[i] > 0:
                    row_indices.append(i)
        for key in self._pins:
            var index = self.rows.index(key)
            if index >= frozen_rows and (index < row_start or index >= row_end):
                row_indices.append(index)
        for i in range(min(frozen_columns, self.columns.at(Float64(viewport.width)) + 1)):
            if self.columns._values[i] > 0:
                column_indices.append(i)
        var column_start = max(frozen_columns, self.columns.at(plan.offset_x + frozen_w) - overscan)
        var column_end = min(self.columns.count(), self.columns.at(plan.offset_x + Float64(viewport.width)) + 1 + overscan)
        if frozen_w < Float64(viewport.width):
            for i in range(column_start, column_end):
                if self.columns._values[i] > 0:
                    column_indices.append(i)
        for row in row_indices:
            for column in column_indices:
                var row_key = self.rows.keys[row]
                var column_key = self.columns.keys[column]
                var x = self.columns.offset(column)
                var y = self.rows.offset(row)
                if column >= frozen_columns:
                    x -= plan.offset_x
                if row >= frozen_rows:
                    y -= plan.offset_y
                var width = self.columns._values[column]
                var height = self.rows._values[row]
                if rtl:
                    x = Float64(viewport.width) - x - width
                var rect = Rect(viewport.x + Float32(x), viewport.y + Float32(y), Float32(width), Float32(height))
                if not isfinite(rect.x) or not isfinite(rect.y) or not isfinite(rect.width) or not isfinite(rect.height):
                    raise Error("Collection coordinates exceed geometry precision")
                var clip = viewport
                if row >= frozen_rows:
                    clip.y += Float32(frozen_h)
                    clip.height -= Float32(frozen_h)
                if column >= frozen_columns:
                    clip.width -= Float32(frozen_w)
                    if not rtl:
                        clip.x += Float32(frozen_w)
                var mount = 0
                for old in self._active:
                    if old.row_key == row_key and old.column_key == column_key:
                        mount = old.mount
                        break
                if mount == 0:
                    mount = plan._next_mount
                    plan._next_mount += 1
                var pinned = False
                for key in self._pins:
                    pinned = pinned or key == row_key
                plan.cells.append(RealizedCell(row_key, column_key, row, column, mount,
                    rect, rect.intersection(clip), row < frozen_rows or column < frozen_columns, pinned))
        # Frozen cells paint last; reverse hit testing uses this same order.
        var sorted = List[RealizedCell]()
        for cell in plan.cells:
            if not cell.frozen:
                sorted.append(cell)
        for cell in plan.cells:
            if cell.frozen:
                sorted.append(cell)
        plan.cells = sorted^
        return plan^

    def validate(self, plan: ViewportPlan) raises:
        if plan._owner.ptr() != self._owner.ptr() or plan._generation != self._generation or plan._rows_revision != self.rows.revision or plan._columns_revision != self.columns.revision or plan._pin_revision != self._pin_revision:
            raise Error("Stale or foreign viewport realization plan")

    def commit(mut self, var plan: ViewportPlan) raises:
        """Call only after global geometry publication succeeds; discard on failure."""
        self.validate(plan)
        for cell in plan.cells:
            if cell.mount >= self._next_mount:
                self.created += 1
            else:
                self.reused += 1
        self._next_mount = plan._next_mount
        self._active = plan.cells.copy()
        self._generation += 1

    def realized(self) -> Int:
        return len(self._active)
