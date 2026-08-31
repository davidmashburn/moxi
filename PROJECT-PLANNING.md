# Moxi Project Plan

This branch is the planning record for the work after the 0.5 preview. The
implementation worktree may remain dirty while these slices are developed;
existing changes are user-owned and must not be rewritten or silently folded
into a planning commit.

## Direction after 0.5

Moxi is a Mojo UI library with a retained view/runtime model, explicit backend
boundaries, deterministic headless rendering, native macOS presentation, a
capability bus, component state, accessibility semantics, and a broad control
catalog. The next phase is about making those contracts production-worthy,
starting with the rendering and performance path and then using it to build a
first-class plotting library.

The remaining explicitly deferred post-0.5 work is now narrower:

- A production portable font-fallback chain beyond the new optional HarfBuzz
  adapter; the adapter now supplies OpenType shaping/positioning and stable
  clusters through a host-selected Unicode font, while custom collections,
  fallback chains, and full paragraph bidi remain host policy.
- Scrollbar widgets and viewport policy around the implemented variable-height
  recycler.
- Deep native widgets and platform-native interaction/accessibility fidelity;
  the macOS slice now carries explicit checked/expanded/range semantics,
  richer AX attributes/notifications, nested hit testing, deeper
  collection-widget affordances, and an AppKit field-editor overlay for
  focused single-line inputs. Web ARIA plus iOS/Android virtual accessibility
  host bridges are present; editable collection cells, menu/dialog tracking,
  and live Mojo-runtime publication remain open.
- Native iOS, Android, and browser app targets with device/emulator/browser CI;
  host lifecycle/input shims now live under `native/hosts/`, with local iOS,
  Android, and browser demo artifacts checked by `scripts/host_check.sh`.
- Complex GPU typography, asynchronous frame pacing, and portable
  cross-platform resource loaders; Metal now covers printable ASCII glyphs,
  CoreText Unicode text textures, registered file-backed images,
  quadratic/cubic curves, elliptical arcs, concave polygons, and bounded
  even-odd compound/self-intersecting fills, with optional GPU timestamps.
- Localized component execution and dependency-scoped invalidation beyond the
  current accounting contract.

Performance is a release requirement, not a later optimization pass. Mojo is
being used for predictable, low-overhead UI work, so every renderer/runtime
slice must have a repeatable benchmark, a stated workload, and a recorded
reason for any tradeoff.

## Latest implementation slice

The current macOS pass closes two previously visible quality gaps. Metal keeps
the allocation-free ASCII geometry path for short labels, uses CoreText-backed
Unicode textures with a bounded persistent text cache for fallback glyphs,
flattens quadratic/cubic/arc paths, ear-clips concave simple polygons, and
scanline-tessellates bounded compound/self-intersecting paths with even-odd
fill semantics. Its benchmark reports synchronized CPU and optional GPU
timings.
Accessibility now transports
explicit toggle/disclosure state and numeric ranges through reconciliation,
paint, the native registry, and AppKit; the native presenter uses those same
states for list/table/tree/menu/dialog/tab/canvas affordances. The offscreen
Metal benchmark records Unicode texture draws, cache hits, and rasterizations
separately from geometry and continues to report vertices, submissions, paths,
fallbacks, and checksums.

Remaining renderer limits are asynchronous pacing, portable shaping/font
fallback, and platform-specific GPU text/image/path tessellation. Remaining
native limits are editable collection cells, system menu/dialog tracking,
live Mojo-runtime publication on iOS/Android/Web, and device-level
screen-reader automation.

The first product built on these contracts is a first-class plotting library:
a supported interactive 2D visualization system with portable data, declarative
scene generation, GPU/native presentation, and a path to advanced domains.

## Core contract decisions

1. `View` remains declarative and platform-independent. It owns no native
   handles and is safe to rebuild.
2. Retained runtime state, component state, capability calls, and platform
   handles have explicit ownership boundaries. A callback or native handle
   does not cross a serialization or capability boundary implicitly.
