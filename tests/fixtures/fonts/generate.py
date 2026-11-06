"""Generate original geometric test fonts; requires fonttools only to regenerate.

These are synthetic coverage/advance fixtures, not typography samples. No font
outlines or data are copied from system fonts. Run from any working directory.
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString

DEST = Path(__file__).parent

def build(name, points, advance):
    builder = FontBuilder(1000, isTTF=True)
    cmap = {cp: f"u{cp:06X}" for cp in sorted(points)}
    order = [".notdef", *cmap.values(), "fi"]
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap(cmap)
    glyphs, metrics = {}, {}
    for index, glyph in enumerate(order):
        pen = TTGlyphPen(None)
        if glyph != cmap.get(32):
            pen.moveTo((70, 0)); pen.lineTo((advance - 70, 0))
            pen.lineTo((advance - 70, 400 + (index % 4) * 60)); pen.lineTo((70, 700))
            pen.closePath()
        glyphs[glyph] = pen.glyph()
        metrics[glyph] = (advance if glyph != "fi" else advance * 3 // 2, 0)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=800, descent=-200)
    builder.setupNameTable({"familyName": name, "styleName": "Regular", "uniqueFontIdentifier": name,
                           "fullName": name, "psName": name})
    builder.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
    builder.setupPost(); builder.setupMaxp()
    addOpenTypeFeaturesFromString(builder.font, "feature liga { sub u000066 u000069 by fi; } liga;")
    builder.font.recalcTimestamp = False
    builder.font["head"].created = builder.font["head"].modified = 3800000000
    builder.save(DEST / f"{name}.ttf")

ascii_points = set(range(32, 127))
extra = set(range(0x300, 0x370)) | set(range(0x370, 0x530)) | set(range(0x590, 0x700))
extra |= set(range(0x900, 0x980)) | {ord(c) for c in "世界中文日本語候🇺🇸👩💻👍🏽🙂😀"}
extra |= {0x00b7, 0x2014, 0x2022, 0x200d, 0x20e3, 0xfe0f}
build("MoxiTestPrimary", ascii_points, 500)
build("MoxiTestFallback", ascii_points | extra, 700)
build("MoxiTestWide", ascii_points | extra, 950)
