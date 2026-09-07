"""Shared text corpus contract for portable shaping and editing."""

from moxi import (
    TextInputState,
    canonical_text_corpus,
    clamp_text_boundary,
    default_label_style,
    next_text_boundary,
    shape_text,
    test_check,
)


def grapheme_count(text: String) -> Int:
    var count = 0
    var cursor = 0
    while cursor < text.count_codepoints():
        count += 1
        var next = next_text_boundary(text, cursor)
        if next <= cursor:
            next = cursor + 1
        cursor = next
    return count


def main():
    var style = default_label_style()
    var corpus = canonical_text_corpus()
    test_check(len(corpus) == 5)
    for index in range(len(corpus)):
        var fixture = corpus[index]
        var shaped = shape_text(
            fixture.text,
            style,
            fixture.max_width,
            fixture.direction,
        )
        test_check(shaped.glyph_count() > 0)
        test_check(shaped.bidi_applied == fixture.expect_bidi)
        test_check(shaped.used_fallback_font == fixture.expect_fallback)
        if fixture.expect_wrapping:
            test_check(shaped.measurement.line_count > 1)

        var boundaries = grapheme_count(fixture.text)
        test_check(boundaries > 0)
        var cursor = 0
        while cursor < fixture.text.count_codepoints():
            var next = next_text_boundary(fixture.text, cursor)
            test_check(next > cursor)
            test_check(clamp_text_boundary(fixture.text, next) == next)
            cursor = next

        var editing = TextInputState(fixture.text)
        var original_length = fixture.text.count_codepoints()
        test_check(editing.select_all())
        test_check(editing.replace_text_range("X", 0, original_length))
        test_check(editing.text == "X")
        editing.set_text(fixture.text)
        editing.set_composition("候", 0, 1)
        test_check(editing.has_composition())
        test_check(editing.replace_text_range("Y", 0, 1))
        test_check(not editing.has_composition())
        test_check(editing.cursor == 1)
        test_check(editing.replace_text_range("Z", -10, 999))
        test_check(editing.text == "Z")

    print("Moxi text-conformance corpus passed")
