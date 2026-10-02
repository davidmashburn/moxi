"""Mojo-owned retained flow/grid candidate with native paragraph measurements.

Single-threaded context; Mojo snapshots retain the exact measured paragraph.
The module stays provisional while composed-screen and release gates are open.
"""
from std.collections import List, Dict
from std.ffi import external_call
from std.memory import ArcPointer
from .geometry import Point, Rect, Size
from .accessibility import AccessibilitySnapshot, Semantics, ROLE_CONTAINER, ROLE_LABEL, ROLE_CANVAS
from .paint import PaintCommand, PANEL_KIND
from .macos import MacOSRenderer
from .native_paragraph import NativeParagraph

from .retained_engine import RetainedEngine, EnginePlan, EngineSnapshot, RetainedStyle, RetainedTrack, RetainedPlacement, CONTENT, FIXED, FILL, FRACTION, MIN_CONTENT, MAX_CONTENT, FIT_CONTENT, COLUMN, ROW, WRAP, GRID, STACK, LEAF, COLLAPSED


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
                 hidden: Bool, payload: NativeParagraph, has_paragraph: Bool, semantics: Semantics, font: Float32):
        self.key = key
        self.mount = mount
        self.rect = rect
        self.clip = clip
        self.hidden = hidden
        self.paragraph = payload
        self.has_paragraph = has_paragraph
        self.semantics = semantics
        self.semantics.bounds = rect
        self.font = font


struct RetainedSnapshot(ImplicitlyCopyable):
    """One immutable publication drives paint, hit tests and accessibility.

    Clipping affects paint/input; offscreen semantic nodes retain logical bounds.
    """
    var generation: UInt64
    var _outputs: ArcPointer[List[RetainedOutput]]

    def __init__(out self):
        self.generation = 0
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
    var _engine_plan: EnginePlan[NativeParagraph]
    var _semantics: Dict[Int, Semantics]
    var _fonts: Dict[Int, Float32]
    var _metadata_revision: Int
    def __init__(out self, var plan: EnginePlan[NativeParagraph], snapshot: RetainedSnapshot,
                 semantics: Dict[Int, Semantics], fonts: Dict[Int, Float32], revision: Int):
        self.snapshot = snapshot
        self._engine_plan = plan^
        self._semantics = semantics.copy()
        self._fonts = fonts.copy()
        self._metadata_revision = revision


struct RetainedLayout:
    """Mojo owner of a keyed tree, staged geometry, and paragraph caches.

    snapshot() after removal includes tombstones even if the next layout fails.
    """
    var _engine: RetainedEngine[NativeParagraph]
    var _semantics: Dict[Int, Semantics]
    var _fonts: Dict[Int, Float32]
    var _published_semantics: Dict[Int, Semantics]
    var _published_fonts: Dict[Int, Float32]
    var _metadata_revision: Int

    def __init__(out self) raises:
        self._engine = RetainedEngine[NativeParagraph]()
        self._semantics = Dict[Int, Semantics]()
        self._fonts = Dict[Int, Float32]()
        self._published_semantics = Dict[Int, Semantics]()
        self._published_fonts = Dict[Int, Float32]()
        self._metadata_revision = 0

    def set_region(mut self, key: Int, style: RetainedStyle, label: String = "") raises:
        self._engine.set_node(key,style)
        self._semantics[key] = Semantics(key, ROLE_CONTAINER, label)
        self._fonts[key] = Float32(16)
        self._metadata_revision += 1

    def set_box(mut self, key: Int, style: RetainedStyle, label: String = "") raises:
        self.set_region(key, style, label)
        self._semantics[key] = Semantics(key, ROLE_CANVAS, label)

    def set_paragraph(mut self, key: Int, text: String, font: Float32 = 16,
                      style: RetainedStyle = RetainedStyle(LEAF), direction: Int = 0) raises:
        self._engine.set_node(key,style,True,text,font,direction)
        self._semantics[key] = Semantics(key, ROLE_LABEL, text)
        self._fonts[key] = font
        self._metadata_revision += 1

    def set_semantics(mut self, key: Int, semantics: Semantics) raises:
        if key not in self._semantics or semantics.id != key:
            raise Error("Semantics must identify an existing layout key")
        self._semantics[key] = semantics
        self._metadata_revision += 1

    def children(mut self, key: Int, keys: List[Int]) raises:
        self._engine.children(key,keys)

    def tracks(mut self, key: Int, tracks: List[RetainedTrack], rows: Bool = False) raises:
        self._engine.tracks(key,tracks,rows)

    def hide(mut self, key: Int, hidden: Bool) raises:
        self._engine.hide(key,hidden)

    def remove(mut self, key: Int) raises:
        self._engine.remove(key)
        var kept = Dict[Int, Semantics]()
        var fonts = Dict[Int, Float32]()
        for candidate in self._semantics:
            if candidate in self._engine.indices:
                kept[candidate] = self._semantics[candidate]
                fonts[candidate] = self._fonts[candidate]
        self._semantics = kept^
        self._fonts = fonts^
        self._metadata_revision += 1

    def invalidate_environment(mut self) raises:
        self._engine.invalidate_environment()

    def place(mut self, placements: List[RetainedPlacement]) raises:
        self._engine.place(placements)

    def clear_placement(mut self, key: Int) raises:
        self._engine.clear_placement(key)

    def clip(mut self, key: Int, rect: Rect) raises:
        self._engine.clip(key,rect)

    def stage(mut self, root: Int, size: Size) raises -> RetainedPlan:
        var plan = self._engine.stage(root,size)
        var snapshot = self._copy_snapshot(plan.snapshot,self._semantics,self._fonts)
        return RetainedPlan(plan^,snapshot,self._semantics,self._fonts,self._metadata_revision)

    def commit(mut self, plan: RetainedPlan) raises -> RetainedSnapshot:
        if plan._metadata_revision != self._metadata_revision:
            raise Error("Stale semantic metadata in layout candidate")
        var result = self._engine.commit(plan._engine_plan)
        self._published_semantics = plan._semantics.copy()
        self._published_fonts = plan._fonts.copy()
        return self._copy_snapshot(result,self._published_semantics,self._published_fonts)

    def layout(mut self, root: Int, size: Size) raises -> RetainedSnapshot:
        var plan = self.stage(root,size)
        return self.commit(plan)

    def snapshot(self) raises -> RetainedSnapshot:
        return self._copy_snapshot(self._engine.published,self._published_semantics,self._published_fonts)

    def _copy_snapshot(self, snapshot: EngineSnapshot[NativeParagraph], metadata: Dict[Int, Semantics], fonts: Dict[Int, Float32]) -> RetainedSnapshot:
        var result = RetainedSnapshot()
        result.generation = snapshot.generation
        for output in snapshot.outputs[]:
            var semantics = metadata.get(output.key,Semantics(output.key,ROLE_CONTAINER,""))
            semantics.parent_id = output.parent
            result._outputs[].append(RetainedOutput(output.key,output.mount,output.rect,output.clip,output.hidden,output.payload,output.paragraph,semantics,fonts.get(output.key,Float32(16))))
        return result^

    def measurements(self) -> UInt64:
        return self._engine.measurements

    def mutations(self) -> UInt64:
        return self._engine.mutations

    def measurement_nanoseconds(self) -> UInt64:
        """Cumulative provider time; excludes cache lookups and arrangement."""
        return self._engine.measurement_nanoseconds
