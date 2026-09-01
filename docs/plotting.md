# Moxi Plot

Moxi Plot is the first product built on Moxi's portable data, scene, and
interaction contracts. A plot can be inspected and tested without a window;
the same `Scene` can then be rendered by the deterministic software backend,
macOS Metal, or browser-compatible SVG.

## Smallest useful example

```mojo
var data = PlotDataTable()
for index in range(20):
    _ = data.append(Float32(index), Float32(index % 7))

var spec = PlotSpec("signal")
_ = spec.add_line("signal", "x", "y")
_ = spec.add_hover()
_ = spec.add_brush()
_ = spec.add_pan_zoom()
_ = spec.add_click_select()
_ = spec.add_lasso()
var plot = plot_from_spec(spec, data, Rect(0.0, 0.0, 640.0, 360.0))
var scene = plot.build_scene()
```

`PlotSpec` is serializable and owns declarative configuration. `Plot` owns
compiled scales, marks, layout, hit regions, and accessibility summary.
`PlotRuntime` adds persistent viewport and selection state; `PlotView` combines
that runtime with a Moxi view boundary.

## Data and statistical recipes

`PlotDataTable` has typed nullable columns, dictionary-backed categories,
monotonic versions, and stable row keys independent of sorting, filtering, or
level-of-detail reduction. `snapshot()` copies the table for an immutable
boundary. `view()` and `view_selection()` borrow the original table and copy
only row indices, so a filtered selection does not duplicate column storage.
Transforms materialize when they change rows or values.

The current recipe set is deliberately small but executable:

| Recipe | Output | Notes |
| --- | --- | --- |
| `add_histogram` | x/x2 bins, y/count | Equal-width bins; zero-count bins are retained. |
| `add_density` | x/y | Histogram-derived density with area approximately one. |
| `add_ecdf` | sorted x/y | Stable-key sorted empirical cumulative distribution. |
| `add_box` | q1/q3 plus low/high/median | Tukey-style whiskers; optional category grouping. |
| `add_heatmap` | x/x2/y/y2/count | Rectangular 2D density bins. |
| `add_hexbin` | x/x2/y/y2/count | Bounded rectangular compatibility fallback; hex tessellation is staged. |
| `add_regression` | sampled x/y | Ordinary least-squares line over the observed x domain. |

Every recipe is a pure transform in the spec and can be validated against its
source table. The layer mark consumes the derived fields, so the transform
does not leak renderer-specific geometry into the data source.

## Interaction and linking

Selections are stable row keys, not screen rectangles. Click selection,
interval brushing, and option-drag lasso selection update `PlotRuntime` and
remain available for tooltips, accessibility, and data-table fallback. A
`PlotLink` explicitly captures one runtime's selection and applies it to
another runtime. This explicit propagation makes update ownership visible and
avoids hidden global state; an application can choose union/intersection or
cross-filter its own data views.

`PlotView` treats the interaction list as behavior configuration: a view with
no interaction declarations is inert, and only declared hover, brush,
pan/zoom, click-select, keyboard, and lasso gestures are accepted. The
lower-level `PlotRuntime` constructor remains permissive for imperative hosts;
call `runtime.configure(spec)` when compiling a declarative view.

