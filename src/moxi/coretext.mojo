"""CoreText-backed native shaper sharing the portable shaped-run data model."""

from std.ffi import external_call

from .geometry import Size
from .measure import TextMeasurement
from .style import Style
from .text_shaping import ShapedGlyph, ShapedText, TextShaper


struct MacOSTextShaper(TextShaper):
    """Use CoreText's real glyph shaping, bidi, and font fallback on macOS."""

    def __init__(out self):
        pass

    def available(self) -> Bool:
        return external_call["moxi_coretext_available", Int32]() != 0

    def shape(
        self,
        text: String,
        style: Style,
        max_width: Float32,
        direction: Int,
    ) -> ShapedText:
        var result = ShapedText()
        result.direction = direction
        var source = text
        var c_text = source.as_c_string_slice()
        var count = Int(
            external_call["moxi_coretext_shape", Int32](
                c_text.ptr(),
                style.font_size,
                1 if direction == 2 else 0,
            )
        )
        var width = external_call["moxi_coretext_width", Float32]()
        if max_width > 0.0 and width > max_width:
            width = max_width
        var height = external_call["moxi_coretext_height", Float32]()
        if height <= 0.0:
            height = style.font_size * 1.25
        result.measurement = TextMeasurement(Size(width, height), 1)
        result.approximate = False
        result.bidi_applied = direction == 2
        for index in range(count):
            result.glyphs.append(
                ShapedGlyph(
                    Int(external_call["moxi_coretext_glyph_codepoint_at", Int32](Int32(index))),
                    Int(external_call["moxi_coretext_glyph_id_at", Int32](Int32(index))),
                    Int(external_call["moxi_coretext_glyph_cluster_at", Int32](Int32(index))),
                    0,
                    external_call["moxi_coretext_glyph_advance_at", Float32](Int32(index)),
                    external_call["moxi_coretext_glyph_position_at", Float32](Int32(index)),
                    0.0,
                    0,
                )
            )
        return result^
