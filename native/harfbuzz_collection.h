#ifndef MOXI_HARFBUZZ_COLLECTION_H
#define MOXI_HARFBUZZ_COLLECTION_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Instance-owned, serialized per collection. No implicit fallback outside the
   ordered collection. File + face index identifies a host-owned font choice. */
typedef struct MoxiFontCollection MoxiFontCollection;
typedef struct MoxiHBParagraph MoxiHBParagraph;
typedef enum { MOXI_FONT_NOTDEF = 0, MOXI_FONT_REJECT = 1 } MoxiMissingFontPolicy;
typedef enum {
    MOXI_TEXT_OK = 0, MOXI_TEXT_INVALID = 1, MOXI_TEXT_NO_FONT = 2,
    MOXI_TEXT_MISSING = 3, MOXI_TEXT_UNSUPPORTED = 4
} MoxiTextStatus;
typedef enum {
    MOXI_GLYPH_CODEPOINT, MOXI_GLYPH_ID, MOXI_GLYPH_CLUSTER,
    MOXI_GLYPH_END, MOXI_GLYPH_FONT, MOXI_GLYPH_LINE, MOXI_GLYPH_DIRECTION,
    MOXI_GLYPH_SCRIPT
} MoxiGlyphIntField;
typedef enum { MOXI_GLYPH_ADVANCE, MOXI_GLYPH_X, MOXI_GLYPH_Y } MoxiGlyphFloatField;
MoxiFontCollection *moxi_font_collection_create(void);
void moxi_font_collection_release(MoxiFontCollection *collection);
int moxi_font_collection_add_file(MoxiFontCollection *, const char *, int face_index);
/* Fontconfig resolves a family once, including its actual collection face index. */
int moxi_font_collection_add_family(MoxiFontCollection *, const char *);
int moxi_font_collection_policy(MoxiFontCollection *, int policy);
int moxi_font_collection_move(MoxiFontCollection *, int from, int to);
uint64_t moxi_font_collection_revision(const MoxiFontCollection *);
uint64_t moxi_font_collection_builds(const MoxiFontCollection *);
uint64_t moxi_font_collection_hits(const MoxiFontCollection *);
int moxi_font_collection_count(const MoxiFontCollection *);
const char *moxi_font_collection_path(const MoxiFontCollection *, int);
int moxi_font_collection_face_index(const MoxiFontCollection *, int);
/* Exact cache key: collection revision, UTF-8 bytes, size, width, direction.
   Failed requests never return a stale paragraph. Width 0 means unconstrained.
   Limit: 2048 scalars; practical graphemes, greedy cluster wrapping, coarse
   run bidi. Bidi controls are explicitly unsupported (not UAX #9). */
MoxiHBParagraph *moxi_hb_paragraph_create(MoxiFontCollection *, const char *, float, float, int);
int moxi_font_collection_status(const MoxiFontCollection *);
void moxi_hb_paragraph_release(MoxiHBParagraph *);
int moxi_hb_paragraph_count(const MoxiHBParagraph *);
int moxi_hb_paragraph_lines(const MoxiHBParagraph *);
int moxi_hb_paragraph_direction(const MoxiHBParagraph *);
int moxi_hb_paragraph_missing(const MoxiHBParagraph *);
uint64_t moxi_hb_paragraph_revision(const MoxiHBParagraph *);
float moxi_hb_paragraph_width(const MoxiHBParagraph *);
float moxi_hb_paragraph_height(const MoxiHBParagraph *);
int moxi_hb_glyph_int(const MoxiHBParagraph *, int, int field);
float moxi_hb_glyph_float(const MoxiHBParagraph *, int, int field);
/* Carets clamp to a shaped cluster boundary. Selection is one rect per shaped
   cluster, so mixed-direction selections can have disjoint visual geometry. */
int moxi_hb_caret_offset(const MoxiHBParagraph *, int offset);
float moxi_hb_caret_x(const MoxiHBParagraph *, int offset);
float moxi_hb_caret_y(const MoxiHBParagraph *, int offset);
int moxi_hb_hit_test(const MoxiHBParagraph *, float x, float y);
int moxi_hb_selection_count(const MoxiHBParagraph *, int start, int end);
/* Rect fields: x=0, y=1, width=2, height=3. */
float moxi_hb_selection_rect(const MoxiHBParagraph *, int start, int end, int index, int field);
/* Diagnostic SVG uses the actual FreeType outlines, never browser re-shaping. */
int moxi_hb_paragraph_svg(const MoxiHBParagraph *, const char *path, int start, int end);
#ifdef __cplusplus
}
#endif
#endif
