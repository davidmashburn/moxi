#ifndef MOXI_RETAINED_LAYOUT_H
#define MOXI_RETAINED_LAYOUT_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// Thread-confined opaque owners. Release once; never forge or reuse a handle.
typedef struct MoxiLayout MoxiLayout;
typedef struct MoxiLayoutSnapshot MoxiLayoutSnapshot;
typedef struct MoxiLayoutCandidate MoxiLayoutCandidate;
typedef struct { uint64_t key; float x, y, width, height; } MoxiLayoutPlacement;
typedef struct { float width, height, first_baseline, last_baseline; } MoxiLayoutMetrics;
typedef int32_t (*MoxiLayoutMeasure)(const char *, float, float, int32_t, int32_t,
                                   MoxiLayoutMetrics *, uintptr_t *);
typedef void (*MoxiLayoutRelease)(uintptr_t);
typedef struct {
    int32_t kind, width_kind, height_kind;
    float width, height, min_width, min_height, max_width, max_height;
    float gap, padding, grow, shrink;
    int32_t align, rtl, overflow, column, column_span, row, row_span;
} MoxiLayoutSpec;
typedef struct { int32_t min_kind, max_kind; float min, max; } MoxiLayoutTrack;
MoxiLayout *moxi_layout_create(MoxiLayoutMeasure, MoxiLayoutRelease);
void moxi_layout_destroy(MoxiLayout *);
const char *moxi_layout_error(const MoxiLayout *); // borrowed until next operation
int32_t moxi_layout_set_node(MoxiLayout *, uint64_t, const MoxiLayoutSpec *, const char *, float, int32_t);
int32_t moxi_layout_set_region(MoxiLayout *, uint64_t, const MoxiLayoutSpec *);
int32_t moxi_layout_children(MoxiLayout *, uint64_t, const uint64_t *, size_t);
int32_t moxi_layout_tracks(MoxiLayout *, uint64_t, int32_t, const MoxiLayoutTrack *, size_t);
int32_t moxi_layout_hidden(MoxiLayout *, uint64_t, int32_t);
int32_t moxi_layout_remove(MoxiLayout *, uint64_t);
int32_t moxi_layout_has_key(const MoxiLayout *, uint64_t);
int32_t moxi_layout_invalidate(MoxiLayout *);
int32_t moxi_layout_compute(MoxiLayout *, uint64_t, float, float, MoxiLayoutSnapshot **);
// Stage never publishes; commit rejects stale/foreign candidates and borrows it.
int32_t moxi_layout_stage(MoxiLayout *, uint64_t, float, float, MoxiLayoutCandidate **);
int32_t moxi_layout_commit(MoxiLayout *, const MoxiLayoutCandidate *, MoxiLayoutSnapshot **);
MoxiLayoutSnapshot *moxi_layout_candidate_snapshot(const MoxiLayoutCandidate *);
void moxi_layout_candidate_release(MoxiLayoutCandidate *);
int32_t moxi_layout_place(MoxiLayout *, const MoxiLayoutPlacement *, size_t);
int32_t moxi_layout_clear_placement(MoxiLayout *, uint64_t);
MoxiLayoutSnapshot *moxi_layout_snapshot(const MoxiLayout *);
void moxi_layout_snapshot_release(MoxiLayoutSnapshot *);
size_t moxi_layout_snapshot_count(const MoxiLayoutSnapshot *);
uint64_t moxi_layout_snapshot_generation(const MoxiLayoutSnapshot *);
// Integer fields: key, mount, parent, hidden, borrowed native paragraph handle.
uint64_t moxi_layout_snapshot_integer(const MoxiLayoutSnapshot *, size_t, int32_t);
// Float fields: rect[4], clip[4], first baseline, last baseline.
float moxi_layout_snapshot_float(const MoxiLayoutSnapshot *, size_t, size_t);
// Counter fields: measurements, declaration mutations, publications.
uint64_t moxi_layout_counter(const MoxiLayout *, int32_t);
#ifdef __cplusplus
}
static_assert(sizeof(MoxiLayoutSpec) == 80, "layout style ABI");
static_assert(sizeof(MoxiLayoutMetrics) == 16, "layout metrics ABI");
#else
_Static_assert(sizeof(MoxiLayoutSpec) == 80, "layout style ABI");
_Static_assert(sizeof(MoxiLayoutMetrics) == 16, "layout metrics ABI");
#endif
#endif
