# Streaming fractal demo

Run `pixi run demo` and select Line fractal, or run
`pixi run interactive-fractal-demo` for the standalone Metal canvas.

Depth accepts nonnegative decimal integers of arbitrary length. The plus and
minus controls operate on the full value. There is no depth ceiling,
minimum-segment-length cutoff, or maximum leaf count. A job remains marked
Rendering until every requested leaf has been processed. Very large depths
may never produce a leaf in a practical amount of time.

The cursor yields between bounded batches of transforms. It keeps an active
segment, decimal counters, a leaf address in the generator's base, and a fixed
256-entry ancestor ring. Adjacent leaves reuse their shared path; when the
needed ancestor falls outside the ring, the cursor replays from the root.
There is no depth-sized recursion stack or list of completed leaves.
Traversal memory grows with the spelling of the depth and the logarithm of
the number of leaves visited, rather than with the numeric depth or total
output size. The fixed cache improves throughput without changing which
leaves are visited. Native hosts use a four-millisecond compute allowance per
frame, checking time between small batches rather than imposing a leaf rate.

Completed leaves accumulate in a fixed 920×620 RGBA image (2,281,600 bytes).
AppKit and Metal present bounded copies of this image. A small coarse preview
keeps editing useful before the first full-depth leaf arrives. Dragging pauses
the full traversal and rebuilds the preview; releasing resumes a new traversal.
Changing depth, a preset, geometry, or coloring discards the old job immediately.
Set depth to zero or reset the example to replace a practically endless job.

The Playground currently executes in the host process. Cooperative scheduling
and bounded output storage protect this workload; this is not an operating
system sandbox or a general guarantee for arbitrary user code. Input text and
generator size still consume memory, and finite hardware cannot accept
literally unlimited input. Geometry uses Float32 coordinates: tiny details can
collapse at high depths, and unrepresentable leaves are skipped with a float
overflow status. Neither case ends the traversal early. Presentation samples
the result at the fixed canvas resolution.

Bitmap scene commands currently render through the AppKit and Metal adapters.
The portable canvas adapter counts them as unsupported fallbacks; software
and SVG output do not include the bitmap.

`tests/fractal_numerics.mojo` checks arbitrary decimal counters, huge-depth
cancellation, independent leaf-order/geometry oracles for every preset, and
finite raster clipping. `tests/fractal.mojo` checks continuation beyond the
former leaf cap and bounded preview behavior. `pixi run bitmap-test` checks
native and Metal bitmap presentation. Historical renderer measurements in
[performance.md](performance.md) predate this streaming implementation.
