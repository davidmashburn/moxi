# Streaming fractal demo

Run `pixi run demo` and select Line fractal, or run
`pixi run interactive-fractal-demo` for the standalone Metal canvas.

Depth accepts nonnegative decimal integers of arbitrary length. The plus and
minus controls operate on the full value. Each branch draws its current segment
once it reaches the requested depth or measures less than one pixel on the
920×620 raster. A segment exactly one pixel long can still subdivide. Shorter
branches can finish before their neighbors. Generators whose segments stay
large can still produce arbitrarily many lines or take a long time to finish.

The cursor keeps an active segment, decimal counters, and the active path.
Consecutive levels that select the same child share one branch index and a
repeat count. A fixed 256-entry ancestor ring lets adjacent leaves reuse their
shared path. When the needed ancestor falls outside the ring, the cursor
replays from the root. Native hosts allow four milliseconds of compute per
frame, checking time between small batches of transforms.

Completed leaves accumulate in a fixed 920×620 RGBA image (2,281,600 bytes).
AppKit and Metal present bounded copies of this image. A small coarse preview
keeps editing useful before the first terminal segment arrives. Dragging pauses
the full traversal and rebuilds the preview; releasing resumes a new traversal.
Changing depth, a preset, geometry, or coloring discards the old job immediately.
Set depth to zero or reset the example to replace a practically endless job.

The Playground currently executes in the host process. Cooperative scheduling
and bounded output storage protect this workload; this is not an operating
system sandbox or a general guarantee for arbitrary user code. Input text and
generator size still consume memory, and finite hardware cannot accept
literally unlimited input. Geometry uses Float32 coordinates. Unrepresentable leaves
are skipped with a float overflow status.

Bitmap scene commands currently render through the AppKit and Metal adapters.
The portable canvas adapter counts them as unsupported fallbacks; software
and SVG output do not include the bitmap.

`tests/fractal_numerics.mojo` checks arbitrary decimal counters, huge-depth
cancellation, independent leaf-order/geometry oracles for every preset, and
finite raster clipping. `tests/fractal.mojo` checks pixel-limited completion and
bounded preview behavior. `pixi run bitmap-test` checks
native and Metal bitmap presentation. Historical renderer measurements in
[performance.md](performance.md) predate this streaming implementation.