3. A backend advertises what it actually supports. iOS, Android, and Web are
   named targets in the capability matrix even when the Mojo runtime is not
   linked; host artifacts must report their real status rather than masquerade
   as macOS or headless.
4. Scene commands are the portable rendering contract. Software rendering is
   the deterministic oracle; GPU renderers consume the same scene/resources
   where practical and may expose a documented capability-specific extension.
5. Text shaping is an adapter boundary. The fallback estimator remains useful
   for headless tests, but user-visible text must identify whether shaping,
   bidi, font fallback, and glyph rasterization are real on that backend.
6. Examples, tests, and benchmarks consume shared scenarios and data fixtures.
   A demo is a contract test, not a hand-built mirror of the API.

## Shared scenarios and references

The initial shared scenario set should live beside the library (planned
`src/moxi/scenarios.mojo` or a small `scenarios/` package) and be consumed by
tests, examples, benchmarks, and reference screenshots:

- A compact form and wxPython-style control tree.
- A long scrolling list with stable item identity and changing data.
- A mixed text scene containing wrapping, bidi, and editable text cases.
- A plotting fixture suite covering time series, linked scatter/histogram,
  categorical bars, streaming telemetry, heatmaps, and function sampling.
- A 10,000-node stress tree for reconciliation/layout/paint measurements.

Where parity matters, compare against the real platform/reference behavior
(AppKit, UIKit, Android Views/Compose, and browser Canvas/SVG/accessibility
semantics) instead of maintaining a static imitation. Static SVGs and
headless scenes are useful documentation, not behavioral oracles.

## Performance policy

Every renderer/runtime change must update the benchmark story:

- Measure repeated runs, not a single timing; report workload size, pass count,
  checksum/validation signal, compiler/runtime version, and hardware notes.
- Keep quick benchmarks suitable for `pixi run check` and a fuller benchmark
  suitable for release/pre-submit runs.
- Cover at least reconcile, layout, paint/scene generation, software rendering,
  virtualized scrolling, GPU command encoding, buffer growth, submission, and
  synchronized completion. Record native GPU timestamps where the driver
  exposes them and keep CPU encode/wait/frame timings alongside them.
- Compare 100-, 1,000-, and 10,000-node workloads where the stage supports it;
  track allocations or command counts when wall-clock allocation data is not
  portable.
- Treat a 60 Hz frame as a 16.67 ms budget and a 120 Hz frame as an 8.33 ms
  budget. State whether a result is CPU-only, GPU-inclusive, or a cold start.
- Optimize only after a baseline exists. Prefer stable identity, bounded work,
  batching, dirty-region/dirty-component scopes, resource reuse, and fewer
  allocations over speculative micro-optimizations.
- Plot benchmarks must cover 10,000-point lines, 100,000-point scatter,
  million-point scatter with level-of-detail, faceted views, linked views,
  dense heatmaps, streaming updates, and repeated pan/zoom/selection.

The benchmark command and methodology belong in the repository, and release
notes should include the result artifact or a concise comparison table. A
regression should block a release when it breaks a stated budget or materially
increases work for a shared scenario.

## Backend and platform scope

Target the platforms in this order, while keeping the common contract usable:

| Target | First backend shape | Initial native surface | Current status |
| --- | --- | --- | --- |
| macOS | AppKit window + scene/software path; Metal target | windows, input, AX, text bridge | baseline shipped; hardened basic Metal slice |
| iOS | UIKit/Metal surface adapter | app/window lifecycle, touch, safe areas, virtual AX | simulator source target plus virtual `UIAccessibilityElement` bridge; Mojo runtime/device CI pending |
| Android | Android surface/input/accessibility adapter | lifecycle, touch, IME, density, virtual AX | NDK action bridge plus `AccessibilityNodeProvider`; APK/JDK validation pending on hosts without Java |
| Web | browser host + Canvas/WebGPU target | DOM focus/ARIA bridge, pointer/touch, resize | browser host plus pure ARIA mapping tests; packaged WASM target pending |

