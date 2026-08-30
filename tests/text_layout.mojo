"""Text layout request and fallback-reporting contract test."""

from moxi import test_check
from moxi import (
    Color,
    RichText,
    Style,
    TEXT_DIRECTION_RTL,
    TEXT_LAYOUT_ESTIMATE,
    TEXT_LAYOUT_NATIVE,
    TextLayoutRequest,
    TextSpan,
    layout_rich_text,
    layout_text,
)


def main():
    var style = Style(
        Color(0.0, 0.0, 0.0, 0.0),
        Color(1.0, 1.0, 1.0, 1.0),
        0.0,
        16.0,
    )
    var request = TextLayoutRequest("hello world", style, 48.0)
    var estimate = layout_text(request)
    test_check(estimate.backend_used == TEXT_LAYOUT_ESTIMATE)
    test_check(not estimate.shaped)
    test_check(not estimate.fallback_used)
    test_check(estimate.measurement.line_count > 1)

    request.set_backend(TEXT_LAYOUT_NATIVE)
    request.set_direction(TEXT_DIRECTION_RTL)
    var fallback = layout_text(request)
    test_check(fallback.backend_used == TEXT_LAYOUT_ESTIMATE)
    test_check(fallback.fallback_used)
    test_check(not fallback.bidi_applied)

    var rich = RichText()
    rich.append(TextSpan("Hello ", style))
    rich.append(TextSpan("Moxi", style))
    test_check(rich.flattened() == "Hello Moxi")
    test_check(layout_rich_text(rich, 200.0).fallback_used)
    print("Moxi text-layout test passed")
