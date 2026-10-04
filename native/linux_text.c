#include "linux_text.h"

#include <limits.h>
#include <math.h>
#include <pango/pangocairo.h>
#include <string.h>

// A snapshot owns this immutable layout. Drawing never calls update_layout or
// changes its context: measurement and paint must use the same shaped lines.
typedef struct {
    gatomicrefcount references;
    PangoLayout *layout;
    PangoRectangle logical;
    float width;
    float height;
    float first_baseline;
    float last_baseline;
    int line_count;
} MoxiLinuxParagraph;

static gboolean valid_text_font(const char *text, float font_size, int direction) {
    if (text == NULL || !isfinite(font_size) || font_size <= 0 ||
        direction < 0 || direction > 2 || strlen(text) > INT_MAX ||
        !g_utf8_validate(text, -1, NULL)) return FALSE;
    // Pango font descriptions store the size in signed integer Pango units.
    return (double)font_size * PANGO_SCALE <= INT_MAX;
}

static PangoLayout *new_layout(const char *text, int length, float font_size,
                               int direction) {
    PangoFontMap *font_map = pango_cairo_font_map_get_default();
    if (font_map == NULL) return NULL;
    PangoContext *context = pango_font_map_create_context(font_map);
    if (context == NULL) return NULL;
    pango_context_set_base_dir(context, direction == 2 ? PANGO_DIRECTION_RTL
                                                     : PANGO_DIRECTION_LTR);
    pango_context_set_round_glyph_positions(context, FALSE);
    PangoLayout *layout = pango_layout_new(context);
    g_object_unref(context);
    if (layout == NULL) return NULL;
    PangoFontDescription *font = pango_font_description_new();
    pango_font_description_set_family(font, "Sans");
    // Moxi font sizes are logical canvas units, not points dependent on DPI.
    pango_font_description_set_absolute_size(font, (double)font_size * PANGO_SCALE);
    pango_layout_set_font_description(layout, font);
    pango_font_description_free(font);
    pango_layout_set_auto_dir(layout, direction == 0);
    pango_layout_set_alignment(layout, PANGO_ALIGN_LEFT);
    pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    pango_layout_set_text(layout, text, length);
    return layout;
}

static float rounded_width(int units) {
    double exact = (double)units / PANGO_SCALE;
    float result = (float)exact;
    if ((double)result < exact) result = nextafterf(result, INFINITY);
    return result;
}

static float intrinsic_width(const char *text, float font_size, int direction,
                             int query) {
    PangoLayout *layout = new_layout(text, -1, font_size, direction);
    if (layout == NULL) return NAN;
    PangoRectangle logical;
    if (query == 2) {
        // An unbounded layout's logical width is its widest hard line.
        pango_layout_get_extents(layout, NULL, &logical);
        g_object_unref(layout);
        return rounded_width(logical.width);
    }
    // The emergency-wrap profile's minimum is the widest composed cluster,
    // not the widest scalar or word. Cursor positions mark grapheme boundaries.
    int attribute_count = 0;
    const PangoLogAttr *attributes = pango_layout_get_log_attrs_readonly(
        layout, &attribute_count);
    PangoLayout *cluster = new_layout("", 0, font_size, direction);
    if (cluster == NULL) {
        g_object_unref(layout);
        return NAN;
    }
    const char *start = text;
    const char *cursor = text;
    int widest = 0;
    for (int index = 1; index < attribute_count; index++) {
        cursor = g_utf8_next_char(cursor);
        if (!attributes[index].is_cursor_position) continue;
        if (*start != '\n' && *start != '\r') {
            pango_layout_set_text(cluster, start, (int)(cursor - start));
            pango_layout_get_extents(cluster, NULL, &logical);
            widest = MAX(widest, logical.width);
        }
        start = cursor;
    }
    g_object_unref(cluster);
    g_object_unref(layout);
    return rounded_width(widest);
}

