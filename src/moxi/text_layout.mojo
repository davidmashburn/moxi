"""Backend-neutral text layout requests and honest fallback reporting."""

from std.collections import List

from .measure import TextMeasurement, measure_text_wrapped
from .style import Style, default_label_style
from .text_shaping import SHAPER_PORTABLE_ESTIMATE, shape_text


comptime TEXT_LAYOUT_ESTIMATE = 1
comptime TEXT_LAYOUT_NATIVE = 2
comptime TEXT_LAYOUT_PORTABLE = 3
comptime TEXT_DIRECTION_LTR = 1
comptime TEXT_DIRECTION_RTL = 2


struct TextSpan(ImplicitlyCopyable):
    """One styled run in a small rich-text document."""

    var text: String
    var style: Style

    def __init__(out self, text: String, style: Style):
        self.text = text
        self.style = style


struct RichText:
    """A backend-neutral sequence of styled spans.

    The core keeps the document model separate from painting. The current
    headless measurement path flattens runs; a native renderer may consume
    the run boundaries when a rich-text bridge is added.
    """

    var spans: List[TextSpan]

    def __init__(out self):
        self.spans = List[TextSpan]()

    def append(mut self, span: TextSpan):
        self.spans.append(span)

    def count(self) -> Int:
        return len(self.spans)

    def flattened(self) -> String:
        var text = String("")
        for index in range(len(self.spans)):
            text += self.spans[index].text
        return text


struct TextLayoutRequest(ImplicitlyCopyable):
    """A portable request that can be handed to estimate or native layout."""

    var text: String
    var style: Style
    var max_width: Float32
    var backend: Int
    var direction: Int
    var rich_text: Bool

    def __init__(
        out self,
        text: String,
        style: Style,
        max_width: Float32 = 0.0,
    ):
        self.text = text
        self.style = style
        self.max_width = max_width
        self.backend = TEXT_LAYOUT_ESTIMATE
        self.direction = TEXT_DIRECTION_LTR
        self.rich_text = False

    def set_backend(mut self, backend: Int):
        self.backend = backend

    def set_direction(mut self, direction: Int):
        self.direction = direction

    def set_rich_text(mut self, enabled: Bool = True):
        self.rich_text = enabled


struct TextLayoutResult(ImplicitlyCopyable):
    """Measurement plus flags that prevent callers mistaking a fallback for shaping."""

    var measurement: TextMeasurement
    var backend_used: Int
    var shaped: Bool
    var bidi_applied: Bool
    var rich_text_applied: Bool
    var fallback_used: Bool

    def __init__(
        out self,
        measurement: TextMeasurement,
        backend_used: Int,
        shaped: Bool,
        bidi_applied: Bool,
        rich_text_applied: Bool,
        fallback_used: Bool,
    ):
        self.measurement = measurement
        self.backend_used = backend_used
        self.shaped = shaped
        self.bidi_applied = bidi_applied
        self.rich_text_applied = rich_text_applied
        self.fallback_used = fallback_used


def layout_text(request: TextLayoutRequest) -> TextLayoutResult:
    """Measure with the deterministic core and report unsupported upgrades."""
    if request.backend == TEXT_LAYOUT_PORTABLE:
        var shaped = shape_text(
            request.text,
            request.style,
            request.max_width,
            request.direction,
        )
        return TextLayoutResult(
            shaped.measurement,
            TEXT_LAYOUT_PORTABLE,
            False,
            shaped.bidi_applied,
            False,
            shaped.approximate or shaped.used_fallback_font,
        )
    var measurement = measure_text_wrapped(
        request.text,
        request.style,
        request.max_width,
    )
    # Native shaping/bidi is intentionally performed by a platform renderer,
    # not faked in the portable estimator. The result makes that distinction
    # inspectable to tests, adapters, and accessibility tooling.
    return TextLayoutResult(
        measurement,
        TEXT_LAYOUT_ESTIMATE,
        False,
        False,
        False,
        request.backend != TEXT_LAYOUT_ESTIMATE
            or request.direction == TEXT_DIRECTION_RTL
            or request.rich_text,
    )


def layout_rich_text(
    document: RichText,
    max_width: Float32,
) -> TextLayoutResult:
    """Flatten a rich document for deterministic sizing and mark the fallback."""
    var text = document.flattened()
    var style = default_label_style()
    if document.count() > 0:
        style = document.spans[0].style
    var request = TextLayoutRequest(text, style, max_width)
    request.set_rich_text()
    return layout_text(request)
