#ifndef MOXI_LINUX_TEXT_H
#define MOXI_LINUX_TEXT_H

#include <stdint.h>
#include <cairo.h>

#ifdef __cplusplus
extern "C" {
#endif

// The same paragraph ABI as macos_text.m. Direction: natural=0, LTR=1,
// RTL=2. Query: finite offer=0, min-content grapheme=1, max-content line=2.
uintptr_t moxi_paragraph_create(const char *text, float font_size, float width,
                              int direction);
uintptr_t moxi_paragraph_query(const char *text, float font_size, float width,
                             int direction, int query);
void moxi_paragraph_retain(uintptr_t handle);
void moxi_paragraph_release(uintptr_t handle);
// Metrics: offered width, height, first baseline, last baseline, line count.
float moxi_paragraph_metric(uintptr_t handle, int metric);
uintptr_t moxi_layout_native_measure_address(void);
uintptr_t moxi_layout_native_release_address(void);

// Internal presenter helper: paints the immutable measured payload without
// reflowing it, and intersects the caller's clip with the committed box.
void moxi_linux_paragraph_draw(cairo_t *cr, uintptr_t handle, float x, float y,
                               float width, float height, float r, float g,
                               float b, float a);

#ifdef __cplusplus
}
#endif

#endif
