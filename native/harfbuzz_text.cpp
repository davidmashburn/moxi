#include "harfbuzz_text.h"

#include <hb-ft.h>
#include <hb.h>

#include <fontconfig/fontconfig.h>
#include <ft2build.h>
#include FT_FREETYPE_H

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>

#define MOXI_MAX_HARFBUZZ_GLYPHS 8192

static FT_Library moxi_ft_library;
static FT_Face moxi_ft_face;
static int moxi_initialized;
static int moxi_shaped_count;
static int moxi_shaped_direction;
static int moxi_shaped_codepoints[MOXI_MAX_HARFBUZZ_GLYPHS];
static int moxi_shaped_glyphs[MOXI_MAX_HARFBUZZ_GLYPHS];
static int moxi_shaped_clusters[MOXI_MAX_HARFBUZZ_GLYPHS];
static float moxi_shaped_advances[MOXI_MAX_HARFBUZZ_GLYPHS];
static float moxi_shaped_x[MOXI_MAX_HARFBUZZ_GLYPHS];
static float moxi_shaped_y[MOXI_MAX_HARFBUZZ_GLYPHS];
static float moxi_shaped_width;
static float moxi_shaped_height;

// The C ABI is intentionally single-threaded, matching the main-thread UI
// shaping path. A concurrent host should serialize calls or provide one
// adapter instance per thread.

static bool moxi_init_harfbuzz() {
    if (moxi_initialized != 0) return moxi_initialized > 0;
    moxi_initialized = -1;
    if (FT_Init_FreeType(&moxi_ft_library) != 0) return false;
    if (FcInit() == FcFalse) return false;

    FcPattern *pattern = FcPatternBuild(
        nullptr,
        FC_FAMILY,
        FcTypeString,
        "Arial Unicode MS",
        nullptr
    );
    if (pattern == nullptr) return false;
    FcConfigSubstitute(nullptr, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);
    FcResult result = FcResultNoMatch;
    FcPattern *matched = FcFontMatch(nullptr, pattern, &result);
    FcPatternDestroy(pattern);
    if (matched == nullptr || result != FcResultMatch) {
        if (matched != nullptr) FcPatternDestroy(matched);
        return false;
    }
    FcChar8 *file = nullptr;
    FcResult file_result = FcPatternGetString(matched, FC_FILE, 0, &file);
    if (file_result != FcResultMatch || file == nullptr) {
        FcPatternDestroy(matched);
        return false;
    }
    FT_Error face_result = FT_New_Face(
        moxi_ft_library,
        reinterpret_cast<const char *>(file),
        0,
        &moxi_ft_face
    );
    FcPatternDestroy(matched);
    if (face_result != 0) return false;
    moxi_initialized = 1;
    return true;
}

static int moxi_decode_codepoint(const unsigned char *text, int length, int offset) {
    if (text == nullptr || offset < 0 || offset >= length) return -1;
    unsigned char first = text[offset];
    if (first < 0x80) return first;
    if ((first & 0xE0) == 0xC0 && offset + 1 < length) {
        return ((first & 0x1F) << 6) | (text[offset + 1] & 0x3F);
    }
    if ((first & 0xF0) == 0xE0 && offset + 2 < length) {
        return ((first & 0x0F) << 12)
            | ((text[offset + 1] & 0x3F) << 6)
            | (text[offset + 2] & 0x3F);
    }
    if ((first & 0xF8) == 0xF0 && offset + 3 < length) {
        return ((first & 0x07) << 18)
            | ((text[offset + 1] & 0x3F) << 12)
            | ((text[offset + 2] & 0x3F) << 6)
            | (text[offset + 3] & 0x3F);
    }
    return 0xFFFD;
}

static int moxi_cluster_to_codepoint(const char *utf8, int byte_offset) {
    if (utf8 == nullptr || byte_offset <= 0) return 0;
    const unsigned char *text = reinterpret_cast<const unsigned char *>(utf8);
    int result = 0;
    int offset = 0;
    while (offset < byte_offset && text[offset] != 0) {
        unsigned char first = text[offset];
        int width = first < 0x80 ? 1 : ((first & 0xE0) == 0xC0 ? 2 : ((first & 0xF0) == 0xE0 ? 3 : 4));
        offset += width;
        result += 1;
    }
    return result;
}

static int moxi_first_strong_direction(const char *utf8) {
    if (utf8 == nullptr) return 1;
    const unsigned char *text = reinterpret_cast<const unsigned char *>(utf8);
    int length = 0;
    while (text[length] != 0) length += 1;
    int offset = 0;
    while (offset < length) {
        int codepoint = moxi_decode_codepoint(text, length, offset);
        if ((codepoint >= 0x0590 && codepoint <= 0x08FF)
            || (codepoint >= 0xFB1D && codepoint <= 0xFEFF)) {
            return 2;
        }
        if ((codepoint >= 0x0041 && codepoint <= 0x02AF)
            || (codepoint >= 0x0370 && codepoint <= 0x058F)
            || (codepoint >= 0x0900 && codepoint <= 0xD7AF)) {
            return 1;
        }
        unsigned char first = text[offset];
        offset += first < 0x80 ? 1 : ((first & 0xE0) == 0xC0 ? 2 : ((first & 0xF0) == 0xE0 ? 3 : 4));
    }
    return 1;
}

