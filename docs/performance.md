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

The harness runs the retained layout/reconcile/paint path, the interactive
fractal component/canvas path, the shared collection interaction scenario, the
shared plotting scenario, statistical/linked plotting, large-data plotting,
the Metal plot render packet, and the synchronized offscreen Metal scene. Each
workload runs three times by default.
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
| Interactive fractal | line-fractal expansion, one Mojo-to-native endpoint batch, GPU-instanced line expansion, CPU encoding, GPU completion, and synchronized frame time | terminal lines, expansion time, neutral paint time, Metal line segments/vertices/submissions, line-upload time, CPU encode/wait/frame time, GPU time/availability, checksum |
| Portable plot | plot scales, axes, labels, line/scatter/bar scene emission, software rasterization | commands/frame, rasterized pixels/frame, checksum |
| Metal plot packet | ordered plot batches, viewport LOD, one native transfer per batch, GPU line/instance expansion, complete chrome composition | source/emitted points, line segments, instances, packet bytes, ordered batches, GPU submissions, vertices, CPU/GPU/frame time, checksum |
| Statistical/link plot | shared typed fixture, histogram/box/heatmap/regression transforms, linked stable-key selection | derived rows, commands, selected keys, operations/frame, checksum |
| Large plot generation | 10,000-point line with extrema-preserving LOD and 100,000-point scatter with bounded representatives | source rows, rendered representatives, command counts, operations/frame |
| Collection interaction foundation | 10,000 stable-key rows, selection/navigation, reorder gesture and command, scrollbar geometry, popup state, and bounded recycler slots | rows, passes, active slots, slot pool, selected keys, reorder commands, thumb extent |
| Scatter stress | 1,000,000 source rows with a 50,000-point geometry budget and viewport-aware packet reduction | source rows, emitted commands/packet instances, packet bytes, wall-clock process time |
| Indexed plot interactions | 100,000- and 1,000,000-row hover queries, packet-cache reuse, and brush selection | cold index build, hot query time, candidates, index rebuilds, packet rebuilds, selected rows |
| Offscreen Metal | scene batching, ASCII geometry plus CoreText Unicode texture text, bounded text-texture caching, file-backed texture upload/draw, curve/arc flattening, concave/compound/self-intersecting tessellation, CPU vertex upload, synchronized completion, dynamic buffer growth | frames, vertices/frame, submissions, text glyphs, text textures, cache hits, rasterizations, images, paths, capacity, reallocations, overflow count, CPU encode/wait/frame time, GPU time/availability, checksum |

`PerformanceCounters` exposes the first two workloads' work accounting to
applications and test harnesses. `PerformanceReport` can turn counters and a
caller-provided elapsed duration into average frame time, FPS, and a 60/120 Hz
budget check. A 60 Hz frame budget is 16.67 ms; 120 Hz is 8.33 ms.

The counters are not a frame-time promise. They are the regression signal to
compare first, followed by wall-clock timing on the same machine and build.
GPU work reports CPU-side scene/vertex work and synchronized completion for the
offscreen benchmark; the visible CAMetalLayer path is measured separately
because it submits asynchronously and only waits when its three-slot ring is
exhausted.

## Fractal comparison with Xilem

The Moxi example is named `examples/interactive_fractal.mojo` and is exposed
as the `interactive-fractal-demo` task. Its counterpart is
`xilem/examples/interactive_paint.rs` in the Xilem checkout. The comparable
benchmark commands are:

```sh
pixi run fractal-benchmark
(cd ~/Git/xilem && cargo interactive-paint-bench)
```

Both use a 920x620 canvas, the same six preset families, the same 2.5-pixel
minimum segment threshold, and matching low-growth depths. Moxi reports
component expansion, neutral command generation, endpoint upload, GPU line
expansion, Metal encoding, GPU completion, and synchronized frame time
separately.
Xilem's checked-in benchmark reports CPU image rasterization, adaptive parallel
rasterization, and vector-scene construction.

These are not identical renderer backends: Xilem's live widget rasterizes a
CPU image and submits one image draw to its compositor; Moxi's interactive
canvas embeds a CAMetalLayer in the AppKit host, uploads compact endpoints,
and expands each line to a quad in one instanced GPU draw. The visible path
uses three reusable frame-buffer slots and does not wait on every submission;
the offscreen benchmark deliberately waits so its checksum and timings are
complete. AppKit remains a fallback when Metal is unavailable. Xilem's raw
raster number is therefore a line-work baseline, not a direct comparison with
Moxi's synchronized GPU frame time.

On this Apple Silicon host, a representative 25-iteration Metal run measured
the following per-frame values:

| Preset/depth | endpoint upload | CPU encode | GPU | synchronized frame |
| --- | ---: | ---: | ---: | ---: |
| Koch 5 | 0.001 ms | 0.037 ms | 0.112 ms | 0.439 ms |
| Minkowski 4 | 0.003 ms | 0.021 ms | 0.186 ms | 0.440 ms |
| Gosper 5 | 0.009 ms | 0.025 ms | 0.481 ms | 0.776 ms |
| Metro 4 | 0.003 ms | 0.105 ms | 0.193 ms | 1.107 ms |
| Switchback 4 | 0.001 ms | 0.103 ms | 0.113 ms | 0.506 ms |
| Peano 4 | 0.005 ms | 0.024 ms | 0.347 ms | 0.634 ms |

Every case used one dense instanced line submission plus two ordered regular
geometry submissions, with no buffer overflow. The endpoint-upload column
covers the Mojo-to-native copy; CPU triangle generation is now in the line
vertex shader. CPU encode includes all Metal command encoding, while
synchronized frame time also includes completion wait. Values are
machine/load dependent.

## Optimization log

- The retained runtime uses an open-addressed `(id, kind)` index so a rebuild
  does not scan every old node for every new node.
- Virtualized lists release stale slots before allocating new ones, which
  turns scrolling into bounded reuse instead of unbounded view growth.
- The Metal backend batches geometry, fast-path glyphs, and tessellated paths
  into reusable per-frame buffers and ordered submissions. Unicode text is
  rasterized through CoreText on a bounded cache miss, then reused from a
  bounded text-texture cache; the benchmark reports texture submissions,
  cache hits, and rasterizations separately so text quality and CPU cost are
  not hidden behind a batching claim. Registered image textures are flushed as
  ordered image draws, and the vertex buffer grows geometrically when a bounded
  frame exceeds the initial capacity.
- Metal blending, rounded geometry, interpolated gradients, nested scissor
  clips, and Mojo-side transform/layer state keep the GPU path aligned with the
  software scene semantics for supported commands.
- Dense component-owned canvases can embed a `CAMetalLayer` in the regular
  AppKit host through `MacOSMetalCanvasPainter`; native controls,
  accessibility, and input remain owned by the host view. Uniform fractal
  batches cross the Mojo/native boundary once, expand to line quads on the
  GPU, and use a three-slot frame ring for asynchronous presentation. The
  painter reports endpoint-upload, CPU encode/wait, GPU, completion, and
  synchronized timings.
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
  exercises one million source rows and emits at most 50,000 legacy glyphs;
  the packet path further reduces them to occupied viewport cells.
- Dense plot marks can use `PlotRenderPacket`: lines, markers, bars, and
  rectangles travel as flat contiguous records; software renders the same
  packet for parity and Metal expands it with instanced line/quad shaders.
  `pixi run plot-metal-benchmark` reports packet bytes, ordered batches,
  submissions, vertices, GPU time, and complete-frame checksum.
- Packet capacity hints are mark-aware, so a million-row scatter reserves for
  its configured viewport budget instead of allocating worst-case line and
  instance storage. The stress benchmark reports the resulting source versus
  emitted counts and packet bytes.
- Interactive PlotView runtimes retain a fixed 32-pixel screen-space index for
  hover, rectangular brush, and lasso candidate queries. The index is rebuilt
  only after a `Plot` revision or viewport change; ordinary pointer moves query
  nearby buckets instead of scanning every source row. `PlotSelection` keeps
  deterministic key order while using an internal open-addressed membership
  table, and packet mark geometry is cached separately from transient
  selection/hover overlays.
- `pixi run plot-interaction-benchmark` separates cold index construction from
  hot pointer queries and reports candidate counts, packet-cache reuse, and
  brush commit work. Its in-process timings exclude compiler startup; use the
  benchmark harness for repeated process-level measurements.

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
silently expanding memory. Portable text shaping and generic GPU-side
text/image/path tessellation remain follow-up work. The dense fractal line path
already uses GPU-side endpoint-to-quad expansion and asynchronous visible
frame pacing; its bounded three-slot ring can wait when the GPU falls behind.
The text texture count is a quality/performance signal: it identifies where a frame
used a CoreText texture instead of the allocation-free ASCII geometry path;
the cache-hit and rasterization counters distinguish reuse from new text
uploads. Visible canvas frames are asynchronous; the offscreen benchmark
remains synchronized and can wait when it needs a complete checksum.
The 1M scatter benchmark measures CPU scene generation and is not a GPU
frame-time claim. The interaction benchmark's first query includes index
construction, while subsequent queries exercise the retained grid; pan still
invalidates screen-space geometry because packets currently store pixel
coordinates. The Metal plot packet currently uses independent segment
expansion; continuous line joins/caps, filled-area tessellation, GPU text, and
text-heavy plot labels remain separate work. The iOS and Android hosts now contain SDK-facing lifecycle,
input, and accessibility source slices, and the Web Canvas demo runs in a
real browser; these are host validation artifacts rather than Mojo package
targets. Full device/browser runtime integration and platform performance
baselines remain open. See
[ARCHITECTURE.md](../ARCHITECTURE.md) and
[PROJECT-PLANNING.md](../PROJECT-PLANNING.md) for the staged roadmap.
