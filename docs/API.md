# Moxi API inventory: 0.5 baseline and post-0.5 slices

This is the short, navigable inventory of the public package surface. The
source files and Mojo compiler remain the normative API definition; the
release gate also emits `dist/moxi-api.json` with compiler-generated API
metadata.

## Application lifecycle

| API | Purpose |
| --- | --- |
| `Component` | Value-based `build(bounds)` and `update(event, view)` contract. |
| `ComponentSlot[Child]` | Typed child ownership, namespaced ids, and local event routing. |
| `App[ComponentType]` | Mount, dispatch, resize, tick, paint, render, and clipboard-aware loops. |
| `WindowBackend` / `WindowConfig` | Backend-neutral window and event-pump boundary. |
| `WindowManager` / `WindowId` | Bounded portable multi-window ownership model. |
| `Renderer` / `PaintCommands` | Backend-neutral complete-frame and optional incremental paint boundary. |
| `TestWindow` / `TestRenderer` | Deterministic headless integration adapters. |
| `LiveScriptState` | Ordinary component shell for a development-reloadable canvas module. |

Start with [examples/hello_component.mojo](../examples/hello_component.mojo),
then use [examples/form.mojo](../examples/form.mojo) for event routing and
text editing.

`DemoEntry`, `DemoCatalog`, and `DemoBrowserState` provide the searchable
wxPython-style example browser. The catalog exposes real source paths, Pixi
tasks, page kinds, and source excerpts; `DemoBrowserState` mounts the
catalog pages through typed `ComponentSlot`s. Scene and plot pages mount a
real canvas node and the host renders their `Scene` in the same window. The
opt-in editable page uses `MacOSFileWatcher` and `MacOSLiveScript` to rebuild
an exported `moxi_live_frame` module in place; standalone Pixi tasks remain
separate companion entrypoints. The core `App` remains process-neutral.

## View and layout

`ColumnView` owns an ordered flat tree of `ViewNode` values. Use
`add_label*`, `add_button*`, `add_text_input*`, `add_checkbox*`,
`add_progress*`, `add_slider*`, `add_switch*`, `add_radio*`,
`add_image*`, `add_multiline_text*`, the catalog helpers (`add_combo_box*`,
`add_list*`, `add_table*`, `add_tree*`, `add_menu*`, `add_dialog*`,
`add_tabs*`, `add_canvas*`, `add_separator*`), `add_spacer*`,
`add_column*`, and `add_row*` to construct it.
Call `layout()` after construction. Use `set_action_id`, `set_enabled`, the
intrinsic/wrapping setters, accessibility setters, and clipping setters to
declare behavior. `ColumnRuntime` reconciles that declaration into retained
widgets by `(id, kind)`.

`add_stack*`, `add_grid*`, `add_split*`, and `add_portal*` provide the 0.5
container modes. Portal offsets are bounded and persistent through `App`
rebuilds. `ScrollState`, `VirtualListState`, and `visible_range()` provide
portable range math; `VirtualRecycler` and `VirtualizedList[Builder]` add
stable-key overscan slots, recycling, measured variable heights,
prefix-offset lookup, anchor-preserving updates, clamped offsets, and
`ensure_visible()`. Scrollbar painting remains a follow-up.

The layout constants are `ALIGN_*`, `JUSTIFY_*`, `COLUMN_AXIS`, and
`ROW_AXIS`. Geometry is represented by `Point`, `Size`, and `Rect`.
`measure_text` and `measure_text_wrapped` are deterministic estimates;
`TextLayoutRequest`, `TextLayoutResult`, `RichText`, and `TextSpan` make the
native-shaping/rich-text fallback explicit.

## Events and editing

`Event` is the portable envelope for pointer/click, scroll, drag/drop, key,
text, IME composition, resize, frame-tick, task-result, touch, and
semantic-action events. The event payloads stay backend-neutral; native key
codes and toolkit handles do not cross the boundary.
`TextInputEvent` can carry a codepoint replacement range; a negative range means
replace the current selection. `TextInputState` provides Unicode-safe cursor,
selection, insertion, replacement, deletion, composition, and clipboard
operations.

## Semantics and platform support

`Semantics` and `AccessibilitySnapshot` expose stable roles, labels, values,
hints, bounds, parent ids, enabled/focused/selected state, explicit
checked/expanded state, optional numeric ranges, and action masks without a
native dependency. The macOS adapter publishes the complete catalog as an
AppKit accessibility tree and translates AX
press/pick/increment/decrement/expand/collapse actions back to the logical
event path. Focused single-line text inputs additionally use an AppKit
`NSTextField` field editor; multiline inputs retain the custom IME client. The
Web host maps snapshots to ARIA, while the iOS and Android host artifacts
expose virtual native accessibility nodes. See [accessibility.md](accessibility.md)
for the platform mapping and current fidelity limits.

