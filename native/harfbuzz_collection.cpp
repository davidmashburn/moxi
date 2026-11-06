#include "harfbuzz_collection.h"
#include <hb-ft.h>
#include <fontconfig/fontconfig.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H
#include <algorithm>
#include <cmath>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

namespace {
constexpr int MaxScalars = 2048;
enum class Direction { Auto, LTR, RTL };
struct Library {
    FT_Library ft = nullptr;
    Library() { if (FT_Init_FreeType(&ft)) ft = nullptr; }
    ~Library() { if (ft) FT_Done_FreeType(ft); }
};
struct Face {
    std::shared_ptr<Library> library;
    FT_Face ft = nullptr;
    std::string path;
    int index;
    ~Face() { if (ft) FT_Done_Face(ft); }
};
struct Scalar { uint32_t cp; int byte; };
struct Cluster { int start, end, font; hb_script_t script; Direction direction; bool missing; };
struct Glyph {
    int cp, id, start, end, font, line;
    Direction direction;
    hb_script_t script;
    float advance, x, y;
};
struct Caret { int offset; float x, y; };
struct Paragraph {
    std::string text;
    std::vector<std::shared_ptr<Face>> faces;
    std::vector<Glyph> glyphs;
    std::vector<Caret> carets;
    uint64_t revision = 0;
    float size, constraint, width = 0, height = 0, line_height = 0, ascent = 0;
    int lines = 0, missing = 0;
    Direction requested, direction;
};
bool decode(const std::string &text, std::vector<Scalar> &scalars) {
    for (size_t i = 0; i < text.size();) {
        size_t start = i;
        unsigned char c = text[i++];
        uint32_t cp = c;
        int continuation = 0;
        if (c >= 0xc2 && c <= 0xdf) { cp = c & 31; continuation = 1; }
        else if (c >= 0xe0 && c <= 0xef) { cp = c & 15; continuation = 2; }
        else if (c >= 0xf0 && c <= 0xf4) { cp = c & 7; continuation = 3; }
        else if (c >= 0x80) return false;
        if (i + continuation > text.size()) return false;
        for (int j = 0; j < continuation; ++j) {
            c = text[i++];
            if ((c & 0xc0) != 0x80) return false;
            cp = (cp << 6) | (c & 63);
        }
        if ((continuation == 1 && cp < 0x80) || (continuation == 2 && cp < 0x800)
            || (continuation == 3 && cp < 0x10000) || cp > 0x10ffff
            || (cp >= 0xd800 && cp <= 0xdfff)) return false;
        scalars.push_back({cp, int(start)});
        if (scalars.size() > MaxScalars) return false;
    }
    return true;
}
bool regional(uint32_t cp) { return cp >= 0x1f1e6 && cp <= 0x1f1ff; }
bool extend(uint32_t cp) {
    auto category = hb_unicode_general_category(hb_unicode_funcs_get_default(), cp);
    return category == HB_UNICODE_GENERAL_CATEGORY_NON_SPACING_MARK
        || category == HB_UNICODE_GENERAL_CATEGORY_SPACING_MARK
        || category == HB_UNICODE_GENERAL_CATEGORY_ENCLOSING_MARK
        || cp == 0x200d || (cp >= 0xfe00 && cp <= 0xfe0f)
        || (cp >= 0xe0100 && cp <= 0xe01ef) || (cp >= 0x1f3fb && cp <= 0x1f3ff);
}
bool ignorable(uint32_t cp) {
    return cp == 0x200d || cp == 0x200c || (cp >= 0xfe00 && cp <= 0xfe0f)
        || (cp >= 0xe0100 && cp <= 0xe01ef);
}
bool newline(uint32_t cp) { return cp == '\n' || cp == '\r'; }
bool unsupported(uint32_t cp) {
    return (cp >= 0x202a && cp <= 0x202e) || (cp >= 0x2066 && cp <= 0x2069)
        || cp == 0x061c || cp == 0x200e || cp == 0x200f || cp == '\t';
}
Direction script_direction(hb_script_t script, Direction neutral) {
    if (script == HB_SCRIPT_COMMON || script == HB_SCRIPT_INHERITED) return neutral;
    return hb_script_get_horizontal_direction(script) == HB_DIRECTION_RTL ? Direction::RTL : Direction::LTR;
}
int portable_script(hb_script_t script) {
    switch (script) {
    case HB_SCRIPT_LATIN: case HB_SCRIPT_GREEK: return 1;
    case HB_SCRIPT_CYRILLIC: return 2;
    case HB_SCRIPT_ARABIC: case HB_SCRIPT_HEBREW: return 3;
    case HB_SCRIPT_HAN: case HB_SCRIPT_HIRAGANA: case HB_SCRIPT_KATAKANA: case HB_SCRIPT_HANGUL: return 4;
    case HB_SCRIPT_DEVANAGARI: return 5;
    default: return 0;
    }
}
}
struct MoxiHBParagraph { std::shared_ptr<Paragraph> value; };
struct MoxiFontCollection {
    std::shared_ptr<Library> library = std::make_shared<Library>();
    std::vector<std::shared_ptr<Face>> faces;
    MoxiMissingFontPolicy policy = MOXI_FONT_NOTDEF;
    MoxiTextStatus status = MOXI_TEXT_OK;
    uint64_t revision = 1, builds = 0, hits = 0;
    std::shared_ptr<Paragraph> cached;
    void changed() { ++revision; cached.reset(); status = MOXI_TEXT_OK; }
};
extern "C" MoxiFontCollection *moxi_font_collection_create() { return new MoxiFontCollection; }
extern "C" void moxi_font_collection_release(MoxiFontCollection *c) { delete c; }
extern "C" int moxi_font_collection_add_file(MoxiFontCollection *c, const char *path, int index) {
    if (!c || !path || !*path || index < 0 || !c->library->ft) return 0;
    auto face = std::make_shared<Face>();
    face->library = c->library; face->path = path; face->index = index;
    if (FT_New_Face(c->library->ft, path, index, &face->ft)) return 0;
    if (!FT_IS_SCALABLE(face->ft) || FT_Select_Charmap(face->ft, FT_ENCODING_UNICODE)) return 0;
    c->faces.push_back(face); c->changed(); return 1;
}
extern "C" int moxi_font_collection_add_family(MoxiFontCollection *c, const char *family) {
    if (!c || !family || !*family || !FcInit()) return 0;
    FcPattern *p = FcPatternBuild(nullptr, FC_FAMILY, FcTypeString, family, nullptr);
    if (!p) return 0;
    FcConfigSubstitute(nullptr, p, FcMatchPattern); FcDefaultSubstitute(p);
    FcResult result;
    FcPattern *match = FcFontMatch(nullptr, p, &result); FcPatternDestroy(p);
    if (!match) return 0;
    FcChar8 *path = nullptr; int index = 0;
    FcPatternGetInteger(match, FC_INDEX, 0, &index);
    int ok = FcPatternGetString(match, FC_FILE, 0, &path) == FcResultMatch
        && moxi_font_collection_add_file(c, reinterpret_cast<const char *>(path), index);
    FcPatternDestroy(match); return ok;
}
extern "C" int moxi_font_collection_policy(MoxiFontCollection *c, int policy) {
    if (!c || (policy != MOXI_FONT_NOTDEF && policy != MOXI_FONT_REJECT)) return 0;
    if (c->policy != policy) { c->policy = static_cast<MoxiMissingFontPolicy>(policy); c->changed(); }
    return 1;
}
extern "C" int moxi_font_collection_move(MoxiFontCollection *c, int from, int to) {
    if (!c || from < 0 || to < 0 || from >= int(c->faces.size()) || to >= int(c->faces.size())) return 0;
    if (from != to) { auto face = c->faces[from]; c->faces.erase(c->faces.begin() + from);
        c->faces.insert(c->faces.begin() + to, face); c->changed(); }
    return 1;
}
extern "C" uint64_t moxi_font_collection_revision(const MoxiFontCollection *c) { return c ? c->revision : 0; }
extern "C" uint64_t moxi_font_collection_builds(const MoxiFontCollection *c) { return c ? c->builds : 0; }
extern "C" uint64_t moxi_font_collection_hits(const MoxiFontCollection *c) { return c ? c->hits : 0; }
extern "C" int moxi_font_collection_count(const MoxiFontCollection *c) { return c ? int(c->faces.size()) : 0; }
extern "C" const char *moxi_font_collection_path(const MoxiFontCollection *c, int i) {
    return c && i >= 0 && i < int(c->faces.size()) ? c->faces[i]->path.c_str() : "";
}
extern "C" int moxi_font_collection_face_index(const MoxiFontCollection *c, int i) {
    return c && i >= 0 && i < int(c->faces.size()) ? c->faces[i]->index : -1;
}
extern "C" int moxi_font_collection_status(const MoxiFontCollection *c) { return c ? c->status : MOXI_TEXT_INVALID; }