uintptr_t moxi_paragraph_create(const char *text, float font_size, float width,
                              int direction) {
    if (!valid_text_font(text, font_size, direction) || !isfinite(width) ||
        width < 0) return 0;
    PangoLayout *layout = new_layout(text, -1, font_size, direction);
    if (layout == NULL) return 0;
    // Never map zero to Pango's -1/unbounded sentinel. Offers beyond Pango's
    // integer range still retain their original width metric; the largest
    // representable wrapping limit is ample for a physical window.
    double units = ceil((double)width * PANGO_SCALE);
    pango_layout_set_width(layout, units >= INT_MAX ? INT_MAX : (int)units);
    MoxiLinuxParagraph *paragraph = g_try_new0(MoxiLinuxParagraph, 1);
    if (paragraph == NULL) {
        g_object_unref(layout);
        return 0;
    }
    g_atomic_ref_count_init(&paragraph->references);
    paragraph->layout = layout;
    paragraph->width = width;
    pango_layout_get_extents(layout, NULL, &paragraph->logical);
    paragraph->height = (float)paragraph->logical.height / PANGO_SCALE;
    paragraph->line_count = pango_layout_get_line_count(layout);
    PangoLayoutIter *iterator = pango_layout_get_iter(layout);
    paragraph->first_baseline = (float)(pango_layout_iter_get_baseline(iterator) -
                                       paragraph->logical.y) / PANGO_SCALE;
    do {
        paragraph->last_baseline = (float)(pango_layout_iter_get_baseline(iterator) -
                                          paragraph->logical.y) / PANGO_SCALE;
    } while (pango_layout_iter_next_line(iterator));
    pango_layout_iter_free(iterator);
    return (uintptr_t)paragraph;
}

uintptr_t moxi_paragraph_query(const char *text, float font_size, float width,
                             int direction, int query) {
    if (query < 0 || query > 2 || !valid_text_font(text, font_size, direction)) return 0;
    if (query != 0) width = intrinsic_width(text, font_size, direction, query);
    return moxi_paragraph_create(text, font_size, width, direction);
}

void moxi_paragraph_retain(uintptr_t handle) {
    if (handle != 0) {
        MoxiLinuxParagraph *paragraph = (MoxiLinuxParagraph *)handle;
        g_atomic_ref_count_inc(&paragraph->references);
    }
}

void moxi_paragraph_release(uintptr_t handle) {
    if (handle != 0) {
        MoxiLinuxParagraph *paragraph = (MoxiLinuxParagraph *)handle;
        if (g_atomic_ref_count_dec(&paragraph->references)) {
            g_object_unref(paragraph->layout);
            g_free(paragraph);
        }
    }
}

float moxi_paragraph_metric(uintptr_t handle, int metric) {
    if (handle == 0) return 0;
    const MoxiLinuxParagraph *paragraph = (const MoxiLinuxParagraph *)handle;
    switch (metric) {
        case 0: return paragraph->width;
        case 1: return paragraph->height;
        case 2: return paragraph->first_baseline;
        case 3: return paragraph->last_baseline;
        case 4: return (float)paragraph->line_count;
        default: return 0;
    }
}

void moxi_linux_paragraph_draw(cairo_t *cr, uintptr_t handle, float x, float y,
                               float width, float height, float r, float g,
                               float b, float a) {
    if (cr == NULL || handle == 0 || !isfinite(x) || !isfinite(y) ||
        !isfinite(width) || !isfinite(height) || width <= 0 || height <= 0 ||
        !isfinite(r) || !isfinite(g) || !isfinite(b) || !isfinite(a)) return;
    const MoxiLinuxParagraph *paragraph = (const MoxiLinuxParagraph *)handle;
    cairo_save(cr);
    cairo_rectangle(cr, x, y, width, height);
    cairo_clip(cr);
    cairo_set_source_rgba(cr, r, g, b, a);
    // Logical extents can have nonzero origins, especially for RTL layouts.
    cairo_move_to(cr, x - (double)paragraph->logical.x / PANGO_SCALE,
                  y - (double)paragraph->logical.y / PANGO_SCALE);
    pango_cairo_show_layout(cr, paragraph->layout);
    cairo_restore(cr);
}

typedef struct {
    float width, height, firstBaseline, lastBaseline;
} MoxiLayoutMetrics;

static int moxi_layout_native_measure(const char *text, float font_size, float width,
                                      int direction, int query,
                                      MoxiLayoutMetrics *metrics,
                                      uintptr_t *payload) {
    if (metrics == NULL || payload == NULL) return 1;
    *payload = 0;
    uintptr_t handle = moxi_paragraph_query(text, font_size, width, direction, query);
    if (handle == 0) return 1;
    metrics->width = moxi_paragraph_metric(handle, 0);
    metrics->height = moxi_paragraph_metric(handle, 1);
    metrics->firstBaseline = moxi_paragraph_metric(handle, 2);
    metrics->lastBaseline = moxi_paragraph_metric(handle, 3);
    *payload = handle;
    return 0;
}

uintptr_t moxi_layout_native_measure_address(void) {
    return (uintptr_t)&moxi_layout_native_measure;
}

uintptr_t moxi_layout_native_release_address(void) {
    return (uintptr_t)&moxi_paragraph_release;
}
