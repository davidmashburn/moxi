"""Optional HarfBuzz-backed shaping adapter.

The Mojo package remains dependency-free by default. Link
``native/harfbuzz_text.o`` plus HarfBuzz, FreeType, and Fontconfig when a
portable OpenType shaping engine is available on the host.
"""

from std.ffi import external_call

from .geometry import Size
from .measure import TextMeasurement
from .style import Style
from .text_shaping import (
    SCRIPT_COMMON,
    ShapedGlyph,
    ShapedRun,
    ShapedText,
    TEXT_DIRECTION_RTL,
    TextShaper,
)


struct HarfBuzzTextShaper(TextShaper):
    """Shape through HarfBuzz with a host-selected Unicode system font.

    The adapter provides real OpenType substitution/positioning and UTF-8
    source clusters. The host font resolver remains intentionally small; a
    production app can replace the native resolver when it needs a custom
    fallback chain or font collection.
    """

    def __init__(out self):
        pass

    def available(self) -> Bool:
        return external_call["moxi_harfbuzz_available", Int32]() != 0

    def shape(
        self,
        text: String,
        style: Style,
        max_width: Float32,
        direction: Int,
    ) -> ShapedText:
        var result = ShapedText()
        var source = text
        var c_text = source.as_c_string_slice()
        var count = Int(
            external_call["moxi_harfbuzz_shape", Int32](
                c_text.ptr(),
                style.font_size,
                direction,
            )
        )
        result.direction = Int(external_call["moxi_harfbuzz_direction", Int32]())
        result.approximate = False
        result.bidi_applied = direction == TEXT_DIRECTION_RTL or result.direction == TEXT_DIRECTION_RTL
        var width = external_call["moxi_harfbuzz_width", Float32]()
        if max_width > 0.0 and width > max_width:
            width = max_width
        var height = external_call["moxi_harfbuzz_height", Float32]()
        if height <= 0.0:
            height = style.font_size * 1.25
        result.measurement = TextMeasurement(Size(width, height), 1)
        for index in range(count):
            result.glyphs.append(
                ShapedGlyph(
                    Int(external_call["moxi_harfbuzz_glyph_codepoint_at", Int32](Int32(index))),
                    Int(external_call["moxi_harfbuzz_glyph_id_at", Int32](Int32(index))),
                    Int(external_call["moxi_harfbuzz_glyph_cluster_at", Int32](Int32(index))),
                    0,
                    external_call["moxi_harfbuzz_glyph_advance_at", Float32](Int32(index)),
                    external_call["moxi_harfbuzz_glyph_x_at", Float32](Int32(index)),
                    external_call["moxi_harfbuzz_glyph_y_at", Float32](Int32(index)),
                    0,
                )
            )
        if count > 0:
            result.runs.append(
                ShapedRun(
                    0,
                    0,
                    count,
                    0,
                    text.count_codepoints(),
                    result.direction,
                    0,
                    SCRIPT_COMMON,
                )
            )
        return result^