The plotting demos use that contract as a retained interaction surface. In
`pixi run demo-browser`, open `Plot Scene` or `Plot Gallery` and use the
toolbar to reset the viewport, clear the selection, toggle the sample marks,
or start the reactive stream. Hovering shows the crosshair/tooltip; clicking
or using the arrow keys selects a point; drag pans; scroll zooms; shift-drag
brushes an interval; and option-drag selects a free-form lasso. The gallery
also demonstrates stable-key linked selection in its headless replay. These
patterns are inspired by Altair's declarative selections and linked-brush
examples ([interaction guide](https://altair-viz.github.io/user_guide/interactions/index.html),
[linked brush](https://altair-viz.github.io/gallery/scatter_linked_brush.html)).

`PlotView` is the reactive boundary for a changing source. Its
`replace_data()` method compares the source's monotonic version, snapshots
only a changed source, recompiles the scene, and returns whether a refresh
occurred. `replace_spec()` replaces the declarative grammar, while
`reset_view()` and `clear_hover()` expose the small host controls used by the
demo toolbar:

```mojo
var view = PlotView(spec, source, bounds)
var previous_version = source.version
_ = source.append(next_x, next_y)
if source.version != previous_version:
    _ = view.replace_data(source)
```

The standalone `plot-gallery` command replays the same hover, click, zoom,
brush, and linked-selection events before patching a source field, so these
behaviors remain deterministic and testable without a window.

Facet scale resolution is independently configurable for x and y. Shared
scales are the default; `PlotSpec.set_shared_scales(False, True)` gives each
facet panel its own x domain while retaining a shared y domain.

## Rendering and performance

The software renderer is the deterministic oracle. The macOS Metal backend
handles rectangles, rounded rectangles, lines, interpolated linear gradients,
nested clips, transforms, layer opacity, fast-path printable ASCII glyphs,
CoreText-rasterized Unicode text, registered file-backed images, quadratic and
  cubic (`Q/C/S/T`) curve flattening, elliptical arc flattening, concave
  polygon tessellation, and bounded even-odd compound/self-intersecting fill.
  It
reuses a shared vertex buffer and grows it when a frame exceeds the initial capacity;
`vertex_count()`, `buffer_capacity()`, `buffer_reallocation_count()`,
`draw_submission_count()`, `rendered_text_glyph_count()`,
`rendered_text_texture_count()`, `rendered_text_texture_cache_hit_count()`,
`rendered_text_texture_raster_count()`,
`rendered_image_count()`, `rendered_path_count()`, and
`fallback_command_count()`, `frame_time_ms()`, `cpu_encode_time_ms()`,
`cpu_wait_time_ms()`, `gpu_time_ms()`, and `gpu_timing_available()` make the
path observable. Malformed/overlarge path commands and unregistered image
resources remain explicit fallbacks. Compound paths use an explicit even-odd
fill rule so Metal and SVG exports agree.

Run the focused workloads with:

```sh
pixi run plot-gallery
pixi run plot-analytics-benchmark
pixi run plot-interaction-benchmark
pixi run plot-metal-benchmark
pixi run metal-benchmark
MOXI_BENCHMARK_RUNS=1 pixi run benchmark
```

The analytics benchmark covers repeated histogram, box, heatmap, and
regression scene generation plus linked selection. The Metal benchmark also
forces one bounded vertex-buffer growth step. Wall-clock values are host
measurements; deterministic command counts, vertices, checksums, and selected
keys are the portable regression signals.

### Dense mark packets

The ordinary `Scene` path is the correctness, export, and fallback contract.
For dense line/scatter/bar/rect marks, `Plot.build_render_packet()` and
`PlotView.build_render_packet()` expose a compact screen-space packet with flat
ten-`Float32` wire records and ordered contiguous batches. The source table,
row keys, and accessibility model are not reduced.

Static plot composition can use the packet explicitly:

```mojo
var packet = plot.build_render_packet()
var chrome = plot.build_scene(False)
software.render_scene(chrome)
software.draw_plot_packet(packet)
```

`MacOSMetalRenderer.render_plot(plot)` and
`MacOSMetalRenderer.render_plot_view(view)` perform this composition for a
complete frame. The Metal path expands line records into quads in one
instanced draw and expands marker/bar/rect records into rounded or square
instances in another. Per-mark color, opacity, width, and size remain in the
packet, so a plot does not need one native call per point. A packet retains
batch order across line and instance groups; renderers must not reorder it
across clip or compositing boundaries.

The packet reducer is viewport-aware: lines use up to four extrema-preserving
representatives per horizontal pixel by default, while scatter uses a
deterministic screen-space cell representative. Explicit line/scatter limits
remain available for application budgets. Reduction affects only visual
geometry; hit testing, tooltips, stable selections, accessibility, and CSV
fallback continue to use source rows.

Interactive runtimes retain a fixed screen-space grid around the plot. Hover
queries inspect only cells intersecting the pointer tolerance, and brush/lasso
operations first query their bounding rectangle before applying exact geometry
tests. The grid is invalidated by the monotonic `Plot.revision` and rebuilt
only after data, scales, visibility, bounds, or viewport changes. Selection
keys retain deterministic insertion order for linking and serialization, while
membership uses an internal open-addressed index.

`PlotRuntime.build_render_packet()` caches dense mark geometry by plot revision
and adds transient hover/selection overlays to a cloned packet. Tooltip text is
returned by `build_overlay_scene()` so a hover does not invalidate the dense
packet or force the full mark Scene fallback. Hosts that use
`render_plot_view()` draw chrome, packet marks, and this small overlay in that
order. Filled area/band marks, text marks, and active lasso paths still use the
full Scene fallback.

The million-row stress case uses the same packet builder after its source table
is fitted to the viewport. Its geometry remains bounded by occupied screen
cells rather than by source-row count; `pixi run plot-stress-benchmark` reports
both source/emitted representatives and packet bytes.

`fallback_required` is a deliberate correctness guard. Filled area/band marks,
text marks, and active lasso states remain on the full Scene path until their
packet representations exist. Software packet rendering is the
deterministic visual oracle for the Metal packet path.

## Target matrix

`IOSBackend`, `AndroidBackend`, and `WebBackend` share lifecycle, resize,
scale-factor, and event-envelope rules. They normalize touch/pointer,
keyboard, text/IME, and resize notifications and expose deterministic
software fallback checksums. `WebBackend.svg_frame()` provides a browser-
compatible output path today. Native host shims live in `native/hosts/`; the
iOS simulator app, Android API-35 APK, and browser Canvas demo are built by
`pixi run ios-build`, `pixi run android-build`, and
`native/web/host_demo.html` respectively, all covered by
  `pixi run host-check`. Web ARIA, iOS virtual UIKit accessibility elements,
  and Android virtual accessibility nodes are implemented in the host shims;
  Mojo target runtime integration and device/browser CI remain
  capability-gated.

See [API.md](API.md) for the complete inventory and
[performance.md](performance.md) for benchmark policy and budgets.