extern "C" int moxi_harfbuzz_available(void) {
    return moxi_init_harfbuzz() ? 1 : 0;
}

extern "C" int moxi_harfbuzz_shape(const char *utf8, float font_size, int direction) {
    moxi_shaped_count = 0;
    moxi_shaped_direction = direction == 2 ? 2 : 1;
    moxi_shaped_width = 0.0f;
    moxi_shaped_height = 0.0f;
    if (!moxi_init_harfbuzz() || utf8 == nullptr) return 0;

    float size = font_size > 0.0f ? font_size : 16.0f;
    if (FT_Set_Char_Size(moxi_ft_face, 0, (FT_F26Dot6)std::lround(size * 64.0f), 72, 72) != 0) {
        return 0;
    }
    hb_font_t *font = hb_ft_font_create_referenced(moxi_ft_face);
    if (font == nullptr) return 0;
    hb_ft_font_set_load_flags(font, FT_LOAD_DEFAULT);
    hb_font_set_scale(font, (int)std::lround(size * 64.0f), (int)std::lround(size * 64.0f));

    hb_buffer_t *buffer = hb_buffer_create();
    if (buffer == nullptr) {
        hb_font_destroy(font);
        return 0;
    }
    hb_buffer_add_utf8(buffer, utf8, -1, 0, -1);
    moxi_shaped_direction = direction == 2 ? 2 : (direction == 0 ? moxi_first_strong_direction(utf8) : 1);
    hb_buffer_set_direction(
        buffer,
        moxi_shaped_direction == 2 ? HB_DIRECTION_RTL : HB_DIRECTION_LTR
    );
    hb_buffer_guess_segment_properties(buffer);
    hb_buffer_set_cluster_level(buffer, HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
    hb_shape(font, buffer, nullptr, 0);

    unsigned int count = 0;
    hb_glyph_info_t const *infos = hb_buffer_get_glyph_infos(buffer, &count);
    hb_glyph_position_t const *positions = hb_buffer_get_glyph_positions(buffer, &count);
    int text_length = (int)std::strlen(utf8);
    float cursor = 0.0f;
    for (unsigned int index = 0;
         index < count && index < MOXI_MAX_HARFBUZZ_GLYPHS;
         index++) {
        int destination = moxi_shaped_count++;
        float advance = (float)positions[index].x_advance / 64.0f;
        moxi_shaped_codepoints[destination] = moxi_decode_codepoint(
            reinterpret_cast<const unsigned char *>(utf8),
            text_length,
            (int)infos[index].cluster
        );
        moxi_shaped_glyphs[destination] = (int)infos[index].codepoint;
        moxi_shaped_clusters[destination] = moxi_cluster_to_codepoint(
            utf8,
            (int)infos[index].cluster
        );
        moxi_shaped_advances[destination] = advance;
        moxi_shaped_x[destination] = cursor + (float)positions[index].x_offset / 64.0f;
        moxi_shaped_y[destination] = (float)positions[index].y_offset / 64.0f;
        cursor += advance;
    }
    moxi_shaped_width = cursor > 0.0f ? cursor : 0.0f;
    moxi_shaped_height = (float)(moxi_ft_face->size->metrics.ascender
        - moxi_ft_face->size->metrics.descender) / 64.0f;
    if (moxi_shaped_height <= 0.0f) moxi_shaped_height = size * 1.25f;

    hb_buffer_destroy(buffer);
    hb_font_destroy(font);
    return moxi_shaped_count;
}

extern "C" int moxi_harfbuzz_direction(void) { return moxi_shaped_direction; }

extern "C" int moxi_harfbuzz_glyph_codepoint_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return -1;
    return moxi_shaped_codepoints[index];
}

extern "C" int moxi_harfbuzz_glyph_id_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0;
    return moxi_shaped_glyphs[index];
}

extern "C" int moxi_harfbuzz_glyph_cluster_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return -1;
    return moxi_shaped_clusters[index];
}

extern "C" float moxi_harfbuzz_glyph_advance_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0.0f;
    return moxi_shaped_advances[index];
}

extern "C" float moxi_harfbuzz_glyph_x_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0.0f;
    return moxi_shaped_x[index];
}

extern "C" float moxi_harfbuzz_glyph_y_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0.0f;
    return moxi_shaped_y[index];
}

extern "C" float moxi_harfbuzz_width(void) { return moxi_shaped_width; }
extern "C" float moxi_harfbuzz_height(void) { return moxi_shaped_height; }
