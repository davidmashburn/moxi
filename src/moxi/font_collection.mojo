"""Host-selected fonts and retained HarfBuzz paragraph snapshots.

Link native/harfbuzz_collection.cpp with HarfBuzz, FreeType and Fontconfig.
Collections are shared by copies and serialized by the calling host. Paragraphs
retain their original faces and geometry across collection changes/eviction.
"""
from std.ffi import external_call
from std.memory import ArcPointer
from std.collections import List
from .geometry import Point, Rect, Size
from .measure import TextMeasurement
from .style import Style
from .text_shaping import ShapedText, ShapedGlyph, ShapedRun, TEXT_DIRECTION_RTL


struct MissingFontPolicy(ImplicitlyCopyable):
    """No implicit system fallback: use primary .notdef, or reject the request."""
    var value: Int32
    comptime NOTDEF = Self(0)
    comptime REJECT = Self(1)

    def __init__(out self, value: Int32):
        self.value = value


struct FontTextStatus(ImplicitlyCopyable):
    var value: Int32
    comptime OK = Self(0)
    comptime INVALID = Self(1)
    comptime NO_FONT = Self(2)
    comptime MISSING = Self(3)
    comptime UNSUPPORTED = Self(4)

    def __init__(out self, value: Int32):
        self.value = value


# C ABI field identities, kept out of callers and domain branching.
comptime _GLYPH_CODEPOINT = 0
comptime _GLYPH_ID = 1
comptime _GLYPH_CLUSTER = 2
comptime _GLYPH_END = 3
comptime _GLYPH_FONT = 4
comptime _GLYPH_LINE = 5
comptime _GLYPH_DIRECTION = 6
comptime _GLYPH_SCRIPT = 7
comptime _GLYPH_ADVANCE = 0
comptime _GLYPH_X = 1
comptime _GLYPH_Y = 2


struct _FontCollectionStorage:
    var handle: UInt

    def __init__(out self):
        self.handle = external_call["moxi_font_collection_create", UInt]()

    def __deinit__(deinit self):
        external_call["moxi_font_collection_release", NoneType](self.handle)


struct _HBParagraphStorage:
    var handle: UInt

    def __init__(out self, handle: UInt):
        self.handle = handle

    def __deinit__(deinit self):
        external_call["moxi_hb_paragraph_release", NoneType](self.handle)


struct FontCollection(ImplicitlyCopyable):
    """An ordered collection. Mutations invalidate its one-entry layout cache.

    Family names resolve once through Fontconfig and may be substituted. Use
    explicit file paths and face indices for reproducible host selection.
    Only scalable Unicode faces are accepted; failed changes are atomic.
    """
    var _storage: ArcPointer[_FontCollectionStorage]

    def __init__(out self):
        self._storage = ArcPointer(_FontCollectionStorage())

    def add_file(self, path: String, face_index: Int = 0) raises:
        if "\x00" in path or face_index < 0 or face_index > 2147483647:
            raise Error("Invalid font path or face index")
        var source = path
        var c_source = source.as_c_string_span()
        if external_call["moxi_font_collection_add_file", Int32](self._storage[].handle, c_source.ptr(), Int32(face_index)) == 0:
            raise Error("Cannot load scalable Unicode font face")

    def add_family(self, family: String) raises:
        if "\x00" in family:
            raise Error("Invalid font family")
        var source = family
        var c_source = source.as_c_string_span()
        if external_call["moxi_font_collection_add_family", Int32](self._storage[].handle, c_source.ptr()) == 0:
            raise Error("Cannot resolve scalable Unicode font family")

    def set_missing_policy(self, policy: MissingFontPolicy) raises:
        if external_call["moxi_font_collection_policy", Int32](self._storage[].handle, policy.value) == 0:
            raise Error("Invalid missing-font policy")

    def move(self, source: Int, destination: Int) raises:
        if source < 0 or destination < 0 or source >= self.count() or destination >= self.count():
            raise Error("Font collection index out of range")
        if external_call["moxi_font_collection_move", Int32](self._storage[].handle, Int32(source), Int32(destination)) == 0:
            raise Error("Cannot reorder font collection")

    def count(self) -> Int:
        return Int(external_call["moxi_font_collection_count", Int32](self._storage[].handle))

    def revision(self) -> UInt64:
        return external_call["moxi_font_collection_revision", UInt64](self._storage[].handle)

    def builds(self) -> UInt64:
        return external_call["moxi_font_collection_builds", UInt64](self._storage[].handle)

    def cache_hits(self) -> UInt64:
        return external_call["moxi_font_collection_hits", UInt64](self._storage[].handle)

    def status(self) -> FontTextStatus:
        return FontTextStatus(external_call["moxi_font_collection_status", Int32](self._storage[].handle))

    def paragraph(self, text: String, style: Style, width: Float32 = 0, direction: Int = 0) raises -> HarfBuzzParagraph:
        if "\x00" in text or direction < 0 or direction > 2:
            raise Error("Invalid paragraph text or direction")
        var source = text
        var c_source = source.as_c_string_span()
        var handle = external_call["moxi_hb_paragraph_create", UInt](
            self._storage[].handle, c_source.ptr(), style.font_size, width, Int32(direction))
        if handle == 0:
            raise Error("HarfBuzz paragraph failed; inspect collection.status()")
        return HarfBuzzParagraph(handle)


