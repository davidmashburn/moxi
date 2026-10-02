"""Optional retained flow/grid candidate, linked with native/retained_layout.

Single-threaded context; native snapshots retain the exact measured paragraph.
The module stays provisional while composed-screen and release gates are open.
"""
from std.collections import List, Dict
from std.ffi import external_call
from std.memory import ArcPointer, Pointer
from .geometry import Point, Rect, Size
from .accessibility import AccessibilitySnapshot, Semantics, ROLE_CONTAINER, ROLE_LABEL, ROLE_CANVAS
from .paint import PaintCommand, PANEL_KIND
from .macos import MacOSRenderer
from .native_paragraph import NativeParagraph

comptime CONTENT = 0
comptime FIXED = 1
comptime FILL = 2
comptime FRACTION = 3
comptime MIN_CONTENT = 4
comptime MAX_CONTENT = 5
comptime FIT_CONTENT = 6
comptime COLUMN = 0
comptime ROW = 1
comptime WRAP = 2
comptime GRID = 3
comptime STACK = 4
comptime LEAF = 5
comptime COLLAPSED = 6


struct RetainedStyle(ImplicitlyCopyable):
    """Validated style. Fraction means a fraction of the containing axis;
    weighted remaining space uses grow. Shrink is explicitly opt-in.

    Field order is the 80-byte C Spec ABI; all fields have 32-bit alignment.
    """
    var kind: Int32
    var width_kind: Int32
    var height_kind: Int32
    var width: Float32
    var height: Float32
    var min_width: Float32
    var min_height: Float32
    var max_width: Float32
    var max_height: Float32
    var gap: Float32
    var padding: Float32
    var grow: Float32
    var shrink: Float32
    var align: Int32
    var rtl: Int32
    var overflow: Int32
    var column: Int32
    var column_span: Int32
    var row: Int32
    var row_span: Int32

    def __init__(out self, kind: Int = COLUMN, width_kind: Int = CONTENT,
                 height_kind: Int = CONTENT, width: Float32 = 0, height: Float32 = 0,
                 min_width: Float32 = 0, min_height: Float32 = 0,
                 max_width: Float32 = 3.4028234e38, max_height: Float32 = 3.4028234e38,
                 gap: Float32 = 0, padding: Float32 = 0, grow: Float32 = 0,
                 shrink: Float32 = 0, align: Int = 0, rtl: Bool = False,
                 overflow: Int = 0, column: Int = 0, column_span: Int = 1,
                 row: Int = 0, row_span: Int = 1):
        self.kind = Int32(kind)
        self.width_kind = Int32(width_kind)
        self.height_kind = Int32(height_kind)
        self.width = width
        self.height = height
        self.min_width = min_width
        self.min_height = min_height
        self.max_width = max_width
        self.max_height = max_height
        self.gap = gap
        self.padding = padding
        self.grow = grow
        self.shrink = shrink
        self.align = Int32(align)
        self.rtl = Int32(Int(rtl))
        self.overflow = Int32(overflow)
        self.column = Int32(column)
        self.column_span = Int32(column_span)
        self.row = Int32(row)
        self.row_span = Int32(row_span)


struct RetainedTrack(ImplicitlyCopyable):
    """Track limits: auto=0, fixed=1, min-content=2, max-content=3, fr=4(max)."""
    var min_kind: Int32
    var max_kind: Int32
    var minimum: Float32
    var maximum: Float32

    def __init__(out self, min_kind: Int = 0, max_kind: Int = 0,
                 minimum: Float32 = 0, maximum: Float32 = 0):
        self.min_kind = Int32(min_kind)
        self.max_kind = Int32(max_kind)
        self.minimum = minimum
        self.maximum = maximum

    @staticmethod
    def fixed(points: Float32) -> Self:
        return Self(1, 1, points, points)

    @staticmethod
    def fraction(weight: Float32, minimum: Float32 = 0) -> Self:
        return Self(1, 4, minimum, weight)


struct _RetainedSnapshotStorage:
    var handle: UInt
    def __init__(out self, handle: UInt = 0):
        self.handle = handle
    def __deinit__(deinit self):
        if self.handle != 0:
            external_call["moxi_layout_snapshot_release", NoneType](self.handle)


struct _RetainedCandidateStorage:
    var handle: UInt
    def __init__(out self, handle: UInt):
        self.handle = handle
    def __deinit__(deinit self):
        external_call["moxi_layout_candidate_release", NoneType](self.handle)


