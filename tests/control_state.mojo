"""Behavior tests for slider, toggle, radio, and multiline state helpers."""

from moxi import (
    KEY_ENTER,
    KEY_RIGHT,
    MultilineTextState,
    Point,
    RadioGroupState,
    Rect,
    SliderState,
    ToggleState,
    test_check,
)


def main():
    var slider = SliderState(0.5, 0.0, 1.0, 0.25)
    test_check(slider.handle_key(KEY_RIGHT))
    test_check(slider.value == 0.75)
    test_check(slider.set_from_position(Point(0.0, 0.0), Rect(0.0, 0.0, 100.0, 20.0)))
    test_check(slider.value == 0.0)

    var toggle = ToggleState()
    test_check(toggle.toggle())
    test_check(toggle.checked)
    test_check(not toggle.set_checked(True))

    var radio = RadioGroupState(4)
    test_check(radio.select(2))
    test_check(radio.is_selected(2))
    test_check(not radio.is_selected(3))

    var multiline = MultilineTextState("one")
    test_check(multiline.handle_key(KEY_ENTER, 0))
    test_check(multiline.insert_text("two"))
    test_check(multiline.text() == "one\ntwo")

    print("Moxi control-state test passed")
