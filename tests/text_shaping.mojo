"""Portable shaping and fallback-face contract test."""

from moxi import (
    PortableTextShaper,
    TEXT_LAYOUT_PORTABLE,
    TextLayoutRequest,
    default_label_style,
    fallback_font_id,
    layout_text,
    shape_text,
    test_check,
)


def main():
    var style = default_label_style()
    var shaped = shape_text("A e\u0301 🙂", style)
    test_check(shaped.glyph_count() == 6)
    test_check(shaped.measurement.line_count == 1)
    test_check(shaped.used_fallback_font)
    test_check(fallback_font_id(0x1F642) == 2)
    test_check(fallback_font_id(0x4E00) == 1)

    var rtl = shape_text("אבג", style, 0.0, 2)
    test_check(rtl.bidi_applied)
    test_check(rtl.glyph(0).cluster == 2)

    var request = TextLayoutRequest("hello", style)
    request.set_backend(TEXT_LAYOUT_PORTABLE)
    var result = layout_text(request)
    test_check(result.backend_used == TEXT_LAYOUT_PORTABLE)
    test_check(result.fallback_used)
    var shaper = PortableTextShaper()
    test_check(shaper.shape("ok", style, 0.0, 1).glyph_count() == 2)
    print("Moxi text-shaping test passed")
