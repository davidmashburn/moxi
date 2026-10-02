#ifndef LAYOUT_TAFFY_H
#define LAYOUT_TAFFY_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct layout_taffy_rect {
    float x;
    float y;
    float width;
    float height;
} layout_taffy_rect;

/* Opaque handle; ownership stays with the Rust static library. */
void *layout_taffy_create(float width, float height);
int32_t layout_taffy_add_text(void *handle, const char *text, float font_size, float flex_grow);
int32_t layout_taffy_compute(void *handle, float width, float height);
int32_t layout_taffy_get_rect(void *handle, uint32_t node_index, layout_taffy_rect *out);
void layout_taffy_destroy(void *handle);

#ifdef __cplusplus
}
#endif

#endif
