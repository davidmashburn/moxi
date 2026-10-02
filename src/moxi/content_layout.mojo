"""Retained content/fill layout for the first modern Moxi layout slice.

This module deliberately has no dependency on ``ColumnView``.  Callers submit
an indexed list of input nodes with :meth:`LayoutTree.sync`, then run
``layout``.  The tree keeps measurement results by stable node id while the
public bounds remain addressable by the current input index.

The sizing vocabulary is intentionally small:

* ``AxisSize.content()`` asks for the measured extent;
* ``AxisSize.fill(weight)`` participates in remaining-space allocation; and
* ``AxisSize.fixed(points)`` requests an explicit extent.

Padding is inside a container's border box and gaps are inserted only between
participating children.  This is a deterministic headless measurement engine;
the text estimator is a replaceable contract, not a claim of native glyph
metric parity.
"""

from std.collections import Dict, List

from .geometry import Rect, Size


comptime AXIS_CONTENT = 0
comptime AXIS_FILL = 1
comptime AXIS_FIXED = 2

comptime LAYOUT_COLUMN = 0
comptime LAYOUT_ROW = 1


struct AxisSize(ImplicitlyCopyable):
    """One axis sizing policy."""

    var kind: Int
    var value: Float32

    def __init__(out self, kind: Int = AXIS_CONTENT, value: Float32 = 0.0):
        self.kind = kind
        self.value = value if value > 0.0 else 0.0

    @staticmethod
    def content() -> AxisSize:
        return AxisSize(AXIS_CONTENT, 0.0)

    @staticmethod
    def fill(weight: Float32 = 1.0) -> AxisSize:
        var safe_weight = weight
        if safe_weight < 0.0:
            safe_weight = 0.0
        return AxisSize(AXIS_FILL, safe_weight)

    @staticmethod
    def fixed(points: Float32) -> AxisSize:
        var safe_points = points
        if safe_points < 0.0:
            safe_points = 0.0
        return AxisSize(AXIS_FIXED, safe_points)


# Free aliases make the contract convenient for code that prefers functions
# over associated constructors.
def content_size() -> AxisSize:
    return AxisSize.content()


def fill_size(weight: Float32 = 1.0) -> AxisSize:
    return AxisSize.fill(weight)


def fixed_size(points: Float32) -> AxisSize:
    return AxisSize.fixed(points)


struct LayoutStyle(ImplicitlyCopyable):
    """Container direction and independent per-axis sizing constraints."""

    var width: AxisSize
    var height: AxisSize
    var min_width: Float32
    var max_width: Float32
    var min_height: Float32
    var max_height: Float32
    var axis: Int
    var padding: Float32
    var gap: Float32

    def __init__(out self):
        self.width = AxisSize.content()
        self.height = AxisSize.content()
        self.min_width = 0.0
        self.max_width = -1.0
        self.min_height = 0.0
        self.max_height = -1.0
        self.axis = LAYOUT_COLUMN
        self.padding = 0.0
        self.gap = 0.0

    def __init__(
        out self,
        width: AxisSize,
        height: AxisSize,
        min_width: Float32 = 0.0,
        max_width: Float32 = -1.0,
        min_height: Float32 = 0.0,
        max_height: Float32 = -1.0,
        axis: Int = LAYOUT_COLUMN,
        padding: Float32 = 0.0,
        gap: Float32 = 0.0,
    ):
        self.width = width
        self.height = height
        self.min_width = min_width if min_width > 0.0 else 0.0
        self.max_width = max_width if max_width >= 0.0 else -1.0
        self.min_height = min_height if min_height > 0.0 else 0.0
        self.max_height = max_height if max_height >= 0.0 else -1.0
        self.axis = LAYOUT_ROW if axis == LAYOUT_ROW else LAYOUT_COLUMN
        self.padding = padding if padding > 0.0 else 0.0
        self.gap = gap if gap > 0.0 else 0.0


def column_style(
    width: AxisSize,
    height: AxisSize,
    min_width: Float32 = 0.0,
    max_width: Float32 = -1.0,
    min_height: Float32 = 0.0,
    max_height: Float32 = -1.0,
    padding: Float32 = 0.0,
    gap: Float32 = 0.0,
) -> LayoutStyle:
    return LayoutStyle(
        width,
        height,
        min_width,
        max_width,
        min_height,
        max_height,
        LAYOUT_COLUMN,
        padding,
        gap,
    )


def row_style(
    width: AxisSize,
    height: AxisSize,
    min_width: Float32 = 0.0,
    max_width: Float32 = -1.0,
    min_height: Float32 = 0.0,
    max_height: Float32 = -1.0,
    padding: Float32 = 0.0,
    gap: Float32 = 0.0,
) -> LayoutStyle:
    return LayoutStyle(
        width,
        height,
        min_width,
        max_width,
        min_height,
        max_height,
        LAYOUT_ROW,
        padding,
        gap,
    )