The first cross-platform milestone is not “all widgets everywhere.” It is a
portable surface/window lifecycle, event vocabulary, scale-factor contract,
resource lifetime policy, accessibility mapping, and deterministic fallback.
The native adapters can then fill the matrix explicitly and share scene,
layout, component, capability, and plotting code.

## Milestones

### 0.6 — GPU-ready rendering and measurable performance (macOS slice complete)

- Stabilize scene/resource ownership and renderer capability contracts.
- Implement a Metal-backed macOS renderer consuming scene commands, with the
  software renderer retained as an oracle/fallback. The current slice covers
  rectangles, rounded rectangles, lines, gradients, clips, transforms, layer
  opacity, printable ASCII glyphs, CoreText Unicode text textures, registered
  file-backed images, quadratic/cubic curves, elliptical arcs, concave simple
  polygons, and bounded even-odd compound/self-intersecting paths.
- Add GPU resource lifetime, resize, scale-factor, clipping, transform, and
  readback/checksum test seams.
- Add repeatable CPU and GPU benchmark cases and use evidence to improve hot
  paths (batching, command storage, invalidation, and resource reuse).
- Route dense component-owned canvases through the Metal scene path when a
  device is available, embedding a transparent `CAMetalLayer` in the regular
  AppKit host while preserving native controls, input, accessibility, and an
  explicit AppKit fallback.
- Keep malformed/overlarge paths, missing resources, and remaining typography
  limits explicit in counters and fallback behavior.

Acceptance: the same supported scene renders through software and GPU paths, a
native window presents it, failures fall back predictably, and benchmark output
makes CPU/render/frame/GPU costs visible. This acceptance is met for the
current macOS scene slice; complex effects and other platform hosts remain
later milestones.

### 0.7 — Portable text contract and real virtualization (core slice complete)

- Define a shaped-run/glyph-resource adapter with script, fallback, and bidi
  metadata; the deterministic portable run contract, CoreText adapter, and
  optional HarfBuzz OpenType adapter are now implemented. Custom fallback
  chains and full paragraph bidi remain explicit extensions.
- Replace visible-range-only lists with stable-key item builders, recycling,
  measured extents, prefix offsets, overscan, anchoring, and ensure-visible
  behavior; scrollbar policy remains separate.
- Benchmark text-heavy and variable-height long-list scenarios separately from
  small trees.

Acceptance: shaping and recycling are observable capabilities with tests for
identity, focus, keyboard navigation, editing, and scroll stability.

### 0.8 — Native depth and localized execution

- Add native adapters for text input/IME, menus, dialogs, tables, lists,
  accessibility actions, drag/drop, and platform lifecycle in priority order.
- Add dependency-scoped invalidation and localized component execution so a
  leaf update does not rebuild or repaint unrelated subtrees.
- Extend the capability bus with platform executors, deadlines, cancellation,
  audit metadata, and explicit async result delivery.

Acceptance: mutation traces identify the affected component/view region and
native controls preserve semantics, focus, and input behavior.

### 0.9 — iOS, Android, and Web vertical slices (host artifact slice complete)

- Ship one small shared scenario end-to-end on each target: window/surface,
  input, layout, scene, text, accessibility, and teardown. The current slice
  builds an iOS simulator app, an Android APK, and a browser Canvas demo;
  Mojo runtime integration, platform accessibility, and device/browser CI
  remain required.
- Start with the GPU-capable path where available (Metal, then WebGPU) and a
  documented software/canvas fallback.
- Establish device/emulator/browser CI or a reproducible manual harness before
  declaring support.

Acceptance: each target has a real demo, readiness/teardown checks, a backend
  capability report, and a platform-specific performance baseline.

### 1.0 — supported core and plotting foundation

- Stabilize the public API and compatibility policy.
- Ship Moxi Plot as a supported 2D package with a declarative grammar,
  columnar data, transforms, composable marks, portable scene output,
  native/GPU rendering, interaction, accessibility, and documentation.
