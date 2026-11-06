"""Portable collection policy and shared-corpus HarfBuzz integration."""
from moxi import (FontCollection, MissingFontPolicy, FontTextStatus, HarfBuzzTextShaper,
                  TextInputState, canonical_text_corpus, next_text_boundary,
                  default_label_style, test_check, TEXT_DIRECTION_LTR, TEXT_DIRECTION_RTL)


def main() raises:
    var fonts = FontCollection()
    fonts.add_file("tests/fixtures/fonts/MoxiTestPrimary.ttf")
    fonts.add_file("tests/fixtures/fonts/MoxiTestFallback.ttf")
    fonts.add_file("tests/fixtures/fonts/MoxiTestWide.ttf")
    var style = default_label_style()
    style.font_size = 20
    var snapshot = fonts.paragraph("Aé世界", style)
    var original = snapshot.shaped()
    test_check(original.glyph(0).font_id == 0)
    for i in range(1, original.glyph_count()):
        test_check(original.glyph(i).font_id == 1)
        test_check(original.glyph(i).cluster != 2)
    test_check(snapshot.caret_offset(2) != 2)
    test_check(snapshot.missing_clusters() == 0)
    var selection = snapshot.selection_rects(1, 3)
    test_check(len(selection) == 1)
    test_check(selection[0].width > 0 and selection[0].height > 0)
    test_check(len(snapshot.selection_rects(1, 1)) == 0)
    var reversed_selection = snapshot.selection_rects(3, 1)
    test_check(reversed_selection[0].x == selection[0].x)
    test_check(reversed_selection[0].width == selection[0].width)
    var original_revision = snapshot.revision()
    var again = fonts.paragraph("Aé世界", style)
    test_check(fonts.builds() == 1 and fonts.cache_hits() == 1)
    fonts.move(2, 1)
    var replacement = fonts.paragraph("Aé世界", style)
    test_check(replacement.shaped().measurement.size.width > original.measurement.size.width)
    test_check(snapshot.shaped().measurement.size.width == original.measurement.size.width)
    test_check(snapshot.revision() == original_revision)
    test_check(replacement.revision() != original_revision)
    var builds = fonts.builds()
    var resized = fonts.paragraph("Aé世界", style, 30)
    test_check(resized.shaped().measurement.line_count > 1)
    var edited = fonts.paragraph("Aé世界!", style, 30)
    var directed = fonts.paragraph("Aé世界!", style, 30, TEXT_DIRECTION_RTL)
    style.font_size = 21
    var restyled = fonts.paragraph("Aé世界!", style, 30, TEXT_DIRECTION_RTL)
    test_check(fonts.builds() == builds + 4)
    fonts.set_missing_policy(MissingFontPolicy.REJECT)
    var rejected = False
    try:
        var missing = fonts.paragraph("\U0010ffff", style)
    except:
        rejected = True
    test_check(rejected)
    test_check(fonts.status().value == FontTextStatus.MISSING.value)
    fonts.set_missing_policy(MissingFontPolicy.NOTDEF)
    var missing = fonts.paragraph("\U0010ffff", style)
    test_check(missing.missing_clusters() == 1)
    test_check(missing.shaped().glyph(0).glyph_id == 0)
    var shaper = HarfBuzzTextShaper(fonts)
    test_check(shaper.available())
    var corpus = canonical_text_corpus()
    for fixture in corpus:
        var p = fonts.paragraph(fixture.text, style, fixture.max_width, fixture.direction)
        var shaped = p.shaped()
        test_check(not shaped.approximate)
        test_check(p.missing_clusters() == 0)
        test_check(shaped.glyph_count() > 0 and shaped.run_count() > 0)
        test_check(shaped.measurement.size.height > 0 and shaped.measurement.size.width > 0)
        if fixture.expect_wrapping:
            test_check(shaped.measurement.line_count > 1)
        for i in range(shaped.glyph_count()):
            var g = shaped.glyph(i)
            test_check(g.cluster >= 0 and g.cluster < fixture.text.count_codepoints())
            test_check(p.cluster_end(i) > g.cluster and p.cluster_end(i) <= fixture.text.count_codepoints())
            test_check(g.font_id >= 0 and g.font_id < fonts.count())
        for i in range(shaped.run_count()):
            var run = shaped.run(i)
            for j in range(run.glyph_start, run.glyph_end):
                test_check(shaped.glyph(j).font_id == run.font_id)
                test_check(shaped.glyph(j).line == run.line)
                test_check(shaped.glyph(j).cluster >= run.cluster_start)
                test_check(shaped.glyph(j).cluster < run.cluster_end)
        # Caret offsets never land inside the documented editing units.
        for offset in range(fixture.text.count_codepoints() + 1):
            var caret = p.caret_offset(offset)
            var boundary = 0
            while boundary < caret:
                boundary = next_text_boundary(fixture.text, boundary)
            test_check(boundary == caret)
        print("HarfBuzz corpus:", fixture.id, "lines", shaped.measurement.line_count,
              "missing clusters", p.missing_clusters())
    # Line breaks remove joining context even when the source text continues.
    # This compares one engine/font with itself, never cross-engine glyph IDs.
    var system_fonts = FontCollection()
    system_fonts.add_family("Arial Unicode MS")
    var isolated = system_fonts.paragraph("م", style, 1, TEXT_DIRECTION_RTL)
    var wrapped_joining = system_fonts.paragraph("مم", style, 1, TEXT_DIRECTION_RTL)
    test_check(wrapped_joining.shaped().measurement.line_count == 2)
    for glyph in wrapped_joining.shaped().glyphs:
        test_check(glyph.glyph_id == isolated.shaped().glyph(0).glyph_id)
    # Non-throwing compatibility seam exposes failure without stale geometry.
    var unsupported = shaper.shape("abc\u202e", style, 0, TEXT_DIRECTION_LTR)
    test_check(unsupported.glyph_count() == 0 and unsupported.approximate)
    test_check(fonts.status().value == FontTextStatus.UNSUPPORTED.value)
    print("Moxi font collection and paragraph tests passed")
