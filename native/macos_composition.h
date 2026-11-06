#ifndef MOXI_COMPOSITION_H
#define MOXI_COMPOSITION_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Main-thread, owner-scoped, copied RGBA8 premultiplied sRGB. No GPU handles.
 * 32 live resources process-wide, <=2048 pixels per dimension, <=16 MiB each.
 * Token is never reused. Owner must be a live F02 window. Publication serials
 * strictly increase. compose copies a retained image into that owner's slot;
 * a later publish does not change an already composed frame. A token binds
 * to one draw slot on first compose; at most two snapshots per token. Explicit
 * release clears that resource's draw references. Owner destruction retires its
 * tokens. Every operation restores the previously selected owner, including
 * failure. */
/* Experimental owner snapshot for planar probes. Exact logical dimensions,
 * RGBA8 premultiplied sRGB at 1 pixel/point; caller capacity >= w*h*4.
 * Copies actual AppKit content; does not export focus/IME/AX geometry. */
int moxi_composition_snapshot(uint64_t owner, uint8_t *rgba, size_t capacity,
                              int width, int height);
uint64_t moxi_composition_acquire(uint64_t owner);
int moxi_composition_publish(uint64_t owner, uint64_t token, uint64_t serial,
                             const uint8_t *rgba, size_t length, int width,
                             int height, int stride);
int moxi_composition_compose(uint64_t owner, uint64_t token, int slot, float x,
                             float y, float width, float height);
int moxi_composition_release(uint64_t owner, uint64_t token);
#ifdef __cplusplus
}
#endif
#endif
