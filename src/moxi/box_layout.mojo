"""Provisional retained box protocol: exact width, height-independent leaves.

This first profile supports paragraph and fixed-content leaves in one region.
It deliberately has no intrinsic-query, nested-region, or viewport protocol yet.
Policies stage placements; only commit publishes paint, input and AX geometry.
Underscored fields are runtime-owned; custom policies use measure/plan/place.
"""

from std.collections import List
from std.memory import ArcPointer
from std.math import isfinite
from .geometry import Point, Rect, Size
from .accessibility import AccessibilitySnapshot, Semantics, ROLE_LABEL, ROLE_CANVAS
from .paint import PaintCommand, PANEL_KIND


def _extent(value: Float32) raises:
    if not isfinite(value) or value < 0:
        raise Error("Layout extents must be finite and nonnegative")


struct BoxMetrics(ImplicitlyCopyable):
    var size: Size
    var first_baseline: Float32
    var last_baseline: Float32

    def __init__(out self, size: Size, first: Float32 = -1, last: Float32 = -1):
        self.size = size
        self.first_baseline = first
        self.last_baseline = last


trait ParagraphPayload(ImplicitlyCopyable & Deinitable):
    """Immutable height-for-width result, retained by caches and snapshots."""

    def __init__(out self): ...

    @staticmethod
    def create(text: String, font_size: Float32, width: Float32, direction: Int) raises -> Self: ...

    def metrics(self) -> BoxMetrics: ...


struct MeasuredBox[P: ParagraphPayload](ImplicitlyCopyable):
    var key: Int
    var metrics: BoxMetrics
    var _payload: Self.P
    var _owner: ArcPointer[Int]
    var _revision: Int
    var _environment: Int

    def __init__(out self, key: Int, metrics: BoxMetrics, payload: Self.P,
                 owner: ArcPointer[Int], revision: Int, environment: Int):
        self.key = key
        self.metrics = metrics
        self._payload = payload
        self._owner = owner
        self._revision = revision
        self._environment = environment


struct _BoxLeaf[P: ParagraphPayload]:
    var key: Int
    var text: String
    var font: Float32
    var direction: Int
    var box_height: Float32
    var revision: Int
    var cache: List[MeasuredBox[Self.P]]

    def __init__(out self, key: Int, text: String, font: Float32,
                 direction: Int, box_height: Float32, revision: Int):
        self.key = key
        self.text = text
        self.font = font
        self.direction = direction
        self.box_height = box_height
        self.revision = revision
        self.cache = List[MeasuredBox[Self.P]]()


struct BoxPlacement[P: ParagraphPayload](ImplicitlyCopyable):
    var rect: Rect
    var measured: MeasuredBox[Self.P]

    def __init__(out self, rect: Rect, measured: MeasuredBox[Self.P]):
        self.rect = rect
        self.measured = measured


struct PlacementPlan[P: ParagraphPayload]:
    var _owner: ArcPointer[Int]
    var _revision: Int
    var _base_generation: Int
    var _environment: Int
    var _size: Size
    var _placements: List[BoxPlacement[Self.P]]

    def __init__(out self, owner: ArcPointer[Int], revision: Int,
                 generation: Int, environment: Int, size: Size):
        self._owner = owner
        self._revision = revision
        self._base_generation = generation
        self._environment = environment
        self._size = size
        self._placements = List[BoxPlacement[Self.P]]()

    def place(mut self, measured: MeasuredBox[Self.P], rect: Rect):
        """Stage one direct child. Validation and publication happen at commit."""
        self._placements.append(BoxPlacement(rect, measured))


struct _BoxOutput[P: ParagraphPayload](ImplicitlyCopyable):
    var key: Int
    var text: String
    var font: Float32
    var paragraph: Bool
    var rect: Rect
    var measured: MeasuredBox[Self.P]

    def __init__(out self, leaf: _BoxLeaf[Self.P], placement: BoxPlacement[Self.P]):
        self.key = leaf.key
        self.text = leaf.text
        self.font = leaf.font
        self.paragraph = leaf.box_height < 0
        self.rect = placement.rect
        self.measured = placement.measured


