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
keeps editing useful before the first terminal segment arrives. Each drag movement
refreshes the preview and restarts rendering for the new geometry. Frame ticks
continue refining the curve while the pointer is held and after release.
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

## When does native rendering pay off?

On an Apple M4, Moxi drew one million individually colored Peano Serpent lines
in **76.6 ms**. The original JavaScript demo took **997 ms** to submit the same
number of strokes to Canvas 2D. That gives Moxi **13.0× the throughput** on this
curve, or about **13 million lines per second**.

| Curve | Depth | Lines drawn | Moxi raster (ms) | JS submit (ms) | JS through readback (ms) | Throughput vs. JS submit |
|---|---:|---:|---:|---:|---:|---:|
| Koch | 6 | 4,096 | 0.215 | 3.90 | 7.70 | 18.1× |
| SampleFractal | 16 | 65,536 | 4.56 | 71.4 | 92.3 | 15.7× |
| Peano Serpent | 6 | 1,000,000 | 76.6 | 997 | 1,019 | 13.0× |

This workload rewards a renderer that can consume each short line immediately.
The original recursively yields each leaf, constructs a CSS color, and saves,
strokes, and restores a Canvas 2D context for that line. Moxi hashes the
endpoint coordinates into RGB and blends directly into one reusable raster
with a compile-time loop over the three color channels. A million leaves need
the same 2.28 MB output image as four thousand. The host can present that image
once per frame. [Original stroke and traversal routines](https://github.com/davidmashburn/canvas-line-fractal/blob/5f78b3fb3e167365d86dc21b79788bec454c16ec/drawFractal.js#L11-L53).

At 4,096 lines, the absolute saving is under 4 ms and both renderers submit or
finish within a 60 Hz frame interval. At a million lines, even Moxi needs
multiple frames to show the whole curve interactively. The demo splits that
work into short batches so dragging can restart the render.

In a separate before-and-after run on the same machine, the million-line
colored Moxi render went from 122.0 to 68.5 ms. The default single-color
render went from 84.4 to 66.2 ms and produced matching raster checksums on
all three curves. Random-color mode now assigns different hues to individual
segments. Rendering the same geometry again reproduces those colors.

### Method and limits

Measured on November 25, 2026 with an Apple M4, macOS 27.2.1, Mojo 1.1.0
(`8189361e`), headless Chrome 158.0.8127.37, and Moxi revision
[`381d917`](https://github.com/davidmashburn/moxi/commit/381d917).
Each cell is the median of seven full renders after two warmups per curve and
renderer. Million-line Moxi samples ranged from 68.6 to 93.8 ms.
[Individual timing samples](benchmarks/fractal-throughput-m4.csv).

Both paths draw colored terminal segments on a fresh 920×620 raster. The
harness passes Moxi's normalized generator coordinates to the original
JavaScript traversal and checks every run's leaf count. The two renderers use
different color sequences, antialiasing and sub-pixel distance tests. These
fixtures reach the same leaf counts under both stopping rules.

Timing starts after setup. Moxi stops when the CPU raster is complete.
**JS submit** stops immediately after the last Canvas stroke call returns.
**JS through readback** also waits for the browser to return the full RGBA
image. The speedup uses the earlier JS endpoint. Frame scheduling, Metal
upload, screen presentation, and input latency are outside these timings.
The measurements compare two implementations. A JavaScript renderer that
batches paths or writes directly to a typed pixel buffer would need its own
benchmark.

### Reproduce on macOS

From the Moxi checkout with Pixi and Google Chrome installed, run the commands
below. The runner reads the original renderer at the pinned Git revision,
compiles the native benchmark, runs both sequentially, and prints seven timing
samples per renderer per curve as JSON lines. Use `--chrome PATH` for another
Chrome executable.

```sh
git clone https://github.com/davidmashburn/canvas-line-fractal.git ../canvas-line-fractal
pixi run python scripts/fractal_throughput.py ../canvas-line-fractal
```

For host encoding and Metal presentation timings, run `pixi run fractal-benchmark`.
