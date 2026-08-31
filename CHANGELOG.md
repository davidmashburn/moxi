# Changelog

## Unreleased — post-0.5 experimental slices

- Moved the interactive fractal canvas onto the macOS Metal geometry path. The
  regular AppKit host still owns controls, input, and accessibility, while an
  embedded `CAMetalLayer` handles the dense canvas; the fallback remains
  available when Metal cannot attach.
- Added a single endpoint upload for uniform fractal batches and GPU-side
  instanced line-quad expansion. The visible canvas now uses a three-slot
  asynchronous frame ring, while offscreen benchmarks retain synchronized
  completion for checksums and comparable timings.
- Extended the fractal benchmark to report endpoint upload, Metal encoding,
  GPU completion, synchronized frame time, line segments, vertices, draw
  submissions, and in-flight/completed frame counts separately.
- Hardened the macOS Metal scene renderer with reusable/growing per-frame
  buffers, ordered submissions, alpha blending, rounded rectangles,
  interpolated gradients, nested clips, transform/layer state, and observable
  submission/capacity/reallocation/fallback counters.
- Added usable iOS, Android, and Web host bridges for normalized touch/pointer,
  key, text/IME, and resize events, deterministic software fallback checksums,
  and Web SVG frame export. Added an SDK-built iOS simulator app, an Android
  API-35 debug APK, and a real browser Canvas host demo; Mojo package runtime
  integration and platform accessibility remain gated.
- Added shared typed plotting fixtures, statistical/linked plotting benchmarks,
  zero-copy key-selection views, recipe-aware spec validation, and a statistical
  visual reference. The gallery now exercises histogram, box, heatmap, and
  regression recipes alongside lasso-enabled interactions.
- Added repeatable retained, plotting, dense-plot, and offscreen-Metal
  benchmarks with deterministic work counters, checksums, and 60/120 Hz budget
  reporting guidance.
- Added portable cluster-aware approximate shaping metadata and a CoreText
  adapter that retains native glyph ids, clusters, bidi direction, advances,
  and fallback information at the shaped-run boundary.
- Added an optional HarfBuzz/FreeType/Fontconfig shaping adapter with real
  OpenType substitution/positioning, UTF-8 cluster mapping, auto direction,
  and a reproducible linked smoke demo.
- Added stable-key fixed-extent `VirtualRecycler` and `VirtualizedList`
  builders with overscan, bounded slot ownership, clamped offsets, and
  ensure-visible behavior, plus localized execution dependency accounting.
- Added shared lifecycle and scale-factor contracts for iOS, Android, and Web;
  native host artifacts now have reproducible local build targets, while SVG
  provides the deterministic Web-compatible scene export.
- Expanded Moxi Plot into an executable typed 2D foundation: Float32/Float64,
  integer/Boolean/string/category/timestamp/duration fields, stable-key
  snapshots and views, field encodings, second channels, per-row styling,
  categorical labels, core mark recipes, facets, deterministic dataflow
  transforms, scale metadata, annotations, interaction tools, PlotView/
  PlotControl, CSV fallback, SVG paths/opacity, and bounded scatter LOD.
- Added a typed plot gallery plus 100k and 1M-row stress benchmarks that keep
  source rows for interaction while bounding emitted geometry.
- Added an optional `PlotRenderPacket` fast path for dense lines, markers,
  bars, and rectangles. Packets keep ordered flat buffers and source-row
  semantics, render through the software oracle, and use instanced Metal
  expansion with viewport-aware line/scatter reduction.
- Added a repeatable `plot-metal-benchmark` workload covering packet bytes,
  ordered submissions, GPU vertices/timing, complete-frame composition, and
  checksum parity.
- Made packet capacity planning mark-aware so dense scatter builds reserve for
  the viewport budget rather than worst-case source-row expansion.

## 0.5.0 — 2026-08-30

- Added a deterministic in-process capability bus with manifests, side-effect
  policy, exact bus-issued agent approvals, bounded FIFO backpressure, typed
  handler execution, idempotent replay, and exclusive leases.
- Added stack, grid, split-pane, and clipped portal containers with persistent
  scroll offsets, fixed-extent visible-range math, and clipping-aware routing.
- Added a backend-neutral scene/resource seam with deterministic software
  raster checks for shapes, gradients, layers, transforms, and declared path
  bounds.
- Added slider, switch, radio, image, multiline, combo, list, table, tree,
  menu, dialog, tabs, canvas, and separator descriptors plus portable state
  models and theme coverage.