- Publish like-for-like performance results for representative UI and plot
  workloads, plus the known limitations for each backend.

Acceptance: a versioned plot specification can be built and inspected without
a renderer; the same supported 2D plot renders through software and native/GPU
paths; selections, viewport changes, and data updates are deterministic;
accessibility exposes a chart summary and data-table fallback; and release
benchmarks record CPU, render, and frame costs at multiple data sizes.

## Plotting library: supported 2D program

Moxi Plot is a library feature, not a demo-specific painter. The product
boundary is a declarative, serializable plot specification plus a stateful
runtime that compiles it into the existing backend-neutral scene contract.
The source of truth is platform-neutral data and declarative configuration;
runtime state, caches, native handles, and renderer-specific resources stay
outside the specification.

The design deliberately combines several proven ideas without making Moxi a
wrapper around another renderer:

- Altair/Vega-Lite's validated declarative grammar, encodings, transforms,
  composition, and selection parameters.
- Bokeh's persistent columnar data source, shared selections, explicit tools,
  streaming, and patch updates.
- Observable Plot and ggplot2's composable marks, scales, facets, statistics,
  and theme defaults rather than a closed list of monolithic chart types.
- Plotly's practical trace/layout model, hover modes, subplots, and animated
  updates.
- Wolfram's parameterized functions, locators, dynamic controls, bookmarks,
  and exploratory manipulation.

### Implementation status of the current 2D slice

The executable foundation now covers typed nullable columnar data, stable row
keys, snapshots and zero-copy views, field-aware encodings, second positional
channels, categorical labels/colors, core Cartesian marks, statistical
histogram/density/ECDF/box/heatmap/hexbin/regression recipes, facets with
independent scale resolution, layer/horizontal/vertical composition,
deterministic filter/sort/sample/bin/rolling/impute/stack/group/aggregate
transforms, forward/inverse scale mapping, annotations, JSON inspection/
round-tripping, PlotView/PlotControl, pointer/touch navigation, interval brush
and lasso selection, explicit linked selections, keyboard focus,
accessibility state, CSV fallback, SVG path/opacity output, and bounded
line/scatter geometry. The software renderer, SVG serializer, Metal geometry,
text, and path support, target fallback bridges, host status contract, and browser host
module are contract-tested.

This is an implemented foundation, not completion of every item in the
design. Custom production font fallback, scrollbar policy, editable collection
widget ownership, Mojo-host runtime integration, asynchronous GPU pacing and
resource lifetime, PDF/PNG export, and the broader polar/geographic/3D
families remain explicitly staged work.

### Core interface

The public API has four layers:

1. `DataTable`, `DataView`, `DataSource`, `DataPatch`, and stable `RowKey`
   types provide typed, column-oriented data and bounded updates.
2. `PlotSpec`, `LayerSpec`, `MarkSpec`, `Encoding`, `TransformSpec`,
   `ScaleSpec`, `AxisSpec`, `LegendSpec`, `FacetSpec`, `CoordinateSpec`,
   `AnnotationSpec`, and `ThemeSpec` describe a plot without owning a window
   or renderer.
3. `PlotRuntime`, `PlotState`, `Selection`, `Parameter`, `Viewport`,
   `PlotEvent`, and `PlotAction` own interaction state and incremental
   invalidation.
4. `PlotView`/`PlotControl` integrates the runtime with Moxi layout, events,
   semantics, and `SceneRenderer` backends.

An illustrative Mojo-like API is:

```mojo
var chart = Chart(data)
chart.layer(
    line().encode(
        x = field("time", TEMPORAL),
        y = field("value", QUANTITATIVE),
        color = field("series", NOMINAL),
    ),
    point().encode(
        x = field("time", TEMPORAL),
        y = field("value", QUANTITATIVE),
        color = field("series", NOMINAL),
        tooltip = fields("time", "value", "series"),
    ),
)
chart.transform(filter(expr("value > 0")))
chart.facet(row = field("region"))
chart.interact(
    hover("nearest").crosshair().tooltip(),
    brush("window").project_x(),
    pan_zoom("x"),
)

var plot = PlotView(chart)
var scene = plot.build_scene(bounds)
plot.dispatch(event)
```

