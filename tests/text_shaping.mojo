"""Portable shaping and fallback-face contract test."""

from moxi import (
    PortableTextShaper,
    SCRIPT_ARABIC_HEBREW,
    SCRIPT_LATIN,
    TEXT_DIRECTION_AUTO,
    TEXT_LAYOUT_PORTABLE,
    TextLayoutRequest,
    default_label_style,
    fallback_font_id,
    script_id,
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
    test_check(shaped.run_count() == 5)
    test_check(shaped.run(0).script == SCRIPT_LATIN)
    test_check(shaped.run(2).glyph_count() == 2)
    test_check(shaped.glyph(0).glyph_id == shaped.glyph(0).codepoint)
    test_check(fallback_font_id(0x1F642) == 2)
    test_check(fallback_font_id(0x4E00) == 1)

    var rtl = shape_text("אבג", style, 0.0, 2)
    test_check(rtl.bidi_applied)
    test_check(rtl.glyph(0).cluster == 2)
    test_check(rtl.run_count() == 1)
    test_check(rtl.run(0).direction == 2)
    test_check(rtl.run(0).script == SCRIPT_ARABIC_HEBREW)

    var auto_rtl = shape_text("...אבג", style, 0.0, TEXT_DIRECTION_AUTO)
    test_check(auto_rtl.direction == 2)
    test_check(script_id(0x05D0) == SCRIPT_ARABIC_HEBREW)
    test_check(auto_rtl.bidi_applied)

    var request = TextLayoutRequest("hello", style)
    request.set_backend(TEXT_LAYOUT_PORTABLE)
    var result = layout_text(request)
    test_check(result.backend_used == TEXT_LAYOUT_PORTABLE)
    test_check(result.fallback_used)
    var shaper = PortableTextShaper()
    test_check(shaper.shape("ok", style, 0.0, 1).glyph_count() == 2)
    print("Moxi text-shaping test passed")
