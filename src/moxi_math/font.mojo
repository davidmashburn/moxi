"""Pinned OpenType MATH resource. Explicit open/close bracket native snapshots."""
from std.ffi import external_call
from std.collections import List

struct MathConstant(ImplicitlyCopyable):
    var value: Int32
    comptime SCRIPT_SCALE = Self(0)
    comptime AXIS = Self(5)
    comptime SUB_SHIFT = Self(8)
    comptime SUPER_SHIFT = Self(11)
    comptime SCRIPT_GAP = Self(15)
    comptime UPPER_GAP = Self(18)
    comptime LOWER_GAP = Self(20)
    comptime NUM_GAP = Self(37)
    comptime FRACTION_RULE = Self(38)
    comptime DEN_GAP = Self(40)
    comptime RADICAL_GAP = Self(50)
    comptime RADICAL_RULE = Self(51)
    def __init__(out self, value: Int32):
        self.value = value

struct MathGlyph(ImplicitlyCopyable):
    var id: Int
    var x: Float32
    var y: Float32
    var size: Float32
    var advance: Float32
    var cluster: Int
    def __init__(out self, id: Int, x: Float32, y: Float32, size: Float32, advance: Float32 = 0, cluster: Int = 0):
        self.id = id
        self.x = x
        self.y = y
        self.size = size
        self.advance = advance
        self.cluster = cluster

struct MathFont(ImplicitlyCopyable):
    def __init__(out self):
        pass
    def constant(self, c: MathConstant, size: Float32) -> Float32:
        return external_call["moxi_math_constant", Float32](c.value, size)
    def glyph(self, cp: Int) -> Int:
        return Int(external_call["moxi_math_glyph", Int32](Int32(cp)))
    def metric(self, glyph: Int, size: Float32, field: Int) -> Float32:
        return external_call["moxi_math_metric", Float32](Int32(glyph), size, Int32(field))
    def shape(self, text: String, size: Float32) -> List[MathGlyph]:
        var source = text
        var ptr = source.as_c_string_span()
        var count = Int(external_call["moxi_math_shape", Int32](ptr.ptr()))
        var result = List[MathGlyph]()
        var x: Float32 = 0
        for i in range(count):
            var id = Int(external_call["moxi_math_shaped", Float32](Int32(i), Int32(0), size))
            var advance = external_call["moxi_math_shaped", Float32](Int32(i), Int32(1), size)
            var dx = external_call["moxi_math_shaped", Float32](Int32(i), Int32(2), size)
            var dy = external_call["moxi_math_shaped", Float32](Int32(i), Int32(3), size)
            var cluster = Int(external_call["moxi_math_shaped", Float32](Int32(i), Int32(4), size))
            result.append(MathGlyph(id, x + dx, dy, size, advance, cluster))
            x += advance
        return result^
    def stretch(self, cp: Int, size: Float32, height: Float32) -> List[MathGlyph]:
        var count = Int(external_call["moxi_math_stretch", Int32](Int32(self.glyph(cp)), size, height))
        var result = List[MathGlyph]()
        for i in range(count):
            var id = Int(external_call["moxi_math_piece", Float32](Int32(i), Int32(0)))
            var top = external_call["moxi_math_piece", Float32](Int32(i), Int32(1))
            result.append(MathGlyph(id, 0, top + self.metric(id, size, 1), size, self.metric(id, size, 0)))
        return result^

def open_math_font(path: String) raises:
    var source = path
    var ptr = source.as_c_string_span()
    if external_call["moxi_math_font_open", Int32](ptr.ptr()) == 0:
        raise Error("Pinned math font missing, already open, or has no MATH table")

def close_math_font():
    external_call["moxi_math_font_close", NoneType]()