struct HarfBuzzParagraph(ImplicitlyCopyable):
    """Immutable geometry with practical-cluster caret/hit testing.

    Greedy grapheme wrapping reshapes each line. An indivisible cluster wider
    than the constraint overflows honestly. Bidi uses coarse script runs, not
    UAX #9; explicit bidi controls and tabs are rejected. No IME/AX claim.
    """
    var _storage: ArcPointer[_HBParagraphStorage]

    def __init__(out self, handle: UInt):
        self._storage = ArcPointer(_HBParagraphStorage(handle))

    def revision(self) -> UInt64:
        return external_call["moxi_hb_paragraph_revision", UInt64](self._storage[].handle)

    def missing_clusters(self) -> Int:
        return Int(external_call["moxi_hb_paragraph_missing", Int32](self._storage[].handle))

    def _int(self, index: Int, field: Int) -> Int:
        return Int(external_call["moxi_hb_glyph_int", Int32](self._storage[].handle, Int32(index), Int32(field)))

    def _float(self, index: Int, field: Int) -> Float32:
        return external_call["moxi_hb_glyph_float", Float32](self._storage[].handle, Int32(index), Int32(field))

    def cluster_end(self, glyph: Int) -> Int:
        return self._int(glyph, _GLYPH_END)

    def caret_offset(self, offset: Int) -> Int:
        return Int(external_call["moxi_hb_caret_offset", Int32](self._storage[].handle, Int32(max(-2147483647, min(2147483647, offset)))))

    def caret(self, offset: Int) -> Point:
        var clamped = Int32(self.caret_offset(offset))
        return Point(external_call["moxi_hb_caret_x", Float32](self._storage[].handle, clamped),
                     external_call["moxi_hb_caret_y", Float32](self._storage[].handle, clamped))

    def hit_test(self, point: Point) -> Int:
        return Int(external_call["moxi_hb_hit_test", Int32](self._storage[].handle, point.x, point.y))

    def selection_rects(self, start: Int, end: Int) -> List[Rect]:
        var a = Int32(self.caret_offset(start))
        var b = Int32(self.caret_offset(end))
        var handle = self._storage[].handle
        var count = Int(external_call["moxi_hb_selection_count", Int32](handle, a, b))
        var result = List[Rect](capacity=count)
        for i in range(count):
            result.append(Rect(
                external_call["moxi_hb_selection_rect", Float32](handle, a, b, Int32(i), Int32(0)),
                external_call["moxi_hb_selection_rect", Float32](handle, a, b, Int32(i), Int32(1)),
                external_call["moxi_hb_selection_rect", Float32](handle, a, b, Int32(i), Int32(2)),
                external_call["moxi_hb_selection_rect", Float32](handle, a, b, Int32(i), Int32(3))))
        return result^

    def write_svg(self, path: String, selection_start: Int = 0, selection_end: Int = 0) raises:
        if "\x00" in path:
            raise Error("Invalid SVG path")
        var source = path
        var c_source = source.as_c_string_span()
        if external_call["moxi_hb_paragraph_svg", Int32](self._storage[].handle, c_source.ptr(), Int32(self.caret_offset(selection_start)), Int32(self.caret_offset(selection_end))) == 0:
            raise Error("Cannot write paragraph SVG")

    def shaped(self) -> ShapedText:
        var result = ShapedText()
        var handle = self._storage[].handle
        var count = Int(external_call["moxi_hb_paragraph_count", Int32](handle))
        result.direction = Int(external_call["moxi_hb_paragraph_direction", Int32](handle))
        result.approximate = False
        result.bidi_applied = result.direction == TEXT_DIRECTION_RTL
        result.measurement = TextMeasurement(Size(
            external_call["moxi_hb_paragraph_width", Float32](handle),
            external_call["moxi_hb_paragraph_height", Float32](handle)),
            Int(external_call["moxi_hb_paragraph_lines", Int32](handle)))
        for i in range(count):
            var font = self._int(i, _GLYPH_FONT)
            var line = self._int(i, _GLYPH_LINE)
            var cluster = self._int(i, _GLYPH_CLUSTER)
            var end = self._int(i, _GLYPH_END)
            var direction = self._int(i, _GLYPH_DIRECTION)
            var script = self._int(i, _GLYPH_SCRIPT)
            result.used_fallback_font = result.used_fallback_font or font != 0
            result.bidi_applied = result.bidi_applied or direction != result.direction
            result.glyphs.append(ShapedGlyph(self._int(i, _GLYPH_CODEPOINT), self._int(i, _GLYPH_ID),
                cluster, font, self._float(i, _GLYPH_ADVANCE), self._float(i, _GLYPH_X), self._float(i, _GLYPH_Y), line))
            if len(result.runs) > 0:
                var previous = result.runs[len(result.runs) - 1]
                if previous.font_id == font and previous.line == line and previous.direction == direction and previous.script == script:
                    result.runs[len(result.runs) - 1].glyph_end = i + 1
                    result.runs[len(result.runs) - 1].cluster_start = min(previous.cluster_start, cluster)
                    result.runs[len(result.runs) - 1].cluster_end = max(previous.cluster_end, end)
                    continue
            result.runs.append(ShapedRun(line, i, i + 1, cluster, end, direction, font, script))
        return result^