The final API must also provide explicit builders for code that does not use
fluent chaining. `PlotSpec` should be inspectable and versioned, with
`to_json()`/`from_json()` added once the typed contract is stable. A
Vega-Lite subset adapter may be provided later, but Moxi's own specification
is the source of truth.

### Data model and mutation contract

`DataTable` must support:

- `Float64`, `Int64`, `Bool`, categorical/string, timestamp, and duration
  columns;
- nullable values with validity masks rather than treating every `NaN` as a
  missing value;
- dictionary-encoded categories and zero-copy `DataView` row selections;
- stable row identity independent of sorting, filtering, faceting, or
  decimation; and
- immutable snapshots plus `replace`, `append`, `patch`, and bounded
  `rollover` updates.

The runtime keeps the source rows for tooltips, selection, accessibility, and
editing even when a renderer uses an aggregate or level-of-detail geometry.
User-defined transforms are pure and deterministic in the serializable path;
local custom transforms can use a trait-based extension point but must not
silently carry callbacks across a capability or serialization boundary.

### Declarative grammar

Encodings support `x`, `y`, `x2`, `y2`, `color`, `fill`, `stroke`, `opacity`,
`size`, `shape`, `angle`, `radius`, `text`, `tooltip`, `href`, `order`,
`detail`, `key`, `row`, `column`, and `facet`. Each channel can be bound to a
field, literal, typed expression, parameter, or conditional value based on
hover/selection state.

Composition must support:

- layering marks in one coordinate system;
- horizontal, vertical, and general concatenation;
- faceting into small multiples;
- repeated views over fields or channels; and
- explicit shared/independent scale, axis, and legend resolution.

Transforms form a cacheable dataflow graph and include filter, calculate,
sort, group, aggregate, bin, time-unit extraction, stack, window, rolling
statistics, pivot/fold, lookup/join, sample, impute, quantile, density,
regression/LOESS, contour, and hexbin operations.

### Scales, coordinates, and guides

The scale contract must expose both directions and its guide metadata:

```text
forward(value) -> pixel
inverse(pixel) -> value
ticks(count) -> positioned labels
format(value) -> label
domain(), range(), and validity diagnostics
```

Implement linear, logarithmic, symmetric-logarithmic, power/square-root,
temporal, ordinal, point, band, threshold, quantile/quantize, sequential,
diverging, and categorical scales. Domains must define behavior for empty,
constant, reversed, invalid, and out-of-range data.

The first coordinate system is Cartesian. Polar/radial coordinates follow;
geographic projections and 3D cameras use separate extension contracts.
Guides include axes, minor ticks, grid lines, titles, subtitles, legends,
continuous color bars, annotations, responsive sizing, aspect ratios, label
collision handling, and automatic margins.

### Marks and plot families

Named chart functions are recipes that compile into composable marks and
transforms. The initial supported portfolio is:

| Tier | Marks and recipes |
| --- | --- |
| Core 2D | line, step, dot, scatter, bubble, area, band, bar, column, stacked bar, rect, rule, tick, text, interval, error bar |
| Statistical | histogram, density, ECDF, box plot, violin, beeswarm, strip plot, Q-Q plot, regression, LOESS, confidence band |
| Matrix and field | heatmap, raster, image, contour, hexbin, vector field, streamlines |
| Time and finance | candlestick, OHLC, volume, horizon, sparkline, range selector |
| Relational | scatterplot matrix, parallel coordinates, linked small multiples |
| Polar | radial bar, polar line, polar scatter, rose, radar |
| Advanced extensions | treemap, sunburst, icicle, tree, dendrogram, node-link graph, Sankey, geographic layers, 3D surface/mesh/point cloud, volume, isosurface |