struct GeometrySnapshot[P: ParagraphPayload](ImplicitlyCopyable):
    """Read-only by convention; old snapshots retain their own paragraph payloads."""

    var generation: Int
    var _size: Size
    var _outputs: ArcPointer[List[_BoxOutput[Self.P]]]

    def __init__(out self):
        self.generation = 0
        self._size = Size(0, 0)
        self._outputs = ArcPointer(List[_BoxOutput[Self.P]]())

    def count(self) -> Int:
        return len(self._outputs[])

    def bounds(self, key: Int) raises -> Rect:
        for output in self._outputs[]:
            if output.key == key:
                return output.rect
        raise Error("Unknown committed child")

    def hit_test(self, point: Point) -> Int:
        var viewport = Rect(0, 0, self._size.width, self._size.height)
        for i in range(len(self._outputs[]) - 1, -1, -1):
            if self._outputs[][i].rect.intersection(viewport).contains(point):
                return self._outputs[][i].key
        return -1

    def paint_commands(self) -> List[PaintCommand]:
        var commands = List[PaintCommand]()
        var viewport = Rect(0, 0, self._size.width, self._size.height)
        for i in range(len(self._outputs[])):
            var output = self._outputs[][i]
            var command = PaintCommand(output.text, output.rect)
            command.id = output.key
            command.slot = i
            command.style.font_size = output.font
            command.wrap_text = output.paragraph
            command.has_clip = True
            command.clip_bounds = viewport.intersection(output.rect)
            if not output.paragraph:
                command.kind = PANEL_KIND
            commands.append(command)
        return commands^

    def accessibility(self) -> AccessibilitySnapshot:
        var snapshot = AccessibilitySnapshot()
        var viewport = Rect(0, 0, self._size.width, self._size.height)
        for output in self._outputs[]:
            var bounds = output.rect.intersection(viewport)
            if bounds.width <= 0 or bounds.height <= 0:
                continue
            var node = Semantics(output.key,
                ROLE_LABEL if output.paragraph else ROLE_CANVAS, output.text)
            node.bounds = bounds
            snapshot.append(node)
        return snapshot^


