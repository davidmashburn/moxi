"""Contract tests for practical grapheme-safe editor movement."""

from moxi import (
    TextInputState,
    clamp_text_boundary,
    next_text_boundary,
    previous_text_boundary,
)
from moxi.testing import test_check


def main():
    var text = "A e\u0301 🙂"
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

    print("Moxi text-boundary test passed")