namespace {
std::vector<Glyph> shape_line(Paragraph &p, const std::vector<Scalar> &s,
                             const std::vector<Cluster> &clusters, int begin, int end) {
    std::vector<std::vector<Glyph>> runs;
    int line_start = s[clusters[begin].start].byte;
    int last_cp = clusters[end - 1].end;
    int line_end = last_cp < int(s.size()) ? s[last_cp].byte : int(p.text.size());
    for (int i = begin; i < end;) {
        int stop = i + 1;
        const auto &first = clusters[i];
        while (stop < end && clusters[stop].font == first.font
               && clusters[stop].script == first.script && clusters[stop].direction == first.direction) ++stop;
        int start_cp = first.start, end_cp = clusters[stop - 1].end;
        int start_byte = s[start_cp].byte;
        int end_byte = end_cp < int(s.size()) ? s[end_cp].byte : int(p.text.size());
        auto face = p.faces[first.font]->ft;
        FT_Set_Char_Size(face, 0, FT_F26Dot6(std::lround(p.size * 64)), 72, 72);
        hb_font_t *font = hb_ft_font_create_referenced(face);
        hb_buffer_t *buffer = hb_buffer_create();
        // Context may cross face/script runs, but never a newly wrapped line.
        hb_buffer_add_utf8(buffer, p.text.c_str() + line_start, line_end - line_start,
                           start_byte - line_start, end_byte - start_byte);
        hb_buffer_set_flags(buffer, static_cast<hb_buffer_flags_t>(
            (i == begin ? HB_BUFFER_FLAG_BOT : 0) | (stop == end ? HB_BUFFER_FLAG_EOT : 0)));
        hb_buffer_set_direction(buffer, first.direction == Direction::RTL ? HB_DIRECTION_RTL : HB_DIRECTION_LTR);
        hb_buffer_set_script(buffer, first.script);
        hb_buffer_set_cluster_level(buffer, HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES);
        hb_shape(font, buffer, nullptr, 0);
        unsigned count;
        auto infos = hb_buffer_get_glyph_infos(buffer, &count);
        auto positions = hb_buffer_get_glyph_positions(buffer, &count);
        std::vector<int> starts;
        std::vector<int> mapped;
        for (unsigned j = 0; j < count; ++j) {
            int cp = start_cp;
            while (cp + 1 < end_cp && s[cp + 1].byte <= line_start + int(infos[j].cluster)) ++cp;
            // Normalize to the fallback unit, including ZWJ and flag sequences.
            for (int k = i; k < stop; ++k) if (cp >= clusters[k].start && cp < clusters[k].end) { cp = clusters[k].start; break; }
            mapped.push_back(cp); starts.push_back(cp);
        }
        starts.push_back(end_cp); std::sort(starts.begin(), starts.end());
        starts.erase(std::unique(starts.begin(), starts.end()), starts.end());
        std::vector<Glyph> run;
        for (unsigned j = 0; j < count; ++j) {
            int cp = mapped[j];
            int next = *std::upper_bound(starts.begin(), starts.end(), cp);
            run.push_back({int(s[cp].cp), int(infos[j].codepoint), cp, next, first.font, 0,
                first.direction, first.script, positions[j].x_advance / 64.f,
                positions[j].x_offset / 64.f, -positions[j].y_offset / 64.f});
        }
        hb_buffer_destroy(buffer); hb_font_destroy(font);
        runs.push_back(std::move(run)); i = stop;
    }
    if (p.direction == Direction::RTL) std::reverse(runs.begin(), runs.end());
    std::vector<Glyph> glyphs;
    float x = 0;
    for (auto &run : runs) for (auto glyph : run) { glyph.x += x; x += glyph.advance; glyphs.push_back(glyph); }
    return glyphs;
}
float advance(const std::vector<Glyph> &glyphs) { float width = 0; for (auto &g : glyphs) width += g.advance; return width; }
void append_line(Paragraph &p, std::vector<Glyph> glyphs, int start, int end) {
    float y = p.lines * p.line_height;
    float width = advance(glyphs);
    p.width = std::max(p.width, width);
    if (glyphs.empty()) p.carets.push_back({start, 0, y});
    for (size_t i = 0; i < glyphs.size();) {
        size_t stop = i + 1;
        while (stop < glyphs.size() && glyphs[stop].start == glyphs[i].start) ++stop;
        // Cursor geometry follows advances, independent of glyph ink offsets.
        float x = 0; for (size_t j = 0; j < i; ++j) x += glyphs[j].advance;
        float w = 0; for (size_t j = i; j < stop; ++j) w += glyphs[j].advance;
        bool rtl = glyphs[i].direction == Direction::RTL;
        p.carets.push_back({glyphs[i].start, rtl ? x + w : x, y});
        p.carets.push_back({glyphs[i].end, rtl ? x : x + w, y});
        i = stop;
    }
    (void)end;
    for (auto &g : glyphs) { g.line = p.lines; g.y += y + p.ascent; p.glyphs.push_back(g); }
    ++p.lines; p.height = p.lines * p.line_height;
}
const Caret &caret(const Paragraph &p, int offset) {
    // Downstream affinity at a wrap or directional boundary.
    const Caret *best = &p.carets.front();
    for (const auto &c : p.carets) if (std::abs(int64_t(c.offset) - offset) <= std::abs(int64_t(best->offset) - offset)) best = &c;
    return *best;
}
}
extern "C" MoxiHBParagraph *moxi_hb_paragraph_create(MoxiFontCollection *c, const char *text, float size, float width, int direction) {
    if (!c) return nullptr;
    c->status = MOXI_TEXT_INVALID;
    if (!text || !std::isfinite(size) || !std::isfinite(width) || size <= 0 || size > 4096 || width < 0 || direction < 0 || direction > 2) return nullptr;
    if (c->faces.empty()) { c->status = MOXI_TEXT_NO_FONT; return nullptr; }
    if (c->cached && c->cached->text == text && c->cached->size == size
        && c->cached->constraint == width && int(c->cached->requested) == direction) {
        ++c->hits; c->status = MOXI_TEXT_OK; return new MoxiHBParagraph{c->cached};
    }
    auto p = std::make_shared<Paragraph>();
    p->text = text; p->faces = c->faces; p->revision = c->revision;
    p->size = size; p->constraint = width; p->requested = static_cast<Direction>(direction);
    p->direction = direction == 2 ? Direction::RTL : Direction::LTR;
    std::vector<Scalar> s;
    if (!decode(p->text, s)) return nullptr;
    for (const auto &scalar : s) if (unsupported(scalar.cp)) { c->status = MOXI_TEXT_UNSUPPORTED; return nullptr; }
    if (!direction) for (auto &scalar : s) {
        auto script = hb_unicode_script(hb_unicode_funcs_get_default(), scalar.cp);
        if (script != HB_SCRIPT_COMMON && script != HB_SCRIPT_INHERITED) { p->direction = script_direction(script, Direction::LTR); break; }
    }
    for (auto &face : p->faces) {
        if (FT_Set_Char_Size(face->ft, 0, FT_F26Dot6(std::lround(size * 64)), 72, 72)) return nullptr;
        p->ascent = std::max(p->ascent, face->ft->size->metrics.ascender / 64.f);
        p->line_height = std::max(p->line_height, (face->ft->size->metrics.ascender - face->ft->size->metrics.descender) / 64.f);
    }
    p->line_height = std::max(p->line_height, size * 1.25f);
    std::vector<Cluster> clusters;
    Direction previous_direction = p->direction;
    hb_script_t previous_script = HB_SCRIPT_COMMON;
    for (int i = 0; i < int(s.size());) {
        int end = i + 1;
        if (s[i].cp == '\r' && end < int(s.size()) && s[end].cp == '\n') ++end;
        else if (!newline(s[i].cp)) {
            if (regional(s[i].cp) && end < int(s.size()) && regional(s[end].cp)) ++end;
            while (end < int(s.size()) && !newline(s[end].cp)
                   && (extend(s[end].cp) || s[end - 1].cp == 0x200d || s[end - 1].cp == 0x094d)) ++end;
        }
        int selected = -1;
        for (int f = 0; f < int(c->faces.size()); ++f) {
            bool covers = true;
            for (int j = i; j < end; ++j) if (!ignorable(s[j].cp) && !newline(s[j].cp)
                && !FT_Get_Char_Index(c->faces[f]->ft, s[j].cp)) covers = false;
            if (covers) { selected = f; break; }
        }
        bool missing = selected < 0;
        if (missing) {
            ++p->missing;
            if (c->policy == MOXI_FONT_REJECT) { c->status = MOXI_TEXT_MISSING; return nullptr; }
            selected = 0;
        }
        auto script = hb_unicode_script(hb_unicode_funcs_get_default(), s[i].cp);
        if (script == HB_SCRIPT_COMMON || script == HB_SCRIPT_INHERITED) script = previous_script;
        auto dir = script_direction(script, previous_direction);
        clusters.push_back({i, end, selected, script, dir, missing});
        previous_direction = dir; previous_script = script; i = end;
    }
    int begin = 0;
    while (begin < int(clusters.size())) {
        if (newline(s[clusters[begin].start].cp)) {
            append_line(*p, {}, clusters[begin].start, clusters[begin].start); ++begin; continue;
        }
        int end = begin;
        std::vector<Glyph> accepted;
        while (end < int(clusters.size()) && !newline(s[clusters[end].start].cp)) {
            auto candidate = shape_line(*p, s, clusters, begin, end + 1);
            if (width > 0 && end > begin && advance(candidate) > width) break;
            accepted = std::move(candidate); ++end;
        }
        append_line(*p, std::move(accepted), clusters[begin].start, clusters[end - 1].end);
        begin = end;
        if (begin < int(clusters.size()) && newline(s[clusters[begin].start].cp)) ++begin;
    }
    if (clusters.empty() || newline(s.back().cp)) append_line(*p, {}, int(s.size()), int(s.size()));
    ++c->builds; c->status = MOXI_TEXT_OK; c->cached = p;
    return new MoxiHBParagraph{std::move(p)};
}
extern "C" void moxi_hb_paragraph_release(MoxiHBParagraph *p) { delete p; }
extern "C" int moxi_hb_paragraph_count(const MoxiHBParagraph *p) { return p ? int(p->value->glyphs.size()) : 0; }
extern "C" int moxi_hb_paragraph_lines(const MoxiHBParagraph *p) { return p ? p->value->lines : 0; }
extern "C" int moxi_hb_paragraph_direction(const MoxiHBParagraph *p) { return p ? int(p->value->direction) : 0; }
extern "C" int moxi_hb_paragraph_missing(const MoxiHBParagraph *p) { return p ? p->value->missing : 0; }
extern "C" uint64_t moxi_hb_paragraph_revision(const MoxiHBParagraph *p) { return p ? p->value->revision : 0; }
extern "C" float moxi_hb_paragraph_width(const MoxiHBParagraph *p) { return p ? p->value->width : 0; }
extern "C" float moxi_hb_paragraph_height(const MoxiHBParagraph *p) { return p ? p->value->height : 0; }
extern "C" int moxi_hb_glyph_int(const MoxiHBParagraph *p, int i, int field) {
    if (!p || i < 0 || i >= int(p->value->glyphs.size())) return -1;
    const auto &g = p->value->glyphs[i];
    switch (field) {
    case MOXI_GLYPH_CODEPOINT: return g.cp; case MOXI_GLYPH_ID: return g.id;
    case MOXI_GLYPH_CLUSTER: return g.start; case MOXI_GLYPH_END: return g.end;
    case MOXI_GLYPH_FONT: return g.font; case MOXI_GLYPH_LINE: return g.line;
    case MOXI_GLYPH_DIRECTION: return int(g.direction); case MOXI_GLYPH_SCRIPT: return portable_script(g.script);
    default: return -1;
    }
}
extern "C" float moxi_hb_glyph_float(const MoxiHBParagraph *p, int i, int field) {
    if (!p || i < 0 || i >= int(p->value->glyphs.size())) return 0;
    const auto &g = p->value->glyphs[i];
    switch (field) { case MOXI_GLYPH_ADVANCE: return g.advance; case MOXI_GLYPH_X: return g.x;
        case MOXI_GLYPH_Y: return g.y; default: return 0; }
}
extern "C" int moxi_hb_caret_offset(const MoxiHBParagraph *p, int offset) { return p ? caret(*p->value, offset).offset : 0; }
extern "C" float moxi_hb_caret_x(const MoxiHBParagraph *p, int offset) { return p ? caret(*p->value, offset).x : 0; }
extern "C" float moxi_hb_caret_y(const MoxiHBParagraph *p, int offset) { return p ? caret(*p->value, offset).y : 0; }
extern "C" int moxi_hb_hit_test(const MoxiHBParagraph *p, float x, float y) {
    if (!p || !std::isfinite(x) || !std::isfinite(y)) return 0;
    int line = int(std::clamp(y / p->value->line_height, 0.f, float(p->value->lines - 1)));
    const Caret *best = nullptr;
    for (auto &c : p->value->carets) if (int(c.y / p->value->line_height) == line)
        if (!best || std::abs(c.x - x) <= std::abs(best->x - x)) best = &c;
    return best ? best->offset : 0;
}
namespace {
struct SelectionRect { float x, y, width, height; };
std::vector<SelectionRect> selection(const Paragraph &p, int start, int end) {
    int a = caret(p, start).offset, b = caret(p, end).offset;
    if (a > b) std::swap(a, b);
    std::vector<SelectionRect> rects;
    if (a == b) return rects;
    float x = 0; int line = 0;
    for (size_t i = 0; i < p.glyphs.size();) {
        const auto &g = p.glyphs[i];
        if (g.line != line) { line = g.line; x = 0; }
        size_t stop = i + 1; float width = g.advance;
        while (stop < p.glyphs.size() && p.glyphs[stop].line == line && p.glyphs[stop].start == g.start)
            width += p.glyphs[stop++].advance;
        if (g.start < b && g.end > a) rects.push_back({x, line*p.line_height, width, p.line_height});
        x += width; i = stop;
    }
    return rects;
}
}
extern "C" int moxi_hb_selection_count(const MoxiHBParagraph *p, int start, int end) {
    return p ? int(selection(*p->value, start, end).size()) : 0;
}
extern "C" float moxi_hb_selection_rect(const MoxiHBParagraph *p, int start, int end, int index, int field) {
    if (!p || index < 0) return 0;
    auto rects = selection(*p->value, start, end);
    if (index >= int(rects.size())) return 0;
    auto &r = rects[index];
    switch (field) { case 0: return r.x; case 1: return r.y; case 2: return r.width; case 3: return r.height; default: return 0; }
}

