"""CoreText/portable structural parity on the shared text corpus."""

from moxi import (
    MacOSTextShaper,
    canonical_text_corpus,
    default_label_style,
    shape_text,
    test_check,
)


def main() raises:
    var native = MacOSTextShaper()
    if not native.available():
        print("Moxi native text parity skipped: CoreText unavailable")
        return
    var style = default_label_style()
    var corpus = canonical_text_corpus()
    for index in range(len(corpus)):
        var fixture = corpus[index]
        var portable = shape_text(
            fixture.text,
            style,
            fixture.max_width,
            fixture.direction,
        )
        var shaped = native.shape(
            fixture.text,
            style,
            fixture.max_width,
            fixture.direction,
        )
        # Width and glyph ids are engine-specific. These are the shared
        # hand-off invariants: non-empty text has glyphs, valid source
        # clusters, one measured line, and a non-approximate native result.
        test_check(portable.glyph_count() > 0)
        test_check(shaped.glyph_count() > 0)
        test_check(shaped.run_count() > 0)
        test_check(not shaped.approximate)
        test_check(shaped.measurement.line_count == 1)
        test_check(shaped.measurement.size.width > 0.0)
        test_check(shaped.measurement.size.height > 0.0)
        for glyph_index in range(shaped.glyph_count()):
            var glyph = shaped.glyph(glyph_index)
            test_check(glyph.cluster >= 0)
            test_check(glyph.cluster < fixture.text.count_codepoints())
        if fixture.direction == 1 or fixture.direction == 2:
            test_check(shaped.direction == fixture.direction)

    print("Moxi native text parity passed")
