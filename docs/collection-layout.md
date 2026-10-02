# Staged collection viewport

`moxi.collection_layout` is a portable candidate module for keyed variable-height,
two-axis collections. `ExtentIndex` stores O(source-size) metadata and uses a
Fenwick index for O(log n) height updates and offset lookup. Source reorderings
preserve measured extents by key. Invalidate measurements when width, font or
content changes make them obsolete.

`CollectionViewport.stage` returns cell rectangles, clips and proposed mount IDs.
It does not activate slots or fire lifecycle effects. Publish the corresponding
global geometry first, then `commit(plan^)`; discard the plan on failure. Source,
pin or committed-generation changes reject stale plans. Treat plans as runtime
output, not editable declarations. Ordinary scrolling reuses overlapping mounts.

Frozen rows/columns paint after scrolling cells. Their clips exclude the frozen
area from scrolling cells, and RTL mirrors columns once. Frozen tracks beyond the
viewport do not realize the whole source. Realization depends on visible extents,
explicit overscan and at most four pinned editor rows; metadata still scales with
the dataset. Zero-sized tracks do not create visible cells.

Capture `anchor` before insertion or reordering and `restore` afterward.
`measure_row` performs this correction for height changes. Logical focus survives
scrolling; `focus` reveals an offscreen keyed row. Pins retain editor mounts while
offscreen; the component must retain its actual text, selection and composition.
This module does not itself create native editors or implement accessibility row
navigation. Those integration gates remain separate.

`tests/collection_layout.mojo` covers 100,000 variable rows, bounded realization,
mount reuse, frozen tracks, RTL, anchor correction, offscreen focus, editor pin
limits, stale-plan rejection and atomic source validation.