namespace {
struct SVGPath { std::ostream &out; bool started = false; };
int move_to(const FT_Vector *p, void *data) { auto &s = *static_cast<SVGPath *>(data); if (s.started) s.out << "Z "; s.started = true; s.out << "M" << p->x/64.f << " " << -p->y/64.f << " "; return 0; }
int line_to(const FT_Vector *p, void *data) { static_cast<SVGPath *>(data)->out << "L" << p->x/64.f << " " << -p->y/64.f << " "; return 0; }
int conic_to(const FT_Vector *c, const FT_Vector *p, void *data) { static_cast<SVGPath *>(data)->out << "Q" << c->x/64.f << " " << -c->y/64.f << " " << p->x/64.f << " " << -p->y/64.f << " "; return 0; }
int cubic_to(const FT_Vector *a, const FT_Vector *b, const FT_Vector *p, void *data) { static_cast<SVGPath *>(data)->out << "C" << a->x/64.f << " " << -a->y/64.f << " " << b->x/64.f << " " << -b->y/64.f << " " << p->x/64.f << " " << -p->y/64.f << " "; return 0; }
}
extern "C" int moxi_hb_paragraph_svg(const MoxiHBParagraph *handle, const char *path, int start, int end) {
    if (!handle || !path) return 0;
    const auto &p = *handle->value;
    std::ofstream out(path); if (!out) return 0;
    out << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" << std::max(p.width, p.constraint)+40
        << "\" height=\"" << p.height+40 << "\"><rect width=\"100%\" height=\"100%\" fill=\"#fff\"/><g transform=\"translate(20 20)\">";
    for (auto &r : selection(p, start, end))
        out << "<rect x=\"" << r.x << "\" y=\"" << r.y << "\" width=\"" << r.width
            << "\" height=\"" << r.height << "\" fill=\"#c8ddff\"/>";
    for (auto &g : p.glyphs) {
        auto face = p.faces[g.font]->ft;
        FT_Set_Char_Size(face, 0, FT_F26Dot6(std::lround(p.size*64)), 72, 72);
        if (FT_Load_Glyph(face, g.id, FT_LOAD_NO_BITMAP) || face->glyph->format != FT_GLYPH_FORMAT_OUTLINE || face->glyph->outline.n_points == 0) continue;
        out << "<path fill=\"" << (g.font ? "#8c3ca0" : "#18354b") << "\" transform=\"translate(" << g.x << " " << g.y << ")\" d=\"";
        SVGPath sink{out}; FT_Outline_Funcs funcs{move_to, line_to, conic_to, cubic_to, 0, 0};
        FT_Outline_Decompose(&face->glyph->outline, &funcs, &sink);
        out << "Z\"/>";
    }
    const auto &c = caret(p, end);
    out << "<path stroke=\"#d24c2d\" stroke-width=\"2\" d=\"M" << c.x << " " << c.y << "v" << p.line_height << "\"/></g></svg>";
    return bool(out);
}