`backend_capabilities(kind)` reports the shipped headless and AppKit targets
and explicit contracts for GPU, Windows, Linux, iOS, Android, and Web.
`MacOSMetalRenderer` reports runtime readiness for the macOS GPU path, while
`MacOSMetalWindow` presents scenes through a CAMetalLayer. The
`MacOSMetalCanvasPainter` adapts the same Metal geometry path to a dense
component-owned canvas embedded in the regular AppKit host; it keeps the host
view responsible for input, controls, and accessibility. Its scene path
covers geometry, ASCII fast-path glyphs, CoreText Unicode text textures,
registered file-backed images, curve/arc-flattened paths, concave polygon
fills, and bounded even-odd compound/self-intersecting path fills; it also
exposes draw-submission, text-texture, text-cache hit and text-rasterization,
CPU encode/wait/frame timing, optional GPU timestamps, vertex-capacity,
reallocation, resize, per-resource, and fallback counters. `PlatformTarget`,
`SurfaceConfig`, `PlatformSurface`, `PlatformAdapter`, and `HostContract` share
lifecycle, resize, scale-factor, and native-host status rules across the named
mobile/browser targets. `IOSBackend`, `AndroidBackend`, and `WebBackend`
normalize host input and expose deterministic software fallbacks;
`WebBackend.svg_frame()` is the browser-compatible export path. Native host
shims and local demo artifacts are provided under `native/hosts/`,
`native/ios/`, `native/android/`, and `native/web/`; the Mojo package targets
remain unavailable because the published package is still `osx-arm64`.
`MacOSWindow` adds
native queue depth, dropped-event, and draw-command-overflow counters for
adapter diagnostics.

`Scene`, `SceneCommand`, and `SceneRenderer` are the richer drawing boundary.
`SoftwareSceneRenderer` is a deterministic headless rasterizer for basic
shapes, gradients, lines, path bounds, clipping, layers, and transforms.
`MacOSMetalRenderer` batches geometry through Metal and
`SvgSceneRenderer` serializes the same scene for browser-compatible SVG. Metal
uses embedded printable-ASCII geometry for its fast path and CoreText texture
rasterization for Unicode text; image files must be registered before use.
Quadratic/cubic curves, elliptical arcs, and concave simple polygons are
supported, and compound/self-intersecting paths use a bounded even-odd
scanline tessellator. Malformed or overlarge paths and unsupported resources
retain explicit fallback behavior. The software renderer remains a bounds
oracle for paths, so pixel parity for complex path geometry is a later slice.

## Plotting

`PlotDataTable` is a versioned, stable-key columnar source. It supports
nullable `Float32`, `Float64`, `Int64`, Boolean, string, category, timestamp,
and duration fields, plus append/patch/replace/rollover updates, immutable
snapshots, zero-copy row views, deterministic filter/sort/sample/bin/rolling/
impute/stack/aggregate transforms, statistical histogram/density/ECDF/box/
heatmap/hexbin/regression recipes, `view_selection()` projections, and `csv()`
for non-visual output. Category fields use dictionary indices while preserving
their string labels.

`PlotSpec` is a versioned declarative grammar with explicit channel encodings
(`x`, `y`, `x2`, `y2`, color/fill/stroke, size, opacity, text, tooltip, key,
row, column, and facet), validation, JSON round-tripping, layer/horizontal/
vertical/facet composition, core marks (line, step, dot, scatter, bubble,
bar/column, area/band, rect, rule, tick, text, interval, error bar, histogram,
density, ECDF, box, heatmap/hexbin, and regression), scale metadata,
annotations, and declarative hover/brush/lasso/pan-zoom/selection/keyboard
tools. `plot_from_spec()` applies the serializable transform pipeline and
compiles named fields into `Plot`; facet scale resolution can be shared or
independent per axis.

`Plot` owns Cartesian layout, linear/log/symlog/power/square-root/temporal/
ordinal/band and metadata-preserving output scale kinds, axes, grid, legends,
categorical labels, facets, nearest-point hit testing, inverse mapping,
pan/zoom, per-row styles, and accessibility summary output. Line and scatter
LOD are opt-in through `set_line_point_limit()` and
`set_scatter_point_limit()`; source rows and stable keys remain available for
hit testing.

`PlotRuntime` adds pointer/touch pan, shift-drag interval brushing, option-drag
lasso selection, scroll zoom, hover/crosshair/tooltips, click and
multi-selection, keyboard focus and selection, zoom-to-selection, Escape
reset, and semantic selection state. `PlotSelection` stores stable row keys;
`PlotLink` explicitly propagates a selection between runtimes, so linked views
do not rely on hidden global state. `PlotView`/`PlotControl` compile a spec,
retain its source snapshot, expose a CSV data-table fallback, and integrate
runtime scene/accessibility methods.
The software, Metal, and SVG scene paths consume the same plot output; native
Metal covers geometry, printable ASCII glyphs, CoreText Unicode textures,
registered images, curve/arc-flattened paths, and concave simple polygons, while
unsupported text/path/resource cases remain explicit fallbacks. The portable
shaper remains approximate by design;
`HarfBuzzTextShaper` is an optional host-linked OpenType adapter, while custom
fallback chains and full paragraph bidi remain host policy.