Every custom mark must be able to declare its required channels, infer
domains, emit generic scene geometry, contribute hit regions, and publish
accessibility metadata. The core geometry vocabulary should include numeric
path buffers, polylines, polygons, glyph batches, rectangle batches, images,
text runs, and clipping/layer scopes; it should not require a renderer to
understand that a command is a “bar chart.”

### Interaction model

Interactions are declarative tools over explicit runtime state:

| Category | Scope |
| --- | --- |
| Inspect | nearest-point hover, crosshair, tooltip, unified x tooltip, status readout, data table |
| Navigate | pan, wheel zoom, pinch zoom, box zoom, x/y-only zoom, reset, fit-to-data, zoom-to-selection |
| Select | click, shift-click toggle, interval brush, x/y brush, lasso, polygon selection, legend selection |
| Coordinate | shared selections, linked brushing, cross-filtering, linked scales, synchronized cursors |
| Explore | sliders, dropdowns, checkboxes, typed parameter bindings, bookmarks, playback, animation |
| Edit | draggable points, locators, editable regions, annotation handles, add/delete/move marks, undo/redo |
| Streaming | append, patch, rollover, pause/resume, follow-tail, playback window, progressive rendering |
| Accessibility | keyboard focus, arrow-key mark navigation, semantic selection, screen-reader summary, accessible data table |

Selections are data queries, not just pixel rectangles. They are keyed by
stable row identity, may project onto fields or channels, compose with
`AND`/`OR`/`NOT`, and resolve globally, by union, or by intersection across
layers and facets. Hover is transient; selection, viewport, parameters, and
edits are persistent state with explicit invalidation.

### Styling and output

Themes provide semantic tokens for palettes, typography, grid/axis treatment,
mark defaults, normal/hover/selected/muted/invalid states, high contrast,
color-vision-safe output, dark mode, presentation mode, and print mode.

The supported output surface includes deterministic software rendering,
native macOS presentation, GPU rendering when available, and export to PNG,
SVG, and PDF where the backend supports the required text and path contracts.
Every plot must also expose a chart description, axis/encoding summary,
focused data items, and a data-table/CSV fallback for accessibility and
non-visual use.

### Performance and rendering strategy

The compiler caches transformed data, domains, tick labels, facet layout, mark
geometry, hit-test indexes, and accessibility summaries independently. The
current large-data paths use pixel-aware line decimation that preserves
extrema, deterministic scatter representatives, and bounded source data. GPU
buffer reuse/growth is implemented for scene geometry; instancing, progressive
rendering, cancellable transforms, and bounded streaming buffers remain staged.

The original data and stable row keys remain available even when displayed
geometry is aggregated. A cache key must include dataset version, viewport,
scale, transform, style, and relevant interaction state. Interactive work is
measured against the 60 Hz/16.67 ms and 120 Hz/8.33 ms budgets, with CPU-only,
GPU-inclusive, cold-start, and steady-state results identified separately.

### Plot implementation slices

#### Plot foundation

- Add the typed data/source contract and stable row keys.
- Add `PlotSpec`, marks, encodings, transforms, and Cartesian layout.
- Implement line, dot, bar, area, rect, rule, text, and error marks.
- Implement linear, temporal, ordinal, and band scales with axes, legends,
  grid, themes, layer, and basic facet support.
- Emit deterministic scene output and a software-renderer checksum.

#### Interactive plots

- Add `PlotRuntime` and `PlotState`.
- Implement hover, nearest-point inspection, crosshair, tooltips, pan, zoom,
  reset, click selection, multi-selection, interval brush, and lasso.
- Add linked selections across multiple plots, keyboard navigation, touch
  gestures, semantic actions, and a native macOS showcase.
- Add deterministic event replay tests.

#### Analytical and dashboard plots

- Add aggregate, bin, stack, window, density, regression, and quantile
  transforms.