struct LayoutNode(ImplicitlyCopyable):
    """Input record consumed by ``LayoutTree.sync``.

    ``parent`` is an index in the submitted list, or ``-1`` for a root.
    ``intrinsic_*`` supplies a measured extent for non-text content.  Chrome
    extents are added around text/content and are useful for controls whose
    border or internal padding is owned by the caller.
    """

    var id: Int
    var parent: Int
    var style: LayoutStyle
    var container: Bool
    var text: String
    var font_size: Float32
    var wrap: Bool
    var intrinsic_width: Float32
    var intrinsic_height: Float32
    var chrome_width: Float32
    var chrome_height: Float32

    def __init__(
        out self,
        id: Int = 0,
        parent: Int = -1,
        style: LayoutStyle = LayoutStyle(),
        container: Bool = False,
        text: String = "",
        font_size: Float32 = 16.0,
        wrap: Bool = False,
        intrinsic_width: Float32 = 0.0,
        intrinsic_height: Float32 = 0.0,
        chrome_width: Float32 = 0.0,
        chrome_height: Float32 = 0.0,
    ):
        self.id = id
        self.parent = parent
        self.style = style
        self.container = container
        self.text = text
        self.font_size = font_size if font_size > 0.0 else 16.0
        self.wrap = wrap
        self.intrinsic_width = intrinsic_width if intrinsic_width > 0.0 else 0.0
        self.intrinsic_height = intrinsic_height if intrinsic_height > 0.0 else 0.0
        self.chrome_width = chrome_width if chrome_width > 0.0 else 0.0
        self.chrome_height = chrome_height if chrome_height > 0.0 else 0.0


struct LayoutStats(ImplicitlyCopyable):
    """Counters for inspecting retained layout work."""

    var leaf_measurements: Int
    var node_visits: Int
    var cache_hits: Int
    var overflow_count: Int
    var changed_geometry: Int

    def __init__(out self):
        self.leaf_measurements = 0
        self.node_visits = 0
        self.cache_hits = 0
        self.overflow_count = 0
        self.changed_geometry = 0


struct _LayoutRecord(ImplicitlyCopyable):
    var input: LayoutNode
    var rect: Rect
    var extent: Size
    var overflowed: Bool
    var revision: Int
    var cache_valid: Bool
    var cache_revision: Int
    var cache_width: Float32
    var cache_height: Float32
    var cached_extent: Size
    # A retained leaf can be queried at both an unbounded natural width and
    # its final allocated width during one pass. Keep both signatures so a
    # clean rerun does not thrash one single cache slot.
    var cache2_valid: Bool
    var cache2_revision: Int
    var cache2_width: Float32
    var cache2_height: Float32
    var cached_extent2: Size

    def __init__(out self, input: LayoutNode):
        self.input = input
        self.rect = Rect(0.0, 0.0, 0.0, 0.0)
        self.extent = Size(0.0, 0.0)
        self.overflowed = False
        self.revision = 1
        self.cache_valid = False
        self.cache_revision = 0
        self.cache_width = 0.0
        self.cache_height = 0.0
        self.cached_extent = Size(0.0, 0.0)
        self.cache2_valid = False
        self.cache2_revision = 0
        self.cache2_width = 0.0
        self.cache2_height = 0.0
        self.cached_extent2 = Size(0.0, 0.0)


def _same_float(left: Float32, right: Float32) -> Bool:
    return left == right


def _same_axis(left: AxisSize, right: AxisSize) -> Bool:
    return left.kind == right.kind and _same_float(left.value, right.value)


def _same_style(left: LayoutStyle, right: LayoutStyle) -> Bool:
    return (
        _same_axis(left.width, right.width)
        and _same_axis(left.height, right.height)
        and _same_float(left.min_width, right.min_width)
        and _same_float(left.max_width, right.max_width)
        and _same_float(left.min_height, right.min_height)
        and _same_float(left.max_height, right.max_height)
        and left.axis == right.axis
        and _same_float(left.padding, right.padding)
        and _same_float(left.gap, right.gap)
    )


def _same_input(left: LayoutNode, right: LayoutNode) -> Bool:
    return (
        left.id == right.id
        and left.parent == right.parent
        and _same_style(left.style, right.style)
        and left.container == right.container
        and left.text == right.text
        and _same_float(left.font_size, right.font_size)
        and left.wrap == right.wrap
        and _same_float(left.intrinsic_width, right.intrinsic_width)
        and _same_float(left.intrinsic_height, right.intrinsic_height)
        and _same_float(left.chrome_width, right.chrome_width)
        and _same_float(left.chrome_height, right.chrome_height)
    )


