"""CoreText shaping smoke demo using the shared shaped-run contract."""

from moxi import MacOSTextShaper, default_label_style


def main() raises:
    var shaper = MacOSTextShaper()
    if not shaper.available():
        print("Moxi CoreText unavailable")
        return
    var result = shaper.shape("Moxi • שלום • 🙂", default_label_style(), 0.0, 1)
    print("Moxi CoreText glyphs: ", result.glyph_count())
    print("Moxi CoreText width: ", result.measurement.size.width)
