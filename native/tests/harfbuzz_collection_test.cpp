#include "../harfbuzz_collection.h"
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
#include <string>

static MoxiHBParagraph *shape(MoxiFontCollection *c, const char *text, float width = 0, int direction = 1) {
    auto p = moxi_hb_paragraph_create(c, text, 20, width, direction);
    assert(p && moxi_font_collection_status(c) == MOXI_TEXT_OK); return p;
}
int main() {
    static_assert(MOXI_FONT_NOTDEF == 0 && MOXI_FONT_REJECT == 1);
    static_assert(MOXI_TEXT_OK == 0 && MOXI_TEXT_INVALID == 1 && MOXI_TEXT_NO_FONT == 2
                  && MOXI_TEXT_MISSING == 3 && MOXI_TEXT_UNSUPPORTED == 4);
    auto c = moxi_font_collection_create();
    assert(!moxi_hb_paragraph_create(c, "x", 20, 0, 1));
    assert(moxi_font_collection_status(c) == MOXI_TEXT_NO_FONT);
    assert(moxi_font_collection_add_file(c, "tests/fixtures/fonts/MoxiTestPrimary.ttf", 0));
    auto revision = moxi_font_collection_revision(c);
    assert(!moxi_font_collection_add_file(c, "/nonexistent/font.ttf", 0));
    assert(!moxi_font_collection_add_file(c, "tests/fixtures/fonts/MoxiTestPrimary.ttf", 99));
    assert(moxi_font_collection_revision(c) == revision);
    assert(moxi_font_collection_count(c) == 1);
    assert(moxi_font_collection_add_file(c, "tests/fixtures/fonts/MoxiTestFallback.ttf", 0));
    assert(moxi_font_collection_add_file(c, "tests/fixtures/fonts/MoxiTestWide.ttf", 0));
    assert(!moxi_font_collection_policy(c, 77));
    auto p = shape(c, "Aé世界👩‍💻🇺🇸");
    assert(moxi_hb_paragraph_missing(p) == 0);
    assert(moxi_hb_glyph_int(p, 0, MOXI_GLYPH_FONT) == 0);
    for (int i = 1; i < moxi_hb_paragraph_count(p); ++i) {
        assert(moxi_hb_glyph_int(p, i, MOXI_GLYPH_FONT) == 1);
        int start = moxi_hb_glyph_int(p, i, MOXI_GLYPH_CLUSTER);
        assert(start != 2 && start != 6 && start != 7 && start != 9);
    }
    assert(moxi_hb_caret_offset(p, 2) != 2); // e + combining acute
    auto old_width = moxi_hb_paragraph_width(p);
    auto old_revision = moxi_hb_paragraph_revision(p);
    auto builds = moxi_font_collection_builds(c);
    auto cached = shape(c, "Aé世界👩‍💻🇺🇸");
    assert(moxi_font_collection_hits(c) == 1 && moxi_font_collection_builds(c) == builds);
    moxi_hb_paragraph_release(cached);
    assert(moxi_font_collection_move(c, 2, 1));
    auto changed = shape(c, "Aé世界👩‍💻🇺🇸");
    assert(moxi_hb_paragraph_width(changed) > old_width);
    assert(moxi_hb_paragraph_revision(changed) > old_revision);
    assert(moxi_hb_paragraph_width(p) == old_width && moxi_hb_paragraph_revision(p) == old_revision);
    assert(moxi_font_collection_builds(c) == builds + 1);
    assert(moxi_font_collection_move(c, 1, 1));
    revision = moxi_font_collection_revision(c);
    assert(!moxi_font_collection_move(c, -1, 0));
    assert(moxi_font_collection_revision(c) == revision);
    moxi_hb_paragraph_release(changed);
    auto narrow = shape(c, "Aé世界👩‍💻🇺🇸", 25);
    assert(moxi_hb_paragraph_lines(narrow) > 1);
    // No composed fallback unit crosses line boundaries, even if it overflows.
    for (int i = 1; i < moxi_hb_paragraph_count(narrow); ++i)
        if (moxi_hb_glyph_int(narrow, i, MOXI_GLYPH_CLUSTER) == moxi_hb_glyph_int(narrow, i-1, MOXI_GLYPH_CLUSTER))
            assert(moxi_hb_glyph_int(narrow, i, MOXI_GLYPH_LINE) == moxi_hb_glyph_int(narrow, i-1, MOXI_GLYPH_LINE));
    assert(moxi_hb_selection_count(narrow, 0, 10) > 1);
    assert(moxi_hb_selection_count(narrow, 3, 3) == 0);
    assert(moxi_hb_selection_count(narrow, 10, 0) == moxi_hb_selection_count(narrow, 0, 10));
    assert(moxi_hb_selection_rect(narrow, 0, 10, 1, 1) > 0); // a wrapped line
    assert(moxi_hb_caret_offset(narrow, std::numeric_limits<int>::min()) == 0);
    assert(moxi_hb_caret_offset(narrow, std::numeric_limits<int>::max()) == 10);
    assert(moxi_hb_hit_test(narrow, 1e30f, 1e30f) >= 0);
    moxi_hb_paragraph_release(narrow);
    auto missing = shape(c, "\xf4\x8f\xbf\xbf");
    assert(moxi_hb_paragraph_missing(missing) == 1);
    assert(moxi_hb_glyph_int(missing, 0, MOXI_GLYPH_ID) == 0);
    assert(moxi_font_collection_policy(c, MOXI_FONT_REJECT));
    assert(!moxi_hb_paragraph_create(c, "\xf4\x8f\xbf\xbf", 20, 0, 1));
    assert(moxi_font_collection_status(c) == MOXI_TEXT_MISSING);
    moxi_hb_paragraph_release(missing);
    for (const auto *bad : {"\xc0\xaf", "\xed\xa0\x80", "\xf4\x90\x80\x80", "\xe2\x82"}) {
        assert(!moxi_hb_paragraph_create(c, bad, 20, 0, 1));
        assert(moxi_font_collection_status(c) == MOXI_TEXT_INVALID);
    }
    assert(!moxi_hb_paragraph_create(c, "abc", 20, -1, 1));
    assert(!moxi_hb_paragraph_create(c, "abc", NAN, 0, 1));
    assert(!moxi_hb_paragraph_create(c, "abc", 20, INFINITY, 1));
    assert(!moxi_hb_paragraph_create(c, "abc", 20, 0, 3));
    assert(!moxi_hb_paragraph_create(c, std::string(2049, 'a').c_str(), 20, 0, 1));
    assert(!moxi_hb_paragraph_create(c, "a\xe2\x80\xae" "b", 20, 0, 1));
    assert(moxi_font_collection_status(c) == MOXI_TEXT_UNSUPPORTED);
    assert(!moxi_hb_paragraph_create(c, "a\xd8\x9c", 20, 0, 1)); // Arabic letter mark
    assert(moxi_font_collection_status(c) == MOXI_TEXT_UNSUPPORTED);
    auto breaks = shape(c, "A\r\n\r\nB\n");
    assert(moxi_hb_paragraph_lines(breaks) == 4);
    moxi_hb_paragraph_release(breaks);
    auto empty = shape(c, ""); assert(moxi_hb_paragraph_lines(empty) == 1);
    assert(moxi_hb_caret_offset(empty, 100) == 0); moxi_hb_paragraph_release(empty);
    auto ligature = shape(c, "fi");
    assert(moxi_hb_paragraph_count(ligature) == 1);
    assert(moxi_hb_caret_offset(ligature, 1) != 1);
    assert(moxi_hb_selection_count(ligature, 0, 2) == 1);
    moxi_hb_paragraph_release(ligature);
    auto latin = shape(c, "ABC");
    for (int offset = 0; offset <= 3; ++offset)
        assert(moxi_hb_hit_test(latin, moxi_hb_caret_x(latin, offset), moxi_hb_caret_y(latin, offset)) == offset);
    moxi_hb_paragraph_release(latin);
    auto rtl = shape(c, "שלום", 0, 0);
    assert(moxi_hb_paragraph_direction(rtl) == 2);
    assert(moxi_hb_glyph_int(rtl, 0, MOXI_GLYPH_CLUSTER) > moxi_hb_glyph_int(rtl, moxi_hb_paragraph_count(rtl)-1, MOXI_GLYPH_CLUSTER));
    moxi_hb_paragraph_release(rtl);
    // A second collection has independent revision, cache and face order.
    auto other = moxi_font_collection_create();
    assert(moxi_font_collection_add_file(other, "tests/fixtures/fonts/MoxiTestPrimary.ttf", 0));
    auto independent = shape(other, "ABC");
    assert(moxi_font_collection_builds(other) == 1 && moxi_font_collection_hits(other) == 0);
    auto before_add = shape(other, "é");
    assert(moxi_hb_paragraph_missing(before_add) == 1);
    assert(moxi_font_collection_add_file(other, "tests/fixtures/fonts/MoxiTestFallback.ttf", 0));
    auto after_add = shape(other, "é");
    assert(moxi_hb_paragraph_missing(after_add) == 0);
    assert(moxi_hb_paragraph_missing(before_add) == 1);
    assert(moxi_hb_paragraph_revision(after_add) > moxi_hb_paragraph_revision(before_add));
    moxi_hb_paragraph_release(before_add); moxi_hb_paragraph_release(after_add);
    moxi_font_collection_release(other);
    assert(moxi_hb_paragraph_width(independent) == 30);
    moxi_hb_paragraph_release(independent);
    moxi_font_collection_release(c);
    // Collection destruction and cache eviction do not invalidate retained output.
    assert(moxi_hb_paragraph_width(p) == old_width);
    assert(moxi_hb_paragraph_svg(p, "/tmp/moxi-f01-retained.svg", 1, 8));
    moxi_hb_paragraph_release(p);
    std::cout << "HarfBuzz collection policy, lifetime, invalidation, wrapping and caret tests passed\n";
}
