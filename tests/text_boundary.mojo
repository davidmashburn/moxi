"""Contract tests for practical grapheme-safe editor movement."""

from moxi import (
    TextInputState,
    canonical_text_combining_fixture,
    clamp_text_boundary,
    next_text_boundary,
    previous_text_boundary,
)
from moxi.testing import test_check


def main():
    var text = canonical_text_combining_fixture()
    test_check(text.count_codepoints() == 6)
    test_check(next_text_boundary(text, 2) == 4)
    test_check(previous_text_boundary(text, 4) == 2)
    test_check(clamp_text_boundary(text, 3) == 2)

    var input = TextInputState(text)
    input.cursor = 4
    test_check(input.delete_backward())
    test_check(input.text == "A  🙂")
    test_check(input.cursor == 2)
    test_check(input.move_right(False))
    test_check(input.cursor == 3)

    var flags = "🇺🇸🇫🇷🇯"
    test_check(next_text_boundary(flags, 0) == 2)
    test_check(next_text_boundary(flags, 2) == 4)
    test_check(next_text_boundary(flags, 4) == 5)
    test_check(previous_text_boundary(flags, 4) == 2)
    test_check(previous_text_boundary(flags, 5) == 4)
    test_check(clamp_text_boundary(flags, 1) == 0)
    var flag_input = TextInputState(flags)
    flag_input.cursor = 4
    test_check(flag_input.delete_backward())
    test_check(flag_input.text == "🇺🇸🇯")
    test_check(next_text_boundary("🇺🇸́", 0) == 3)
    test_check(previous_text_boundary("🇺🇸́", 3) == 0)
    var conjunct = "हिन्दी"
    test_check(next_text_boundary(conjunct, 0) == 2)
    test_check(next_text_boundary(conjunct, 2) == 6)
    test_check(previous_text_boundary(conjunct, 6) == 2)
    test_check(next_text_boundary("שָ", 0) == 2)
    test_check(next_text_boundary("مَ", 0) == 2)
    print("Moxi text-boundary test passed")