def _clamp(value: Float32, minimum: Float32, maximum: Float32) -> Float32:
    var result = value
    var low = minimum if minimum > 0.0 else 0.0
    var high = maximum
    if high >= 0.0 and high < low:
        low = high
    if result < low:
        result = low
    if high >= 0.0 and result > high:
        result = high
    if result < 0.0:
        result = 0.0
    return result


def _text_measure(text: String, font_size: Float32, max_width: Float32) -> Size:
    """Greedy deterministic codepoint measurement used by headless layout."""
    var size = font_size if font_size > 0.0 else 16.0
    var advance = size * 0.56
    var line_height = size * 1.25
    if line_height < 16.0:
        line_height = 16.0
    if text.count_codepoints() == 0:
        return Size(0.0, 0.0)

    # ``-1`` is the unbounded proposal.  Zero is a real constraint: a wrapped
    # paragraph still has one line per glyph, but publishes zero width.
    var unbounded = max_width < 0.0
    var limit = max_width if not unbounded else 0.0
    if limit < 0.0:
        limit = 0.0
    var line_width: Float32 = 0.0
    var widest: Float32 = 0.0
    var lines = 1
    var index = 0
    var length = text.count_codepoints()
    while index < length:
        var glyph = String(text[codepoint=index:index + 1])
        if glyph == "\n":
            if line_width > widest:
                widest = line_width
            lines += 1
            line_width = 0.0
            index += 1
            continue
        if not unbounded and line_width > 0.0 and line_width + advance > limit:
            if line_width > widest:
                widest = line_width
            lines += 1
            line_width = 0.0
        line_width += advance
        index += 1
    if line_width > widest:
        widest = line_width
    if not unbounded and widest > limit:
        widest = limit
    return Size(widest, line_height * Float32(lines))


