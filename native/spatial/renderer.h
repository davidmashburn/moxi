#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
uint64_t ms_renderer_create(uint64_t owner, uint64_t document);
void ms_renderer_destroy(uint64_t renderer);
int ms_renderer_frame(uint64_t renderer, const void *vertices, size_t count,
                      uint64_t geometrySerial, const float *matrix, int width, int height,
                      int slot, float x, float y, float w, float h);
/* One optional planar component texture, independent of shared D07 geometry. */
int ms_renderer_panel(uint64_t renderer, const void *vertices, size_t count,
                       uint64_t source_owner, int width, int height);
uint64_t ms_renderer_metric(uint64_t renderer, int metric);
double ms_renderer_timing(uint64_t renderer, int metric);
#ifdef __cplusplus
}
#endif
