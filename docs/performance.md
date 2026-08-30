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
| Offscreen Metal | scene batching, GPU ASCII glyphs, file-backed texture upload/draw, polygon tessellation, CPU vertex upload, synchronized completion, dynamic buffer growth | frames, vertices/frame, submissions, text glyphs, images, paths, capacity, reallocations, overflow count, checksum |

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
- The Metal backend batches geometry, glyphs, and paths into one shared vertex
  buffer and reuses it between frames. Registered image textures are flushed
  as ordered image draws, so the benchmark reports the extra submission rather
  than hiding it behind a batching claim; the vertex buffer grows geometrically
  when a bounded frame exceeds the initial capacity.
- Metal blending, rounded geometry, interpolated gradients, nested scissor
  clips, and Mojo-side transform/layer state keep the GPU path aligned with the
  software scene semantics for supported commands.
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
gradients), printable ASCII glyphs, registered file-backed images, and simple
`M/L/H/V/Z` polygon paths. Complex Unicode glyph rasterization, arbitrary
Bezier tessellation, asynchronous frame pacing, and GPU timestamp queries
remain follow-up work.
The 1M scatter benchmark measures CPU scene generation and is not a GPU
frame-time claim. The iOS and Android host demos now compile against their
SDKs, and the Web Canvas demo runs in a real browser; these are host
validation artifacts rather than Mojo package targets. Platform GPU
timestamps, runtime integration, and device/browser performance baselines
remain open. See
[ARCHITECTURE.md](../ARCHITECTURE.md) and
[PROJECT-PLANNING.md](../PROJECT-PLANNING.md) for the staged roadmap.
