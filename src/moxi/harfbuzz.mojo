"""Optional HarfBuzz adapter backed by an owned host-selected collection."""
from .font_collection import FontCollection
from .style import Style
from .text_shaping import ShapedText, TextShaper


struct HarfBuzzTextShaper(TextShaper):
    """OpenType shaping with ordered cluster fallback and bounded paragraphs.

    The default retains the historical Arial Unicode MS Fontconfig request.
    Pass an explicit FontCollection for reproducible fallback policy. Use
    fonts.paragraph() for checked errors, selection geometry and snapshots.
    The non-throwing TextShaper seam returns an empty approximate result on
    failure; fonts.status() exposes the native failure reason.
    """
    var fonts: FontCollection

    def __init__(out self):
        self.fonts = FontCollection()
        try:
            self.fonts.add_family("Arial Unicode MS")
        except:
            pass

    def __init__(out self, fonts: FontCollection):
        self.fonts = fonts

    def available(self) -> Bool:
        return self.fonts.count() > 0

    def shape(self, text: String, style: Style, max_width: Float32, direction: Int) -> ShapedText:
        try:
            var paragraph = self.fonts.paragraph(text, style, max_width, direction)
            return paragraph.shaped()
        except:
            return ShapedText()