- Added catalog accessibility roles and semantic actions, native AppKit AX
  action routing, WindowConfig size/resizability/fullscreen plumbing, and
  native image/resource presentation.
- Added checkbox and determinate progress controls across view, runtime, paint,
  accessibility, headless tests, and native AppKit rendering.
- Added text-layout requests, rich-text span data, explicit fallback reporting,
  and backend capability profiles for headless/AppKit/GPU/Windows/Linux.
- Expanded the wxPython-style showcase to exercise every shipped control,
  typed component slots, clipping, wrapped text, capabilities, and backend
  reporting.
- Added opt-in deterministic codepoint wrapping, intrinsic-height propagation,
  a shared wrapped-text scenario, and a native resize-aware demo.
- Added typed component slots, namespaced child ids, projected local views, and
  stable action ids for parent-to-child event routing.
- Added opt-in root/container clipping metadata with native AppKit clip-state
  handling.
- Added an optional incremental renderer contract for changed commands and
  removed-region clearing, with headless coverage.
- Added alignment and nested-container layouts, clipboard/IME input, focus
  navigation, constraints, validation, and retained identity reconciliation.
- Stabilized the minimal declarative component, layout, event, rendering, and
  native-window contracts for a focused macOS UI core.
- Included retained identity reconciliation, constraints, validation,
  accessibility, Unicode text editing, IME composition, clipboard support,
  deterministic animation, invalidation, headless backends, and package
  consumer coverage in the 0.5 boundary.
- Added canonical `App.run()` and `App.run_with_clipboard()` loops plus
  executable examples for the public lifecycle.
- Added a fail-fast test runner, strict native warning checks, package-consumer
  validation, release-check task, public API inventory, benchmark scaffold, and
  source-controlled wx-style visual references.

## 0.4.0 — Complete in tree

- Added a backend-neutral `Event` model for pointer, key, text, and resize
  input.
- Added focusable view nodes, stable focus across rebuilds, and Tab traversal.
- Added editable single-line text input with cursor movement and deletion.
- Added focused button/text-input paint state and native focus rings.
- Added native AppKit key, text, pointer, and resize event translation.
- Added the shared form scenario, demo, and interaction contract tests.
- Added reusable label, button, and text-input control descriptors.
- Added Unicode-safe text selection, replacement, and cursor editing state.
- Added visible native text selection and portable copy/cut/paste commands.
- Added backend-neutral accessibility roles, labels, values, hints, and state.
- Added pointer down/move/up routing with hover, pressed, enabled, and click
  state.
- Added `RowLayout`, flexible slots, spacers, and the interactive row scenario.
- Added headless `TestRenderer` and `TestWindow` integration contracts.
- Added a clean-cache distributable package consumer check.

## 0.3.0 — 2026-08-28

- Added composable `ViewNode` leaves and `ColumnView` composition.
- Added deterministic vertical layout with padding and spacing.
- Added retained `ColumnRuntime` reconciliation and ordered `PaintCommands`.
- Added computed-bound hit-testing and layout/paint contract coverage.
- Added the value-based `Component` contract and component lifecycle coverage.
- Added `App` for component mount, update, resize, rebuild, and render flow.
- Added backend-neutral `Color`, `Style`, `Panel`, surface, and leaf styling.
- Added resize-aware root bounds and a resizable native macOS window.
- Updated the native macOS renderer to draw multiple labels and buttons per
  frame.
- Reworked the counter demo to use the composed view and command stream.
- Added a minimal component example and expanded the architecture guide.
- Added current architecture documentation and labeled the long-term spec as
  design notes.

## 0.2.0 — 2026-08-27

- Added `CounterState`, `CounterView`, and retained counter widgets.
- Added primary-pointer click events, rectangle hit-testing, and a bounded
  native event pump.
- Added a native macOS counter button and `examples/counter.mojo`.
- Added state/update contract coverage in `tests/counter.mojo`.

## 0.1.1 — 2026-08-27

- Added Pixi package-build metadata through `pixi-build-mojo`, so Moxi can be
  consumed as a Pixi-built Mojo package.

## 0.1.0 — 2026-08-27

Initial experimental preview.

- Added the `moxi` Mojo package and Pixi-pinned development workflow.
- Added declarative labels, retained runtime state, and paint commands.
- Added backend-neutral renderer and window contracts.
- Added a native macOS AppKit window and canvas renderer.
- Added a visible `Hello from Moxi` example and core smoke test.

Known limitations are documented in [README.md](README.md).