struct RetainedPlacement(ImplicitlyCopyable):
    var key: UInt64
    var x: Float32
    var y: Float32
    var width: Float32
    var height: Float32
    def __init__(out self, key: Int, rect: Rect):
        self.key = UInt64(key)
        self.x = rect.x
        self.y = rect.y
        self.width = rect.width
        self.height = rect.height


struct RetainedOutput(ImplicitlyCopyable):
    var key: Int
    var mount: UInt64
    var rect: Rect
    var clip: Rect
    var hidden: Bool
    var paragraph: NativeParagraph
    var has_paragraph: Bool
    var semantics: Semantics
    var font: Float32

    def __init__(out self, key: Int, mount: UInt64, rect: Rect, clip: Rect,
                 hidden: Bool, payload: UInt, semantics: Semantics, font: Float32):
        self.key = key
        self.mount = mount
        self.rect = rect
        self.clip = clip
        self.hidden = hidden
        self.paragraph = NativeParagraph.from_handle(payload)
        self.has_paragraph = payload != 0
        self.semantics = semantics
        self.semantics.bounds = rect
        self.font = font


struct RetainedSnapshot(ImplicitlyCopyable):
    """One immutable publication drives paint, hit tests and accessibility.

    Clipping affects paint/input; offscreen semantic nodes retain logical bounds.
    """
    var generation: UInt64
    var _storage: ArcPointer[_RetainedSnapshotStorage]
    var _outputs: ArcPointer[List[RetainedOutput]]

    def __init__(out self):
        self.generation = 0
        self._storage = ArcPointer(_RetainedSnapshotStorage())
        self._outputs = ArcPointer(List[RetainedOutput]())

    def count(self) -> Int:
        return len(self._outputs[])

    def output(self, key: Int) raises -> RetainedOutput:
        for output in self._outputs[]:
            if output.key == key:
                return output
        raise Error("Unknown retained geometry key")

    def bounds(self, key: Int) raises -> Rect:
        return self.output(key).rect

    def hit_test(self, point: Point) -> Int:
        for i in range(self.count() - 1, -1, -1):
            var output = self._outputs[][i]
            if not output.hidden and output.rect.contains(point) and output.clip.contains(point):
                return output.key
        return -1

    def accessibility(self) -> AccessibilitySnapshot:
        var result = AccessibilitySnapshot()
        for output in self._outputs[]:
            if not output.hidden:
                result.append(output.semantics)
        return result^

    def paint_commands(self) -> List[PaintCommand]:
        var result = List[PaintCommand]()
        for output in self._outputs[]:
            if output.hidden or output.semantics.role == ROLE_CONTAINER:
                continue
            var command = PaintCommand(output.semantics.label, output.rect)
            command.id = output.key
            command.slot = len(result)
            command.style.font_size = output.font
            command.has_clip = True
            command.clip_bounds = output.clip
            command.wrap_text = output.has_paragraph
            if not output.has_paragraph:
                command.kind = PANEL_KIND
            result.append(command)
        return result^


def draw_retained_snapshot(mut renderer: MacOSRenderer, snapshot: RetainedSnapshot) raises:
    var slot = 0
    for output in snapshot._outputs[]:
        if output.hidden or output.semantics.role == ROLE_CONTAINER:
            continue
        var command = PaintCommand(output.semantics.label, output.rect)
        command.id = output.key
        command.slot = slot
        command.style.font_size = output.font
        command.has_clip = True
        command.clip_bounds = output.clip
        command.wrap_text = output.has_paragraph
        if not output.has_paragraph:
            command.kind = PANEL_KIND
        renderer.draw(command)
        if output.has_paragraph:
            external_call["moxi_window_set_paragraph_at", NoneType](Int32(slot), output.paragraph._storage[].handle)
        slot += 1


struct RetainedPlan:
    var snapshot: RetainedSnapshot
    var _storage: ArcPointer[_RetainedCandidateStorage]
    var _semantics: Dict[Int, Semantics]
    var _fonts: Dict[Int, Float32]
    var _metadata_revision: Int
    def __init__(out self, handle: UInt, snapshot: RetainedSnapshot,
                 semantics: Dict[Int, Semantics], fonts: Dict[Int, Float32], revision: Int):
        self.snapshot = snapshot
        self._storage = ArcPointer(_RetainedCandidateStorage(handle))
        self._semantics = semantics.copy()
        self._fonts = fonts.copy()
        self._metadata_revision = revision