- Add histogram, box, density, ECDF, heatmap, and regression recipes. Violin,
  true hexbin tessellation, contour, and candlestick remain staged.
- Add repeat/concat composition, facet scale resolution, annotations,
  drill-down tables, and animated/streaming updates.

#### Production rendering

- Add GPU instancing, progressive rendering, and resource upload for text and
  images. Batched basic geometry, line decimation, level of detail, and vertex
  resource reuse are implemented.
- Add PNG/SVG/PDF export, versioned specification serialization, themes, and
  print-quality output.
- Add full plot benchmark artifacts and backend capability reports.

#### Advanced extensions

- Add polar and geographic projections.
- Add hierarchy, network, flow, and geospatial mark packages.
- Add a separate `Scene3D`/camera/GPU contract for surfaces, meshes, point
  clouds, volumes, and isosurfaces.
- Add typed function sampling for `function_plot`, `parametric_plot`,
  `polar_plot`, `contour_plot`, and `region_plot`, including adaptive
  sampling, discontinuity detection, locators, parameter controls, and
  animation. Serializable functions use an expression tree or sampled data;
  arbitrary callbacks remain local-only.

### Shared scenarios, references, and validation

The plotting fixture suite belongs in the shared scenario package and is
consumed by tests, examples, benchmarks, and reference comparisons:

- streaming multi-series telemetry;
- linked scatterplot, histogram, and data table;
- faceted categorical sales with stacked bars;
- dense heatmap and hexbin data;
- financial OHLC/candlestick data;
- statistical distributions with known quantiles;
- a parameterized function explorer; and
- 10,000, 100,000, and 1,000,000-row stress fixtures.

Use real Vega-Lite/Altair, Bokeh, Observable Plot, ggplot2, Plotly, and
Wolfram behavior as references where parity matters. Compare semantic output,
interaction traces, scale domains, selections, and representative pixels;
static hand-built imitations are documentation, not behavioral oracles.

Plot tests must cover data replacement/append/patch, stable identity,
transforms, missing values, degenerate domains, clipping, scales and inverse
mapping, tick formatting, stable colors, layout, command output, hit testing,
selection resolution, linked views, event replay, accessibility snapshots,
export, and renderer fallback.

Every example is a contract test. The showcase should include a plot gallery,
linked dashboard, streaming view, function explorer, and accessible data
table, all using the shared fixtures and exposing deterministic headless
checksums alongside visible native/GPU output when available.

### Explicit first-release non-goals

The first supported plotting release does not require every advanced family.
3D rendering, arbitrary symbolic algebra, geographic tile services, network
layout algorithms, server-side collaboration, notebook protocol integration,
and a complete Vega-Lite/Plotly compatibility layer remain post-1.0 or
separate packages. They must not weaken the stable 2D data, scene, state,
accessibility, and performance contracts.

## Browser/integration harness

The Web slice has a known-good server path (`python3 -m http.server 8765`), a
stable route (`native/web/host_demo.html`), explicit `MoxiWebHost.stop()`
teardown, Node contract tests, and a real browser smoke path. The browser demo
exercises pointer/focus/resize/frame callbacks and exposes a labeled Canvas;
the host bridge also exposes DOM accessibility mapping. Live plotting updates
and a packaged WebAssembly target remain later gates. Do not claim the Mojo
Web package from the host demo alone.

## Documentation and release gates

Keep `README.md`, `SPEC.md`, `ARCHITECTURE.md`, API docs, changelog, showcase
instructions, capability reports, and benchmark methodology synchronized.
Each milestone needs:

- a status table distinguishing shipped, experimental, and planned behavior;
- a runnable example consuming the public API;
- unit/property tests for pure contracts and integration tests for visible
  behavior;
- benchmark output with the workload and environment recorded; and
- explicit non-goals and fallback behavior for unsupported targets.

The 0.5 worktree is intentionally preserved as-is while this plan is captured.
Future implementation commits should be narrow, reviewable slices that can be
compared cleanly against the existing 0.5 baseline.
