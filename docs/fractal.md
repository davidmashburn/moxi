# Streaming fractal demo

## Switch between native and web

Choose a host by running its command from the repository root. Both commands
build the demo before launching it. Each host starts its own session, so to
compare a shape interactively, select the same preset, depth and colors in both.

| Host | Command | Where the demo opens |
| --- | --- | --- |
| Native macOS | `pixi run interactive-fractal-demo` | A standalone window using Metal when available, with an AppKit fallback. Close the window to quit. |
| WebAssembly | `pixi run web-fractal-demo` | Open the [local browser demo](http://127.0.0.1:8776/experiments/fractal-web/) in a browser with memory64 support. Keep the server running while you use it. Press Ctrl-C in its terminal to stop it. |

To run them side by side, use a separate terminal for each command. The native
demo is also available under **Interactive Line Fractal** in `pixi run demo`. The web build
currently requires the [pinned Apple Silicon toolchain](#measurement-and-reproduction).

Both hosts open on Koch Curve at depth 5. To see one million colored lines,
open **Presets**, choose **Peano Serpent**, and enter **6** in the depth field. Open **Options** and enable **Random colors**.

### Where the UI lives

Edit `FractalState.build()` to change the UI on both platforms. It declares the
depth field, plus and minus buttons, guide and color checkboxes, status labels,
canvas and preset chooser. The chooser shows one family at a time. The same Mojo component handles their events
and paints the canvas. Rebuild with the command for your host and reload the
browser page after a web build. [Shared UI source](../src/moxi/fractal.mojo#L984)

| Follow an action | What Mojo owns on both platforms | What the browser host does |
| --- | --- | --- |
| Show the presets | Open Presets and choose Classic or Experimental. The active preset carries a check mark. [Preset grid](../src/moxi/fractal.mojo#L1085) | The Wasm entry builds the component and publishes its widgets. A generic adapter creates accessible HTML controls and keeps their DOM identities across updates. [Build entry](../experiments/fractal-web/browser.mojo#L247) · [DOM adapter](../native/hosts/moxi_web_view.mjs) |
| Increase the depth | The component handles a press on the plus button, increments its arbitrary-precision integer and restarts the render. [Control handler](../src/moxi/fractal.mojo#L1134) | The DOM supplies focus and keyboard or pointer activation. The host forwards the widget ID and action to the component. [Event entry](../experiments/fractal-web/browser.mojo#L260) |
| Drag a handle | The component picks the handle, edits the generator and restarts rendering during the drag. Its painter orders the preview, bitmap, guides and handles. [Drag handler](../src/moxi/fractal.mojo#L1240) · [Canvas painter](../src/moxi/fractal.mojo#L1600) | JavaScript captures the pointer, converts its position to canvas coordinates and schedules frames. The Canvas 2D adapter executes the Mojo painter's primitives and uploads the bitmap. [Frame loop](../experiments/fractal-web/demo.mjs) · [Painter bridge](../experiments/fractal-web/web_painter.mojo) |

HTML supplies a mount point and loading text. CSS and native browser controls
provide responsive layout, keyboard focus and text editing. The DOM adapter
currently supports the containers, labels, buttons, text fields, checkboxes
and canvas used here. [Page shell](../experiments/fractal-web/index.html) ·
[Host styles](../experiments/fractal-web/style.css)

To compare the shared UI declarations with the browser widget adapter in Bygone:

```sh
bygone --diff src/moxi/fractal.mojo native/hosts/moxi_web_view.mjs
```

## How rendering works

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

## Browser throughput

On an Apple M4 in Chrome 158, the renderer benchmark submitted one
million colored Peano lines in **138.5 ms**. The original JavaScript renderer
took **999.9 ms**, or **7.2× as long**. The Wasm render ranged from 134.9 to
150.0 ms across seven trials. On the small Koch curve both implementations
finished submission in 4 ms or less.

| Colored curve | Lines | Native CPU | Wasm CPU | Wasm through Canvas submission | Original JS through Canvas submission | JS time / Wasm time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Koch | 4,096 | 0.30 ms | 0.5 ms | 0.6 ms | 4.0 ms | 6.7× |
| SampleFractal | 65,536 | 4.12 ms | 6.7 ms | 6.8 ms | 71.6 ms | 10.5× |
| Peano Serpent | 1,000,000 | 68.32 ms | 138.3 ms | 138.5 ms | 999.9 ms | 7.2× |

The original iterator makes a Canvas stroke call for each line. Moxi traverses
the generator and blends each terminal line straight into a 920×620 RGBA
buffer. The benchmark submits that buffer with one `putImageData` call.
The interactive UI also composites that bitmap with the Mojo-drawn guides
and handles and updates its widgets. The table does not time those steps. Going from four thousand lines to a
million increases raster work while keeping the number of Canvas calls per
update constant. The editable generator and the bounded coarse preview stay
available during drawing. Finished line geometry can be discarded immediately.

### Cost of updating the browser controls

On the same M4, changing just the progress label in a 48-widget view produced
37 DOM mutations when the adapter reapplied every declaration. Skipping
unchanged widgets reduced that to **one mutation**. Median JS time per update
went from **0.081 ms to 0.009 ms** in headless Chrome. The focused input and
its browser-managed selection survive updates.

The following rerun includes the Mojo-to-JavaScript path. Each row updates the
same progress label in an attached DOM tree. Times are median microseconds per
update in Chrome 158 on Apple M4.

| Update path | µs |
| --- | ---: |
| JS assigns a precomputed string to a known label | 0.105 |
| JS reconciles a precomputed 48-widget snapshot | 7.5 |
| Mojo builds the view, publishes 48 widgets to JS, then JS reconciles it | 78.5 |

Run `node experiments/fractal-web/widget-benchmark.mjs` with the demo server and
Playwright environment described below. The runner rotates the order of the
three paths, discards two warmups and reports seven trials. The timed intervals
exclude browser layout, painting and line rendering. The direct assignment
assumes the caller already knows the changed element and its new text. The
difference between the last two rows includes Mojo view construction, string
decoding and snapshot allocation as well as the Wasm boundary crossing.

### Did sharing the UI change rendering speed?

The million-line Peano renderer rerun took **137.2 ms** for Moxi and **993.9 ms**
for the original JS iterator through Canvas submission. The earlier medians
were 138.5 and 999.9 ms. Both runs put the renderer advantage at about **7.2×**.
The DOM adapter is outside this timing path.

To measure what a user waits for, we also ran the old hand-written web panel
and the new shared Moxi panel with the same Wasm rendering algorithm, Peano
preset, depth 6, colors and guides. Timing starts when the benchmark clicks
Reset and ends when the page reports one million lines complete. It includes
event handling, four-millisecond work slices, frame scheduling, canvas
submissions and progress updates. It excludes startup and monitor presentation.

| Seven-trial batch | Old HTML/JS panel | Shared Moxi panel |
| --- | ---: | ---: |
| 1 | 686 ms | 752 ms |
| 2 | 751 ms | 685 ms |
| 3 | 771 ms | 902 ms |
| Median of all 21 trials per panel | 768 ms | 787 ms |

The shared panel's pooled median was 2.5% higher. Which panel finished first
varied by batch, so the data do not establish a repeatable whole-demo slowdown.
Both interactive panels use Wasm for line rendering. To reproduce, build
revision `f0e4073` in a separate checkout, start the current demo server, set
the Chrome and Playwright environment below, and run
`node experiments/fractal-web/reset-benchmark.mjs /path/to/built-checkout`.
Each invocation discards two warmups, alternates which panel runs first and
reports one batch. [Renderer, widget and interaction trials](benchmarks/fractal-shared-ui-m4.json)

### What changed during measurement

- **Web backend math.** Scalar min/max in the raster loop previously called
  JavaScript from Wasm. Lowering those operations to Wasm instructions, with
  explicit handling for NaNs and signed zero, cut paired Peano compute time
  from **772.6 to 135.7 ms**. Every pair produced identical pixels.
- **Work per call.** Increasing the batch from 64 to 2,048 transforms cut
  median Peano compute time from **141.2 to 135.7 ms**, reducing JS/Wasm calls
  from 32,987 to 1,031. The longest 2,048-transform call in a separate Peano
  profile took 0.3 ms. The UI checks its four-millisecond allowance between
  calls, presents progress during a drag, and stops requesting frames when done.
- **Reset and presentation.** Editing clears and reuses the core raster.
  The web host also reuses its `ImageData` wrapper until the buffer, offset,
  or dimensions change. A fresh copy would move 2,281,600 bytes per upload.
  Direct and copied uploads both measured **0.1 ms median** over 31 pairs at
  this browser's timer resolution. The experiment establishes the eliminated
  copy and matching canvas pixels. It does not resolve a timing advantage for
  this change alone.

### Measurement and reproduction

Measured November 25, 2026 on macOS 27.2.1, Apple M4, headless Chrome
158.0.8127.37, Mojo 1.1.0 and Moxi revision
[`abc0286`](https://github.com/davidmashburn/moxi/commit/abc0286).
Each throughput cell is the median of seven full renders after two warmups.
Browser trials alternate execution order. Native uses its default
floating-point contraction. A separate native image check disables contraction
to match scalar Wasm rounding and compares every byte on all three curves.
[Raw trials, compiler details and source hashes](benchmarks/fractal-web-m4.json).

The timed browser runs start after fixture setup and render straight through.
The submission endpoint includes traversal, coloring, rasterization or Canvas
drawing calls, and submission to Canvas. For Peano, reading back the entire
canvas brought Wasm to **142.2 ms** and the original JS to **1,046.6 ms**.
Frame scheduling, monitor presentation and interaction latency are outside
these measurements. The original uses different antialiasing, colors and
sub-pixel tests. All three implementations emitted the indicated line counts.
An optimized JS typed-array rasterizer, other browsers and mobile hardware
would need separate measurements.

The demo uses the experimental memory64 toolchain shared with the graph demo.
Building currently requires Apple Silicon, Mojo 1.1.0 (`8189361e`), Apple Clang
21.0.0 (`clang-2100.3.34.2`) and LLD 24.0.0. The browser needs WebAssembly
memory64. Run the UI from the repository root.

```sh
pixi run web-fractal-demo
```

Open [Line fractal](http://127.0.0.1:8776/experiments/fractal-web/). To reproduce
the tables, build both variants and prepare the pinned original JS and native
samples. The preparation command reads the original files directly from Git
revision `5f78b3fb3e167365d86dc21b79788bec454c16ec`.

```sh
git clone https://github.com/davidmashburn/canvas-line-fractal.git ../canvas-line-fractal
bash experiments/fractal-web/build.sh --host-math
bash experiments/fractal-web/build.sh
pixi run python experiments/fractal-web/benchmark-prepare.py ../canvas-line-fractal
```

With the demo server running, open the [benchmark page](http://127.0.0.1:8776/experiments/fractal-web/benchmark.html)
to see the samples. For a headless run, install Playwright outside the repo and
point it at Chrome. The runner serves the benchmark on its own loopback port and
writes `experiments/fractal-web/dist/benchmark/browser-result.json`.

```sh
npm install --prefix /tmp/moxi-browser-tools playwright@1.56.1 --ignore-scripts
export MOXI_PLAYWRIGHT_MODULE=/tmp/moxi-browser-tools/node_modules/playwright/index.mjs
export MOXI_CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
node experiments/fractal-web/benchmark-run.mjs
```

To verify the native/Wasm pixel oracle and runtime lifecycle, run
`bash experiments/fractal-web/check.sh` after building. With the demo server
running and the same Playwright environment, run
`node experiments/fractal-web/browser-check.mjs` to exercise controls, rendering
while a drag is held, resets, very large depths, missing-module feedback and
mobile layout.