struct BoxLayoutContext[P: ParagraphPayload]:
    """Single-owner region. Declaration changes invalidate staged plans atomically.

    Two exact-width measurements per leaf are retained; eviction never invalidates
    a snapshot. The provider declares block-independent metrics for this profile.
    Environment changes (fonts/fallback/scale) explicitly invalidate all leaves.
    """

    var _owner: ArcPointer[Int]
    var _leaves: List[_BoxLeaf[Self.P]]
    var _revision: Int
    var _environment: Int
    var _snapshot: GeometrySnapshot[Self.P]
    var leaf_measurements: Int

    def __init__(out self):
        self._owner = ArcPointer(0)
        self._leaves = List[_BoxLeaf[Self.P]]()
        self._revision = 0
        self._environment = 0
        self._snapshot = GeometrySnapshot[Self.P]()
        self.leaf_measurements = 0

    def _index(self, key: Int) -> Int:
        for i in range(len(self._leaves)):
            if self._leaves[i].key == key:
                return i
        return -1

    def _set(mut self, key: Int, text: String, font: Float32, direction: Int,
             box_height: Float32):
        var index = self._index(key)
        if index >= 0:
            if self._leaves[index].text == text and self._leaves[index].font == font and self._leaves[index].direction == direction and self._leaves[index].box_height == box_height:
                return
        self._revision += 1
        var leaf = _BoxLeaf[Self.P](key, text, font, direction, box_height, self._revision)
        if index >= 0:
            self._leaves[index] = leaf^
        else:
            self._leaves.append(leaf^)

    def set_paragraph(mut self, key: Int, text: String, font_size: Float32 = 16,
                      direction: Int = 0) raises:
        _extent(font_size)
        if font_size == 0 or key < 0 or direction < 0 or direction > 2:
            raise Error("Invalid paragraph declaration")
        self._set(key, text, font_size, direction, -1)

    def set_box(mut self, key: Int, label: String, minimum_height: Float32) raises:
        _extent(minimum_height)
        if key < 0:
            raise Error("Invalid box key")
        self._set(key, label, 0, 0, minimum_height)

    def remove(mut self, key: Int):
        var index = self._index(key)
        if index >= 0:
            _ = self._leaves.pop(index)
            self._revision += 1

    def invalidate_environment(mut self):
        self._environment += 1
        for i in range(len(self._leaves)):
            self._leaves[i].cache.clear()

    def measure(mut self, key: Int, exact_width: Float32) raises -> MeasuredBox[Self.P]:
        _extent(exact_width)
        var index = self._index(key)
        if index < 0:
            raise Error("Unknown layout child")
        for item in self._leaves[index].cache:
            if item.metrics.size.width == exact_width:
                return item
        var payload = Self.P()
        var metrics = BoxMetrics(Size(exact_width, self._leaves[index].box_height))
        if self._leaves[index].box_height < 0:
            payload = Self.P.create(self._leaves[index].text, self._leaves[index].font,
                                    exact_width, self._leaves[index].direction)
            metrics = payload.metrics()
        _extent(metrics.size.width)
        _extent(metrics.size.height)
        if metrics.size.width != exact_width:
            raise Error("Paragraph provider changed the exact width")
        if not isfinite(metrics.first_baseline) or not isfinite(metrics.last_baseline):
            raise Error("Invalid paragraph baseline")
        self.leaf_measurements += 1
        var result = MeasuredBox(key, metrics, payload, self._owner,
                                 self._leaves[index].revision, self._environment)
        if len(self._leaves[index].cache) == 2:
            _ = self._leaves[index].cache.pop(0)
        self._leaves[index].cache.append(result)
        return result

    def plan(self, size: Size) raises -> PlacementPlan[Self.P]:
        _extent(size.width)
        _extent(size.height)
        return PlacementPlan[Self.P](self._owner, self._revision, self._snapshot.generation,
                                      self._environment, size)

    def commit(mut self, plan: PlacementPlan[Self.P]) raises:
        if plan._owner.ptr() != self._owner.ptr() or plan._revision != self._revision or plan._environment != self._environment or plan._base_generation != self._snapshot.generation:
            raise Error("Foreign or stale layout plan")
        if len(plan._placements) != len(self._leaves):
            raise Error("Every direct child needs one placement")
        var next = GeometrySnapshot[Self.P]()
        next._size = plan._size
        next.generation = self._snapshot.generation + 1
        var seen = List[Int]()
        for item in plan._placements:
            var placement = item
            var token = placement.measured
            var index = self._index(token.key)
            if index < 0 or token._owner.ptr() != self._owner.ptr():
                raise Error("Foreign measurement")
            if token._revision != self._leaves[index].revision or token._environment != self._environment:
                raise Error("Stale measurement")
            for key in seen:
                if key == token.key:
                    raise Error("Duplicate placement")
            seen.append(token.key)
            var rect = placement.rect
            _extent(rect.width)
            _extent(rect.height)
            if not isfinite(rect.x) or not isfinite(rect.y) or rect.width != token.metrics.size.width:
                raise Error("Placement must use a valid final-width measurement")
            next._outputs[].append(_BoxOutput(self._leaves[index], placement))
        self._snapshot = next^

    def snapshot(self) -> GeometrySnapshot[Self.P]:
        return self._snapshot


trait BoxLayout:
    """Pure policy hooks. Measurement may populate only the region's caches."""

    def measure[P: ParagraphPayload](self, mut context: BoxLayoutContext[P], width: Float32) raises -> BoxMetrics: ...
    def arrange[P: ParagraphPayload](self, mut context: BoxLayoutContext[P], size: Size) raises -> PlacementPlan[P]: ...