struct LayoutTree:
    """Retained indexed layout arena."""

    var records: List[_LayoutRecord]
    var id_indices: Dict[Int, Int]
    var child_starts: List[Int]
    var child_order: List[Int]
    var current_stats: LayoutStats
    var last_root: Int
    var valid: Bool

    def __init__(out self):
        self.records = List[_LayoutRecord]()
        self.id_indices = Dict[Int, Int]()
        self.child_starts = List[Int]()
        self.child_order = List[Int]()
        self.current_stats = LayoutStats()
        self.last_root = -1
        self.valid = True

    def sync(mut self, nodes: List[LayoutNode]):
        """Replace input order while preserving caches by stable node id."""
        var next = List[_LayoutRecord](capacity=len(nodes))
        var changed = len(self.records) != len(nodes)
        for input_index in range(len(nodes)):
            var incoming = nodes[input_index]
            var old_index = self.id_indices.get(incoming.id, -1)
            if old_index >= 0:
                var record = self.records[old_index]
                if not _same_input(record.input, incoming):
                    changed = True
                    record.revision += 1
                    record.cache_valid = False
                    record.cache2_valid = False
                    record.overflowed = False
                record.input = incoming
                next.append(record)
            else:
                changed = True
                next.append(_LayoutRecord(incoming))
        self.records = next^
        self._rebuild_index()
        # A changed descendant can alter every ancestor's intrinsic extent.
        # Invalidate container queries eagerly; leaf caches remain reusable by
        # their complete (revision, width) key.
        if changed:
            for index in range(len(self.records)):
                if self.records[index].input.container:
                    self.records[index].cache_valid = False
                    self.records[index].cache2_valid = False

    def add(mut self, node: LayoutNode) -> Int:
        """Append an input node and return its current index."""
        self.records.append(_LayoutRecord(node))
        self._rebuild_index()
        for index in range(len(self.records)):
            if self.records[index].input.container:
                self.records[index].cache_valid = False
                self.records[index].cache2_valid = False
        return len(self.records) - 1

    def layout(mut self, bounds: Rect, root: Int = 0):
        """Measure and place the retained tree inside ``bounds``."""
        self.current_stats = LayoutStats()
        self.last_root = root
        if not self.valid or root < 0 or root >= len(self.records):
            return
        _ = self._measure_node(root, bounds.width, bounds.height)
        self._place_node(root, bounds)
        for index in range(len(self.records)):
            if self.records[index].overflowed:
                self.current_stats.overflow_count += 1

    def finish(mut self, bounds: Rect, root: Int = 0):
        """Alias for ``layout`` used by retained callers."""
        self.layout(bounds, root)

    def clone(self) -> LayoutTree:
        var result = LayoutTree()
        result.records = List[_LayoutRecord](capacity=len(self.records))
        for index in range(len(self.records)):
            result.records.append(self.records[index])
        result._rebuild_index()
        result.current_stats = self.current_stats
        result.last_root = self.last_root
        result.valid = self.valid
        return result^

    def node(self, index: Int) -> LayoutNode:
        if index < 0 or index >= len(self.records):
            return LayoutNode()
        return self.records[index].input

    def bounds(self, index: Int) -> Rect:
        if index < 0 or index >= len(self.records):
            return Rect(0.0, 0.0, 0.0, 0.0)
        return self.records[index].rect

    def content_extent(self, index: Int) -> Size:
        if index < 0 or index >= len(self.records):
            return Size(0.0, 0.0)
        return self.records[index].extent

    def extent(self, index: Int) -> Size:
        return self.content_extent(index)

    def overflow(self, index: Int = -1) -> Bool:
        if index >= 0:
            if index >= len(self.records):
                return False
            return self.records[index].overflowed
        return self.current_stats.overflow_count > 0

    def stats(self) -> LayoutStats:
        return self.current_stats

    def leaf_measurements(self) -> Int:
        return self.current_stats.leaf_measurements

    def node_visits(self) -> Int:
        return self.current_stats.node_visits

    def cache_hits(self) -> Int:
        return self.current_stats.cache_hits

    def overflow_count(self) -> Int:
        return self.current_stats.overflow_count

    def count(self) -> Int:
        return len(self.records)

    def is_valid(self) -> Bool:
        """Return whether parent links form a bounded, usable forest."""
        return self.valid

    def _child_count(self, parent: Int) -> Int:
        if parent < 0 or parent >= len(self.records):
            return 0
        return self.child_starts[parent + 1] - self.child_starts[parent]

    def _child_at(self, parent: Int, ordinal: Int) -> Int:
        if parent < 0 or parent >= len(self.records):
            return -1
        var start = self.child_starts[parent]
        var end = self.child_starts[parent + 1]
        if ordinal < 0 or start + ordinal >= end:
            return -1
        return self.child_order[start + ordinal]

    def _rebuild_index(mut self):
        """Build id and contiguous child adjacency indexes in O(n)."""
        self.valid = True
        self.id_indices = Dict[Int, Int]()
        for index in range(len(self.records)):
            self.id_indices[self.records[index].input.id] = index

        var count = len(self.records)
        self.child_starts = List[Int](capacity=count + 1)
        for _ in range(count + 1):
            self.child_starts.append(0)
        for index in range(count):
            var parent = self.records[index].input.parent
            if parent >= 0 and parent < count:
                self.child_starts[parent + 1] += 1
        for index in range(count):
            self.child_starts[index + 1] += self.child_starts[index]
        self.child_order = List[Int](capacity=count)
        for _ in range(count):
            self.child_order.append(-1)
        var cursors = List[Int](capacity=count)
        for index in range(count):
            cursors.append(self.child_starts[index])
        for index in range(count):
            var parent = self.records[index].input.parent
            if parent >= 0 and parent < count:
                var position = cursors[parent]
                self.child_order[position] = index
                cursors[parent] += 1

        # Reject malformed input before measure recursion. Duplicate stable
        # ids make cache retention ambiguous, while an invalid or cyclic
        # parent chain would otherwise recurse forever.
        var visit_state = List[Int](capacity=count)
        for _ in range(count):
            visit_state.append(0)
        for index in range(count):
            var node = self.records[index].input
            if self.id_indices.get(node.id, -1) != index:
                self.valid = False
            var parent = node.parent
            if parent < -1 or parent >= count or parent == index:
                self.valid = False
            elif parent >= 0 and not self.records[parent].input.container:
                self.valid = False

        # Three-state traversal validates every parent chain in linear time:
        # each node is marked visiting once and complete once, avoiding a
        # fresh full ancestor walk for every deep node.
        for start in range(count):
            if visit_state[start] != 0:
                continue
            var cursor = start
            while (
                cursor >= 0
                and cursor < count
                and visit_state[cursor] == 0
            ):
                visit_state[cursor] = 1
                cursor = self.records[cursor].input.parent
            if cursor >= 0 and cursor < count and visit_state[cursor] == 1:
                self.valid = False
            cursor = start
            while (
                cursor >= 0
                and cursor < count
                and visit_state[cursor] == 1
            ):
                visit_state[cursor] = 2
                cursor = self.records[cursor].input.parent

    def _requested_width(self, index: Int, measured: Size) -> Float32:
        var style = self.records[index].input.style
        var value = measured.width
        if style.width.kind == AXIS_FIXED:
            value = style.width.value
        return _clamp(value, style.min_width, style.max_width)

    def _requested_height(self, index: Int, measured: Size) -> Float32:
        var style = self.records[index].input.style
        var value = measured.height
        if style.height.kind == AXIS_FIXED:
            value = style.height.value
        return _clamp(value, style.min_height, style.max_height)

    def _cross_constraint(
        self,
        index: Int,
        axis: Int,
        inner_width: Float32,
        inner_height: Float32,
    ) -> Float32:
        var input = self.records[index].input
        if axis == LAYOUT_COLUMN:
            var proposed: Float32 = -1.0
            if input.style.width.kind == AXIS_FIXED:
                proposed = input.style.width.value
            elif input.style.width.kind == AXIS_FILL or input.wrap:
                proposed = inner_width
            if proposed >= 0.0:
                return _clamp(
                    proposed,
                    input.style.min_width,
                    input.style.max_width,
                )
            return proposed
        var proposed: Float32 = -1.0
        if input.style.height.kind == AXIS_FIXED:
            proposed = input.style.height.value
        elif input.style.height.kind == AXIS_FILL:
            proposed = inner_height
        if proposed >= 0.0:
            return _clamp(
                proposed,
                input.style.min_height,
                input.style.max_height,
            )
        return proposed

    def _row_allocations(
        mut self,
        index: Int,
        inner_width: Float32,
        inner_height: Float32,
    ) -> List[Float32]:
        """Resolve row widths before querying width-dependent child height.

        A row's natural cross size cannot be known from an unbounded text
        query. This first pass resolves fixed/content/fill widths using the
        same clamp-and-redistribute policy as placement; the caller then
        measures each child with its final width.
        """
        var count = self._child_count(index)
        var allocations = List[Float32](capacity=count)
        var weights = List[Float32](capacity=count)
        var fill_flags = List[Int](capacity=count)
        var allocated: Float32 = 0.0
        var weight_total: Float32 = 0.0
        var bounded = inner_width >= 0.0
        var usable_main = inner_width
        if bounded:
            usable_main -= self.records[index].input.style.gap * Float32(
                count - 1 if count > 1 else 0
            )
            if usable_main < 0.0:
                usable_main = 0.0

        for ordinal in range(count):
            var child = self._child_at(index, ordinal)
            var child_height = self._cross_constraint(
                child, LAYOUT_ROW, inner_width, inner_height
            )
            var natural = self._measure_node(child, -1.0, child_height)
            var child_input = self.records[child].input
            var spec = child_input.style.width
            var natural_width = self._requested_width(child, natural)
            var base: Float32
            var is_fill = 0
            var weight: Float32 = 0.0
            if spec.kind == AXIS_FIXED:
                base = spec.value
            elif spec.kind == AXIS_FILL:
                # An unbounded row has no leftover to distribute, so a fill
                # child falls back to its measured content extent.
                base = natural_width if not bounded else child_input.style.min_width
                is_fill = 1
                weight = spec.value
            else:
                base = natural_width
            base = _clamp(base, child_input.style.min_width, child_input.style.max_width)
            allocations.append(base)
            weights.append(weight)
            fill_flags.append(is_fill)
            allocated += base
            if is_fill == 1:
                weight_total += weight

        if bounded:
            var remaining = usable_main - allocated
            if remaining > 0.0 and weight_total > 0.0:
                var active = List[Int](capacity=count)
                for ordinal in range(count):
                    if fill_flags[ordinal] == 1 and weights[ordinal] > 0.0:
                        active.append(ordinal)
                var rounds = 0
                while remaining > 0.0001 and len(active) > 0 and rounds <= count:
                    rounds += 1
                    var active_weight: Float32 = 0.0
                    for active_index in range(len(active)):
                        active_weight += weights[active[active_index]]
                    if active_weight <= 0.0:
                        break
                    var next_active = List[Int](capacity=len(active))
                    var consumed: Float32 = 0.0
                    for active_index in range(len(active)):
                        var ordinal = active[active_index]
                        var share = remaining * weights[ordinal] / active_weight
                        var child = self._child_at(index, ordinal)
                        var maximum = self.records[child].input.style.max_width
                        var room = share
                        if maximum >= 0.0 and allocations[ordinal] + room > maximum:
                            room = maximum - allocations[ordinal]
                            if room < 0.0:
                                room = 0.0
                        allocations[ordinal] += room
                        consumed += room
                        if maximum < 0.0 or allocations[ordinal] + 0.0001 < maximum:
                            next_active.append(ordinal)
                    if consumed <= 0.0001:
                        break
                    remaining -= consumed
                    active = next_active^
        return allocations^

    def _measure_node(
        mut self,
        index: Int,
        available_width: Float32,
        available_height: Float32,
    ) -> Size:
        if index < 0 or index >= len(self.records):
            return Size(0.0, 0.0)
        self.current_stats.node_visits += 1
        var record = self.records[index]
        var first_cache_matches = (
            record.cache_valid
            and record.cache_revision == record.revision
            and _same_float(record.cache_width, available_width)
            and (
                not record.input.container
                or _same_float(record.cache_height, available_height)
            )
        )
        var second_cache_matches = (
            record.cache2_valid
            and record.cache2_revision == record.revision
            and _same_float(record.cache2_width, available_width)
            and (
                not record.input.container
                or _same_float(record.cache2_height, available_height)
            )
        )
        if first_cache_matches:
            self.current_stats.cache_hits += 1
            return record.cached_extent
        if second_cache_matches:
            self.current_stats.cache_hits += 1
            return record.cached_extent2

        var input = record.input
        var measured: Size
        if input.container:
            var padding = input.style.padding
            var inner_width = available_width
            var inner_height = available_height
            if inner_width >= 0.0:
                inner_width -= padding * 2.0
                if inner_width < 0.0:
                    inner_width = 0.0
            if inner_height >= 0.0:
                inner_height -= padding * 2.0
                if inner_height < 0.0:
                    inner_height = 0.0
            var count = self._child_count(index)
            var main: Float32 = 0.0
            var cross: Float32 = 0.0
            var row_allocations = List[Float32]()
            if input.style.axis == LAYOUT_ROW:
                row_allocations = self._row_allocations(
                    index, inner_width, inner_height
                )
            for ordinal in range(count):
                var child = self._child_at(index, ordinal)
                var child_width: Float32
                var child_height: Float32 = -1.0
                if input.style.axis == LAYOUT_COLUMN:
                    child_width = self._cross_constraint(
                        child, input.style.axis, inner_width, inner_height
                    )
                else:
                    child_width = row_allocations[ordinal]
                    child_height = self._cross_constraint(
                        child, input.style.axis, inner_width, inner_height
                    )
                var child_extent = self._measure_node(child, child_width, child_height)
                var child_main: Float32
                var child_cross: Float32
                if input.style.axis == LAYOUT_COLUMN:
                    child_main = self._requested_height(child, child_extent)
                    child_cross = self._requested_width(child, child_extent)
                else:
                    child_main = self._requested_width(child, child_extent)
                    child_cross = self._requested_height(child, child_extent)
                main += child_main
                cross = child_cross if child_cross > cross else cross
            if count > 1:
                main += input.style.gap * Float32(count - 1)
            if input.style.axis == LAYOUT_COLUMN:
                measured = Size(cross + padding * 2.0, main + padding * 2.0)
            else:
                # When the row had a definite width proposal, its allocated
                # track widths are the content extent even if wrapped text's
                # widest line is narrower than the track.
                if available_width >= 0.0:
                    # ``inner_width`` already includes the inter-child gaps;
                    # the allocator subtracts them before distributing track
                    # space and the sum is restored here exactly once.
                    main = inner_width
                measured = Size(main + padding * 2.0, cross + padding * 2.0)
            if input.intrinsic_width > measured.width:
                measured.width = input.intrinsic_width
            if input.intrinsic_height > measured.height:
                measured.height = input.intrinsic_height
        else:
            var chrome_width = input.chrome_width
            var chrome_height = input.chrome_height
            var limit: Float32 = -1.0
            if input.wrap and available_width >= 0.0:
                limit = available_width - chrome_width
                if limit < 0.0:
                    limit = 0.0
            var text_size = _text_measure(input.text, input.font_size, limit)
            measured = Size(
                text_size.width + chrome_width,
                text_size.height + chrome_height,
            )
            if input.intrinsic_width > measured.width:
                measured.width = input.intrinsic_width
            if input.intrinsic_height > measured.height:
                measured.height = input.intrinsic_height
            self.current_stats.leaf_measurements += 1

        measured.width = _clamp(measured.width, input.style.min_width, input.style.max_width)
        measured.height = _clamp(
            measured.height, input.style.min_height, input.style.max_height
        )
        if input.style.width.kind == AXIS_FIXED:
            measured.width = input.style.width.value
        if input.style.height.kind == AXIS_FIXED:
            measured.height = input.style.height.value

        self.records[index].extent = measured
        if (
            self.records[index].cache_valid
            and self.records[index].cache_revision == self.records[index].revision
            and _same_float(self.records[index].cache_width, available_width)
            and (
                not self.records[index].input.container
                or _same_float(self.records[index].cache_height, available_height)
            )
        ):
            self.records[index].cache_width = available_width
            self.records[index].cache_height = available_height
            self.records[index].cached_extent = measured
        elif (
            self.records[index].cache2_valid
            and self.records[index].cache2_revision == self.records[index].revision
            and _same_float(self.records[index].cache2_width, available_width)
            and (
                not self.records[index].input.container
                or _same_float(self.records[index].cache2_height, available_height)
            )
        ):
            self.records[index].cache2_width = available_width
            self.records[index].cache2_height = available_height
            self.records[index].cached_extent2 = measured
        elif not self.records[index].cache_valid:
            self.records[index].cache_valid = True
            self.records[index].cache_revision = self.records[index].revision
            self.records[index].cache_width = available_width
            self.records[index].cache_height = available_height
            self.records[index].cached_extent = measured
        else:
            # Retain the most recent distinct query as the second slot. The
            # first slot remains the stable natural query for the common
            # natural/final-width pair.
            self.records[index].cache2_valid = True
            self.records[index].cache2_revision = self.records[index].revision
            self.records[index].cache2_width = available_width
            self.records[index].cache2_height = available_height
            self.records[index].cached_extent2 = measured
        return measured

    def _place_node(mut self, index: Int, bounds: Rect):
        if index < 0 or index >= len(self.records):
            return
        self.current_stats.node_visits += 1
        var previous = self.records[index].rect
        self.records[index].rect = bounds
        if (
            previous.x != bounds.x
            or previous.y != bounds.y
            or previous.width != bounds.width
            or previous.height != bounds.height
        ):
            self.current_stats.changed_geometry += 1

        var input = self.records[index].input
        # The measurement boundary receives the full allocated border box.
        # Container measurement subtracts its own padding exactly once.
        var measured = self._measure_node(index, bounds.width, bounds.height)
        self.records[index].extent = measured
        self.records[index].overflowed = measured.width > bounds.width or measured.height > bounds.height

        if not input.container:
            return

        var padding_extent = input.style.padding * 2.0
        if bounds.width < padding_extent or bounds.height < padding_extent:
            self.records[index].overflowed = True

        var count = self._child_count(index)
        if count == 0:
            if padding_extent > self.records[index].extent.width:
                self.records[index].extent.width = padding_extent
            if padding_extent > self.records[index].extent.height:
                self.records[index].extent.height = padding_extent
            return
        var padding = input.style.padding
        var inner_width = bounds.width - padding * 2.0
        var inner_height = bounds.height - padding * 2.0
        if inner_width < 0.0:
            inner_width = 0.0
            self.records[index].overflowed = True
        if inner_height < 0.0:
            inner_height = 0.0
            self.records[index].overflowed = True
        var inner_x = bounds.x + padding
        var inner_y = bounds.y + padding
        var main_available = inner_height if input.style.axis == LAYOUT_COLUMN else inner_width
        if main_available < 0.0:
            main_available = 0.0
        var gap_total: Float32 = 0.0
        if count > 1:
            gap_total = input.style.gap * Float32(count - 1)
        var usable_main = main_available - gap_total
        if usable_main < 0.0:
            usable_main = 0.0
            self.records[index].overflowed = True

        var allocations = List[Float32](capacity=count)
        var crosses = List[Float32](capacity=count)
        var weights = List[Float32](capacity=count)
        var fill_flags = List[Int](capacity=count)
        var allocated: Float32 = 0.0
        var weight_total: Float32 = 0.0
        for ordinal in range(count):
            var child = self._child_at(index, ordinal)
            var child_width: Float32 = -1.0
            var child_height: Float32 = -1.0
            if input.style.axis == LAYOUT_COLUMN:
                child_width = self._cross_constraint(
                    child, input.style.axis, inner_width, inner_height
                )
            else:
                child_height = self._cross_constraint(
                    child, input.style.axis, inner_width, inner_height
                )
            var natural = self._measure_node(child, child_width, child_height)
            var child_input = self.records[child].input
            var main_spec = (
                child_input.style.height
                if input.style.axis == LAYOUT_COLUMN
                else child_input.style.width
            )
            var cross_spec = (
                child_input.style.width
                if input.style.axis == LAYOUT_COLUMN
                else child_input.style.height
            )
            var natural_main = (
                self._requested_height(child, natural)
                if input.style.axis == LAYOUT_COLUMN
                else self._requested_width(child, natural)
            )
            var natural_cross = (
                self._requested_width(child, natural)
                if input.style.axis == LAYOUT_COLUMN
                else self._requested_height(child, natural)
            )
            var base: Float32
            var is_fill = 0
            var weight: Float32 = 0.0
            if main_spec.kind == AXIS_FIXED:
                base = main_spec.value
            elif main_spec.kind == AXIS_FILL:
                base = (
                    child_input.style.min_height
                    if input.style.axis == LAYOUT_COLUMN
                    else child_input.style.min_width
                )
                is_fill = 1
                weight = main_spec.value
            else:
                base = natural_main
            if input.style.axis == LAYOUT_COLUMN:
                base = _clamp(base, child_input.style.min_height, child_input.style.max_height)
            else:
                base = _clamp(base, child_input.style.min_width, child_input.style.max_width)
            var cross = inner_width if cross_spec.kind == AXIS_FILL and input.style.axis == LAYOUT_COLUMN else natural_cross
            if cross_spec.kind == AXIS_FIXED:
                cross = cross_spec.value
            elif cross_spec.kind == AXIS_FILL and input.style.axis == LAYOUT_ROW:
                cross = inner_height
            if input.style.axis == LAYOUT_COLUMN:
                cross = _clamp(cross, child_input.style.min_width, child_input.style.max_width)
            else:
                cross = _clamp(cross, child_input.style.min_height, child_input.style.max_height)
            allocations.append(base)
            crosses.append(cross)
            weights.append(weight)
            fill_flags.append(is_fill)
            allocated += base
            if is_fill == 1:
                weight_total += weight

        if allocated > usable_main:
            self.records[index].overflowed = True
        var remaining = usable_main - allocated
        if remaining > 0.0 and weight_total > 0.0:
            var active = List[Int](capacity=count)
            for ordinal in range(count):
                if fill_flags[ordinal] == 1 and weights[ordinal] > 0.0:
                    active.append(ordinal)
            var rounds = 0
            while remaining > 0.0001 and len(active) > 0 and rounds <= count:
                rounds += 1
                var active_weight: Float32 = 0.0
                for active_index in range(len(active)):
                    active_weight += weights[active[active_index]]
                if active_weight <= 0.0:
                    break
                var next_active = List[Int](capacity=len(active))
                var consumed: Float32 = 0.0
                for active_index in range(len(active)):
                    var ordinal = active[active_index]
                    var share = remaining * weights[ordinal] / active_weight
                    var child = self._child_at(index, ordinal)
                    var child_input = self.records[child].input
                    var maximum = (
                        child_input.style.max_height
                        if input.style.axis == LAYOUT_COLUMN
                        else child_input.style.max_width
                    )
                    var room = share
                    if maximum >= 0.0 and allocations[ordinal] + room > maximum:
                        room = maximum - allocations[ordinal]
                        if room < 0.0:
                            room = 0.0
                    allocations[ordinal] += room
                    consumed += room
                    if maximum < 0.0 or allocations[ordinal] + 0.0001 < maximum:
                        next_active.append(ordinal)
                if consumed <= 0.0001:
                    break
                remaining -= consumed
                active = next_active^

        # A row's cross extent can depend on the width allocated in the main
        # axis (wrapped text is the important case).  Re-query those children
        # after flex allocation and before placement.
        if input.style.axis == LAYOUT_ROW:
            for ordinal in range(count):
                var child = self._child_at(index, ordinal)
                var child_input = self.records[child].input
                if (
                    child_input.wrap
                    or child_input.style.height.kind == AXIS_CONTENT
                ):
                    var reflowed = self._measure_node(child, allocations[ordinal], -1.0)
                    if child_input.style.height.kind == AXIS_CONTENT:
                        crosses[ordinal] = _clamp(
                            self._requested_height(child, reflowed),
                            child_input.style.min_height,
                            child_input.style.max_height,
                        )

        var cursor: Float32 = 0.0
        var max_cross: Float32 = 0.0
        for ordinal in range(count):
            var child = self._child_at(index, ordinal)
            var main_extent = allocations[ordinal]
            var cross_extent = crosses[ordinal]
            var child_bounds: Rect
            if input.style.axis == LAYOUT_COLUMN:
                child_bounds = Rect(
                    inner_x,
                    inner_y + cursor,
                    cross_extent,
                    main_extent,
                )
            else:
                child_bounds = Rect(
                    inner_x + cursor,
                    inner_y,
                    main_extent,
                    cross_extent,
                )
            self._place_node(child, child_bounds)
            if self.records[child].overflowed:
                self.records[index].overflowed = True
            if cross_extent > max_cross:
                max_cross = cross_extent
            cursor += main_extent
            if ordinal + 1 < count:
                cursor += input.style.gap

        # Publish the extent of the laid-out, unscrolled child content. The
        # measured extent is still retained in the query cache; this public
        # value must include allocations that exceed a fixed viewport so
        # scroll containers can expose their true range.
        var padding_total = input.style.padding * 2.0
        var published = measured
        if input.style.axis == LAYOUT_COLUMN:
            var actual = Size(max_cross + padding_total, cursor + padding_total)
            if actual.width > published.width:
                published.width = actual.width
            if actual.height > published.height:
                published.height = actual.height
        else:
            var actual = Size(cursor + padding_total, max_cross + padding_total)
            if actual.width > published.width:
                published.width = actual.width
            if actual.height > published.height:
                published.height = actual.height
        self.records[index].extent = published
        if published.width > bounds.width or published.height > bounds.height:
            self.records[index].overflowed = True
        if cursor > main_available + 0.0001:
            self.records[index].overflowed = True
