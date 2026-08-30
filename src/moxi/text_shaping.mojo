"""Portable shaped-run data and a deterministic fallback shaper.

The fallback operates on Unicode scalar clusters and deliberately reports that
it is approximate. Native adapters can implement the same `TextShaper` seam
with CoreText, HarfBuzz, Android text, or browser shaping without changing the
layout/data contract.
"""

from std.collections import List

from .geometry import Size
from .style import Style
from .text_boundary import (
    codepoint_at,
    is_extend,
    is_regional_indicator,
)
from .measure import TextMeasurement


comptime SHAPER_PORTABLE_ESTIMATE = 1
comptime SHAPER_NATIVE = 2


def _is_rtl(codepoint: Int) -> Bool:
    return (
        (codepoint >= 0x0590 and codepoint <= 0x08FF)
        or (codepoint >= 0xFB1D and codepoint <= 0xFDFF)
        or (codepoint >= 0xFE70 and codepoint <= 0xFEFF)
    )


def _is_emoji(codepoint: Int) -> Bool:
    return (
        (codepoint >= 0x1F000 and codepoint <= 0x1FAFF)
        or is_regional_indicator(codepoint)
    )


def fallback_font_id(codepoint: Int) -> Int:
    """Return a stable fallback-face class for a Unicode scalar."""
    if _is_emoji(codepoint):
        return 2
    if codepoint >= 0x2E80 and codepoint <= 0x9FFF:
        return 1
    if _is_rtl(codepoint):
        return 3
    return 0


struct ShapedGlyph(ImplicitlyCopyable):
    """One portable glyph placeholder with cluster and fallback metadata."""

    var codepoint: Int
    var cluster: Int
    var font_id: Int
    var advance: Float32
    var x: Float32
    var y: Float32
    var line: Int

    def __init__(
        out self,
        codepoint: Int,
        cluster: Int,
        font_id: Int,
        advance: Float32,
        x: Float32,
        y: Float32,
        line: Int,
    ):
        self.codepoint = codepoint
        self.cluster = cluster
        self.font_id = font_id
        self.advance = advance
        self.x = x
        self.y = y
        self.line = line


struct ShapedText:
    """Result of shaping with enough metadata for renderers and hit testing."""

    var glyphs: List[ShapedGlyph]
    var measurement: TextMeasurement
    var direction: Int
    var bidi_applied: Bool
    var approximate: Bool
    var used_fallback_font: Bool

    def __init__(out self):
        self.glyphs = List[ShapedGlyph]()
        self.measurement = TextMeasurement(Size(0.0, 0.0), 0)
        self.direction = 1
        self.bidi_applied = False
        self.approximate = True
        self.used_fallback_font = False

    def glyph_count(self) -> Int:
        return len(self.glyphs)

    def glyph(self, index: Int) -> ShapedGlyph:
        return self.glyphs[index]


trait TextShaper:
    """Backend seam for native or portable text shaping implementations."""

    def shape(
        self,
        text: String,
        style: Style,
        max_width: Float32,
        direction: Int,
    ) -> ShapedText:
        ...


struct PortableTextShaper(TextShaper):
    """Deterministic cluster-aware shaper used by headless and unsupported hosts."""

    def __init__(out self):
        pass

    def shape(
        self,
        text: String,
        style: Style,
        max_width: Float32,
        direction: Int,
    ) -> ShapedText:
        var result = ShapedText()
        result.direction = direction
        var font_size = style.font_size
        if font_size <= 0.0:
            font_size = 16.0
        var base_advance = font_size * 0.56
        var line_height = font_size * 1.25
        if line_height < 16.0:
            line_height = 16.0
        var width_limit = max_width if max_width > 0.0 else 0.0
        var line_width: Float32 = 0.0
        var max_line_width: Float32 = 0.0
        var line = 0
        var line_count = 1
        var index = 0
        while index < text.count_codepoints():
            var codepoint = codepoint_at(text, index)
            var advance = base_advance
            if codepoint == 0x0A:
                if line_width > max_line_width:
                    max_line_width = line_width
                line += 1
                line_count += 1
                line_width = 0.0
                index += 1
                continue
            if codepoint == 0x09:
                advance *= 4.0
            elif is_extend(codepoint):
                advance = 0.0
            elif _is_emoji(codepoint):
                advance *= 1.15
            elif codepoint >= 0x2E80 and codepoint <= 0x9FFF:
                advance *= 1.75
            if width_limit > 0.0 and line_width > 0.0 and line_width + advance > width_limit:
                if line_width > max_line_width:
                    max_line_width = line_width
                line += 1
                line_count += 1
                line_width = 0.0
            var font_id = fallback_font_id(codepoint)
            if font_id != 0:
                result.used_fallback_font = True
            result.glyphs.append(
                ShapedGlyph(
                    codepoint,
                    index,
                    font_id,
                    advance,
                    line_width,
                    line_height * Float32(line),
                    line,
                )
            )
            line_width += advance
            index += 1

        if line_width > max_line_width:
            max_line_width = line_width
        if width_limit > 0.0 and max_line_width > width_limit:
            max_line_width = width_limit
        result.measurement = TextMeasurement(
            Size(max_line_width, line_height * Float32(line_count)),
            line_count,
        )

        # The fallback has no glyph shaping engine, but it can provide a
        # stable visual order for the explicit RTL request. Keep clusters and
        # positions intact so editors can still map back to source offsets.
        if direction == 2:
            var visual = List[ShapedGlyph](capacity=len(result.glyphs))
            var index = len(result.glyphs)
            while index > 0:
                index -= 1
                visual.append(result.glyphs[index])
            result.glyphs = visual^
            result.bidi_applied = True
        return result^


def shape_text(
    text: String,
    style: Style,
    max_width: Float32 = 0.0,
    direction: Int = 1,
) -> ShapedText:
    """Shape text through the portable adapter until a native shaper is used."""
    var shaper = PortableTextShaper()
    return shaper.shape(text, style, max_width, direction)
