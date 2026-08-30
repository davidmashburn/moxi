"""Deterministic, backend-neutral text measurement for intrinsic sizing."""

from .geometry import Size
from .style import Style


struct TextMeasurement(ImplicitlyCopyable):
    """A deterministic text extent plus the number of laid-out lines."""

    var size: Size
    var line_count: Int

    def __init__(out self, size: Size, line_count: Int):
        self.size = size
        self.line_count = line_count


def measure_text_wrapped(
    text: String,
    style: Style,
    max_width: Float32,
) -> TextMeasurement:
    """Estimate greedy codepoint-wrapped text without a native backend.

    This is intentionally a stable layout estimate, not glyph-accurate font
    shaping. Lines wrap at the estimated codepoint advance; whitespace is
    retained in the estimate so headless layout and the native text rectangle
    agree on the deterministic line-count contract.
    """
    var font_size = style.font_size
    if font_size <= 0.0:
        font_size = 16.0
    var advance = font_size * 0.56
    var line_height = font_size * 1.25
    if line_height < 16.0:
        line_height = 16.0

    var width_limit = max_width
    if width_limit < 0.0:
        width_limit = 0.0
    var line_width: Float32 = 0.0
    var max_line_width: Float32 = 0.0
    var line_count = 1
    var index = 0
    var length = text.count_codepoints()
    while index < length:
        var glyph = String(text[codepoint=index:index + 1])
        if glyph == "\n":
            if line_width > max_line_width:
                max_line_width = line_width
            line_count += 1
            line_width = 0.0
            index += 1
            continue
        if width_limit > 0.0 and line_width > 0.0 and line_width + advance > width_limit:
            if line_width > max_line_width:
                max_line_width = line_width
            line_count += 1
            line_width = 0.0
        line_width += advance
        index += 1

    if line_width > max_line_width:
        max_line_width = line_width
    if width_limit > 0.0 and max_line_width > width_limit:
        max_line_width = width_limit
    return TextMeasurement(
        Size(max_line_width, line_height * Float32(line_count)),
        line_count,
    )


def measure_text(text: String, style: Style) -> Size:
    """Estimate a single-line text extent without requiring a native backend.

    This is intentionally a stable layout estimate, not glyph-accurate font
    shaping. A platform renderer can replace it with real metrics later while
    keeping the intrinsic-sizing contract intact.
    """
    return measure_text_wrapped(text, style, 0.0).size