struct RetainedLayout:
    """Unique owner of a keyed tree. Use snapshot() after a failed transaction to
    obtain recovery geometry with removed identities already tombstoned.
    """
    var _handle: UInt
    var _semantics: Dict[Int, Semantics]
    var _fonts: Dict[Int, Float32]
    var _published_semantics: Dict[Int, Semantics]
    var _published_fonts: Dict[Int, Float32]
    var _metadata_revision: Int

    def __init__(out self) raises:
        self._handle = external_call["moxi_layout_create", UInt](
            external_call["moxi_layout_native_measure_address", UInt](),
            external_call["moxi_layout_native_release_address", UInt]())
        self._semantics = Dict[Int, Semantics]()
        self._fonts = Dict[Int, Float32]()
        self._published_semantics = Dict[Int, Semantics]()
        self._published_fonts = Dict[Int, Float32]()
        self._metadata_revision = 0
        if self._handle == 0:
            raise Error("Cannot create retained layout context")

    def __deinit__(deinit self):
        if self._handle != 0:
            external_call["moxi_layout_destroy", NoneType](self._handle)

    def _check(self, status: Int32) raises:
        if status != 0:
            var message = external_call["moxi_layout_error", Pointer[UInt8, MutAnyOrigin]](self._handle)
            raise Error(String(message))

    def set_region(mut self, key: Int, style: RetainedStyle, label: String = "") raises:
        if key <= 0:
            raise Error("Retained layout keys must be positive")
        var abi = style
        self._check(external_call["moxi_layout_set_region", Int32](self._handle, UInt64(key), Pointer(to=abi)))
        self._semantics[key] = Semantics(key, ROLE_CONTAINER, label)
        self._fonts[key] = Float32(16)
        self._metadata_revision += 1

    def set_box(mut self, key: Int, style: RetainedStyle, label: String = "") raises:
        self.set_region(key, style, label)
        self._semantics[key] = Semantics(key, ROLE_CANVAS, label)

    def set_paragraph(mut self, key: Int, text: String, font: Float32 = 16,
                      style: RetainedStyle = RetainedStyle(LEAF), direction: Int = 0) raises:
        if key <= 0 or "\x00" in text:
            raise Error("Invalid paragraph key or embedded NUL")
        var abi = style
        var source = text
        var c_source = source.as_c_string_slice()
        self._check(external_call["moxi_layout_set_node", Int32](self._handle, UInt64(key), Pointer(to=abi), c_source.ptr(), font, Int32(direction)))
        self._semantics[key] = Semantics(key, ROLE_LABEL, text)
        self._fonts[key] = font
        self._metadata_revision += 1

    def set_semantics(mut self, key: Int, semantics: Semantics) raises:
        if key not in self._semantics or semantics.id != key:
            raise Error("Semantics must identify an existing layout key")
        self._semantics[key] = semantics
        self._metadata_revision += 1

    def children(mut self, key: Int, keys: List[Int]) raises:
        var values = List[UInt64]()
        for child in keys:
            if child <= 0:
                raise Error("Child keys must be positive")
            values.append(UInt64(child))
        self._check(external_call["moxi_layout_children", Int32](self._handle, UInt64(key), values.unsafe_ptr(), UInt(len(values))))

    def tracks(mut self, key: Int, tracks: List[RetainedTrack], rows: Bool = False) raises:
        var values = tracks.copy()
        self._check(external_call["moxi_layout_tracks", Int32](self._handle, UInt64(key), Int32(Int(rows)), values.unsafe_ptr(), UInt(len(values))))

    def hide(mut self, key: Int, hidden: Bool) raises:
        self._check(external_call["moxi_layout_hidden", Int32](self._handle, UInt64(key), Int32(Int(hidden))))

    def remove(mut self, key: Int) raises:
        self._check(external_call["moxi_layout_remove", Int32](self._handle, UInt64(key)))
        var kept = Dict[Int, Semantics]()
        var fonts = Dict[Int, Float32]()
        for candidate in self._semantics:
            if external_call["moxi_layout_has_key", Int32](self._handle, UInt64(candidate)) != 0:
                kept[candidate] = self._semantics[candidate]
                fonts[candidate] = self._fonts[candidate]
        self._semantics = kept^
        self._fonts = fonts^

    def invalidate_environment(mut self) raises:
        self._check(external_call["moxi_layout_invalidate", Int32](self._handle))

    def place(mut self, placements: List[RetainedPlacement]) raises:
        var values = placements.copy()
        self._check(external_call["moxi_layout_place", Int32](self._handle, values.unsafe_ptr(), UInt(len(values))))

    def clear_placement(mut self, key: Int) raises:
        self._check(external_call["moxi_layout_clear_placement", Int32](self._handle, UInt64(key)))

    def clip(mut self, key: Int, rect: Rect) raises:
        self._check(external_call["moxi_layout_clip", Int32](self._handle, UInt64(key),rect.x,rect.y,rect.width,rect.height))

    def stage(mut self, root: Int, size: Size) raises -> RetainedPlan:
        var handle: UInt = 0
        self._check(external_call["moxi_layout_stage", Int32](self._handle, UInt64(root), size.width, size.height, Pointer(to=handle)))
        var snapshot = self._copy_snapshot(external_call["moxi_layout_candidate_snapshot", UInt](handle), self._semantics, self._fonts)
        return RetainedPlan(handle, snapshot, self._semantics, self._fonts, self._metadata_revision)

    def commit(mut self, plan: RetainedPlan) raises -> RetainedSnapshot:
        if plan._metadata_revision != self._metadata_revision:
            raise Error("Stale semantic metadata in layout candidate")
        var result: UInt = 0
        self._check(external_call["moxi_layout_commit", Int32](self._handle, plan._storage[].handle, Pointer(to=result)))
        self._published_semantics = plan._semantics.copy()
        self._published_fonts = plan._fonts.copy()
        return self._copy_snapshot(result, self._published_semantics, self._published_fonts)

    def layout(mut self, root: Int, size: Size) raises -> RetainedSnapshot:
        var result: UInt = 0
        self._check(external_call["moxi_layout_compute", Int32](self._handle, UInt64(root), size.width, size.height, Pointer(to=result)))
        self._published_semantics = self._semantics.copy()
        self._published_fonts = self._fonts.copy()
        return self._copy_snapshot(result, self._published_semantics, self._published_fonts)

    def snapshot(self) raises -> RetainedSnapshot:
        return self._copy_snapshot(external_call["moxi_layout_snapshot", UInt](self._handle), self._published_semantics, self._published_fonts)

    def _copy_snapshot(self, handle: UInt, metadata: Dict[Int, Semantics], fonts: Dict[Int, Float32]) raises -> RetainedSnapshot:
        var result = RetainedSnapshot()
        result._storage = ArcPointer(_RetainedSnapshotStorage(handle))
        result.generation = external_call["moxi_layout_snapshot_generation", UInt64](handle)
        var count = Int(external_call["moxi_layout_snapshot_count", UInt](handle))
        for i in range(count):
            var key = Int(external_call["moxi_layout_snapshot_integer", UInt64](handle, UInt(i), Int32(0)))
            var mount = external_call["moxi_layout_snapshot_integer", UInt64](handle, UInt(i), Int32(1))
            var parent = Int(external_call["moxi_layout_snapshot_integer", UInt64](handle, UInt(i), Int32(2)))
            var hidden = external_call["moxi_layout_snapshot_integer", UInt64](handle, UInt(i), Int32(3)) != 0
            var payload = UInt(external_call["moxi_layout_snapshot_integer", UInt64](handle, UInt(i), Int32(4)))
            var rect = self._rect(handle, i, 0)
            var clip = self._rect(handle, i, 4)
            var semantics = metadata.get(key, Semantics(key, ROLE_CONTAINER, ""))
            semantics.parent_id = parent
            result._outputs[].append(RetainedOutput(key, mount, rect, clip, hidden, payload, semantics, fonts.get(key, Float32(16))))
        return result^

    def _rect(self, handle: UInt, index: Int, field: Int) -> Rect:
        return Rect(external_call["moxi_layout_snapshot_float", Float32](handle, UInt(index), UInt(field)),
                    external_call["moxi_layout_snapshot_float", Float32](handle, UInt(index), UInt(field+1)),
                    external_call["moxi_layout_snapshot_float", Float32](handle, UInt(index), UInt(field+2)),
                    external_call["moxi_layout_snapshot_float", Float32](handle, UInt(index), UInt(field+3)))

    def measurements(self) -> UInt64:
        return external_call["moxi_layout_counter", UInt64](self._handle, Int32(0))

    def mutations(self) -> UInt64:
        return external_call["moxi_layout_counter", UInt64](self._handle, Int32(1))

    def measurement_nanoseconds(self) -> UInt64:
        """Cumulative provider callback time; excludes cached lookups and arrangement."""
        return external_call["moxi_layout_counter", UInt64](self._handle, Int32(3))
