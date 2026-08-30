"""HarfBuzz shaping smoke demo; link it with scripts/harfbuzz_check.sh."""

from moxi import HarfBuzzTextShaper, default_label_style


def main() raises:
    var shaper = HarfBuzzTextShaper()
    if not shaper.available():
        print("Moxi HarfBuzz unavailable")
        return
    var result = shaper.shape("office • مرحبا • नमस्ते", default_label_style(), 0.0, 0)
    print("Moxi HarfBuzz glyphs: ", result.glyph_count())
    print("Moxi HarfBuzz width: ", result.measurement.size.width)
    print("Moxi HarfBuzz approximate: ", result.approximate)
