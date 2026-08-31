# Performance and benchmark policy

Moxi treats performance as part of the UI contract. The benchmark suite makes
the amount of work visible in deterministic counters and records host timing
separately. This keeps comparisons useful across Mojo/compiler and GPU-driver
changes without pretending that a single machine's wall-clock result is a
portable guarantee.

## Run the suite

```sh
pixi run benchmark
```

The harness runs the retained layout/reconcile/paint path, the shared plotting
scenario, statistical/linked plotting, large-data plotting, and the
synchronized offscreen Metal scene. Each workload runs three times by default.
Use one run for a quick local check or choose another count:

```sh
MOXI_BENCHMARK_RUNS=1 pixi run benchmark
MOXI_BENCHMARK_RUNS=10 pixi run benchmark
```

Each Mojo benchmark prints deterministic counters such as scene commands,
vertices, rasterized pixels, and a checksum. `/usr/bin/time -p` prints `real`,
`user`, and `sys` for the host process around each run. The process timing
includes runtime startup and, for the portable cases, compilation/loading;
the Metal binary is compiled once before its measured runs.

## Workloads and budgets

| Workload | What it exercises | Stable signals |
| --- | --- | --- |
| Retained pipeline | layout, identity reconciliation, paint, scene conversion, fixed/variable-extent range math | passes, child count, paint commands, checksum, operations/frame |
| Portable plot | plot scales, axes, labels, line/scatter/bar scene emission, software rasterization | commands/frame, rasterized pixels/frame, checksum |
| Statistical/link plot | shared typed fixture, histogram/box/heatmap/regression transforms, linked stable-key selection | derived rows, commands, selected keys, operations/frame, checksum |
| Large plot generation | 10,000-point line with extrema-preserving LOD and 100,000-point scatter with bounded representatives | source rows, rendered representatives, command counts, operations/frame |
| Scatter stress | 1,000,000 source rows with a 50,000-point geometry budget | source rows, emitted commands, wall-clock process time |
| Offscreen Metal | scene batching, ASCII geometry plus CoreText Unicode texture text, bounded text-texture caching, file-backed texture upload/draw, curve/arc flattening, concave/compound/self-intersecting tessellation, CPU vertex upload, synchronized completion, dynamic buffer growth | frames, vertices/frame, submissions, text glyphs, text textures, cache hits, rasterizations, images, paths, capacity, reallocations, overflow count, CPU encode/wait/frame time, GPU time/availability, checksum |

`PerformanceCounters` exposes the first two workloads' work accounting to
applications and test harnesses. `PerformanceReport` can turn counters and a
caller-provided elapsed duration into average frame time, FPS, and a 60/120 Hz
budget check. A 60 Hz frame budget is 16.67 ms; 120 Hz is 8.33 ms.

The counters are not a frame-time promise. They are the regression signal to
compare first, followed by wall-clock timing on the same machine and build.
GPU work must report both CPU-side scene/vertex work and synchronized GPU
completion until an asynchronous presentation path exists.

## Optimization log

- The retained runtime uses an open-addressed `(id, kind)` index so a rebuild
  does not scan every old node for every new node.
- Virtualized lists release stale slots before allocating new ones, which
  turns scrolling into bounded reuse instead of unbounded view growth.
- The Metal backend batches geometry, fast-path glyphs, and tessellated paths
  into one shared vertex buffer and reuses it between frames. Unicode text is
  rasterized through CoreText on a bounded cache miss, then reused from a
  bounded text-texture cache; the benchmark reports texture submissions,
  cache hits, and rasterizations separately so text quality and CPU cost are
  not hidden behind a batching claim. Registered image textures are flushed as
  ordered image draws, and the vertex buffer grows geometrically when a bounded
  frame exceeds the initial capacity.
- Metal blending, rounded geometry, interpolated gradients, nested scissor
  clips, and Mojo-side transform/layer state keep the GPU path aligned with the
  software scene semantics for supported commands.
- Compound subpaths, holes, and self-intersections use a bounded even-odd
  scanline tessellator after the fast simple-polygon path. The renderer reports
  synchronized CPU encode time, CPU wait time, total frame time, and Metal
  command-buffer GPU timestamps when the driver exposes them.
- Dense line plots can opt into extrema-preserving pixel-level reduction with
  `Plot.set_line_point_limit()`; the large benchmark keeps the 10,000-point
  source data but bounds emitted line geometry to 2,048 points.
- Dense scatter plots can opt into deterministic representative sampling with
  `Plot.set_scatter_point_limit()`; the source table and stable row keys remain
  intact for hit testing and accessibility. `pixi run plot-stress-benchmark`
  exercises one million source rows and emits at most 50,000 glyphs.

When changing a hot path, add or update a deterministic counter, run the same
scenario before and after, and record the reason for the change in the commit
message. Do not optimize the plot or demo by changing its data shape: the
shared scenario is also a component and documentation contract.

## Current limits

The GPU slice renders basic geometry (including rounded rectangles and linear
gradients), printable ASCII glyphs, CoreText Unicode text textures,
registered file-backed images, quadratic/cubic Bezier paths, elliptical arcs,
concave polygons, compound paths with holes, and self-intersecting fills.
Compound fills currently use an explicit even-odd rule and bounded scanline
tessellation; extremely large or malformed paths are rejected rather than
silently expanding memory. Asynchronous frame pacing, portable text shaping,
and GPU-side text/image/path tessellation remain follow-up work. The text
texture count is a quality/performance signal: it identifies where a frame
used a CoreText texture instead of the allocation-free ASCII geometry path;
the cache-hit and rasterization counters distinguish reuse from new text
uploads.
The 1M scatter benchmark measures CPU scene generation and is not a GPU
frame-time claim. The iOS and Android hosts now contain SDK-facing lifecycle,
input, and accessibility source slices, and the Web Canvas demo runs in a
real browser; these are host validation artifacts rather than Mojo package
targets. Full device/browser runtime integration and platform performance
baselines remain open. See
[ARCHITECTURE.md](../ARCHITECTURE.md) and
[PROJECT-PLANNING.md](../PROJECT-PLANNING.md) for the staged roadmap.