## Capability and agent boundary

`CapabilityDescriptor` defines the fixed manifest entry, side-effect class,
approval policy, availability, concurrency, input schema, and permissions.
`CapabilityInvocation` carries the request id, caller, arguments, routing
metadata, and optional approval. `CapabilityBus.authorize()` enforces policy
and returns a lease for exclusive work; `complete()` releases that exact lease.
`invoke_handler()` runs a registered typed `CapabilityHandler`, records the
successful result in a bounded four-entry recent-history, and supports
idempotent replay. Plain `invoke()` is an executor-less guard and returns
`CAPABILITY_EXECUTOR_REQUIRED`.

The 0.5 schema check is a bounded JSON grammar plus object-argument check; it
is not a full JSON Schema validator. `manifest_json()` is intended for an
adapter that owns transport and execution. `ConversationContext` keeps
historical turns separate from a fresh state payload and can append structured
capability results.

See [the agent design note](../Specification%20High-Performance%20Agent-Re.md)
for the boundary and [examples/wx_style.mojo](../examples/wx_style.mojo) for
the complete visible approval flow.

## Source map

| Area | Source |
| --- | --- |
| Public exports | [`src/moxi/__init__.mojo`](../src/moxi/__init__.mojo) |
| Views and layout | [`src/moxi/view.mojo`](../src/moxi/view.mojo), [`src/moxi/layout.mojo`](../src/moxi/layout.mojo) |
| Controls and editing | [`src/moxi/controls.mojo`](../src/moxi/controls.mojo), [`src/moxi/control_state.mojo`](../src/moxi/control_state.mojo) |
| Runtime and invalidation | [`src/moxi/runtime.mojo`](../src/moxi/runtime.mojo), [`src/moxi/invalidation.mojo`](../src/moxi/invalidation.mojo) |
| Scene and resources | [`src/moxi/scene.mojo`](../src/moxi/scene.mojo), [`src/moxi/software.mojo`](../src/moxi/software.mojo), [`src/moxi/resources.mojo`](../src/moxi/resources.mojo) |
| Live development host | [`src/moxi/live_script.mojo`](../src/moxi/live_script.mojo), [`src/moxi/macos.mojo`](../src/moxi/macos.mojo), [`native/macos_window.m`](../native/macos_window.m), [`tests/live_reload.mojo`](../tests/live_reload.mojo) |
| Plotting | [`docs/plotting.md`](plotting.md), [`src/moxi/plotting.mojo`](../src/moxi/plotting.mojo), [`src/moxi/plot_data.mojo`](../src/moxi/plot_data.mojo), [`src/moxi/plot_spec.mojo`](../src/moxi/plot_spec.mojo), [`src/moxi/plot_runtime.mojo`](../src/moxi/plot_runtime.mojo), [`src/moxi/plot_selection.mojo`](../src/moxi/plot_selection.mojo), [`src/moxi/plot_link.mojo`](../src/moxi/plot_link.mojo), [`src/moxi/plot_view.mojo`](../src/moxi/plot_view.mojo), [`src/moxi/svg.mojo`](../src/moxi/svg.mojo) |
| Performance | [`src/moxi/performance.mojo`](../src/moxi/performance.mojo), [`docs/performance.md`](performance.md), [`scripts/benchmark.sh`](../scripts/benchmark.sh) |
| Platform targets | [`src/moxi/platform.mojo`](../src/moxi/platform.mojo), [`src/moxi/platform_adapters.mojo`](../src/moxi/platform_adapters.mojo), [`src/moxi/targets.mojo`](../src/moxi/targets.mojo), [`src/moxi/host_contract.mojo`](../src/moxi/host_contract.mojo), [`native/hosts/`](../native/hosts/) |
| Text shaping | [`src/moxi/text_shaping.mojo`](../src/moxi/text_shaping.mojo), [`src/moxi/coretext.mojo`](../src/moxi/coretext.mojo), [`src/moxi/harfbuzz.mojo`](../src/moxi/harfbuzz.mojo), [`native/macos_text.m`](../native/macos_text.m), [`native/harfbuzz_text.cpp`](../native/harfbuzz_text.cpp) |
| Reactivity and tasks | [`src/moxi/reactivity.mojo`](../src/moxi/reactivity.mojo), [`src/moxi/tasks.mojo`](../src/moxi/tasks.mojo) |
| Capabilities and conversation | [`src/moxi/capability.mojo`](../src/moxi/capability.mojo), [`src/moxi/conversation.mojo`](../src/moxi/conversation.mojo) |
| Demo browser | [`docs/demo-browser.md`](demo-browser.md), [`src/moxi/demo_browser.mojo`](../src/moxi/demo_browser.mojo), [`examples/demo_browser.mojo`](../examples/demo_browser.mojo) |
| Native adapter | [`src/moxi/macos.mojo`](../src/moxi/macos.mojo), [`native/macos_window.m`](../native/macos_window.m) |
| Contract tests | [`tests/`](../tests/) |
