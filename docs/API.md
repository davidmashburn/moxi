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

Start with [examples/hello_component.mojo](../examples/hello_component.mojo),
then use [examples/form.mojo](../examples/form.mojo) for event routing and
text editing.

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
stable-key overscan slots, recycling, clamped offsets, and
`ensure_visible()`. Variable-height measurement and scrollbars are not yet
implemented.

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
states, bounds, parent ids, and action masks without a native dependency. The
macOS adapter publishes the complete catalog as an AppKit accessibility tree
and translates AX press/pick/increment/decrement/expand/collapse actions back
to the logical event path.

`backend_capabilities(kind)` reports the shipped headless and AppKit targets
and explicit contracts for GPU, Windows, Linux, iOS, Android, and Web.
`MacOSMetalRenderer` reports runtime readiness for the experimental macOS GPU
path, while `MacOSMetalWindow` presents scenes through a CAMetalLayer.
`PlatformTarget`, `SurfaceConfig`, `PlatformSurface`, and
`PlatformAdapter` share lifecycle, resize, and scale-factor rules across the
named mobile/browser targets. iOS, Android, and Web adapters currently fail
closed until native hosts are shipped. `MacOSWindow` adds native queue depth,
dropped-event, and draw-command-overflow counters for adapter diagnostics.

`Scene`, `SceneCommand`, and `SceneRenderer` are the richer drawing boundary.
`SoftwareSceneRenderer` is a deterministic headless rasterizer for basic
shapes, gradients, lines, path bounds, clipping, layers, and transforms.
`MacOSMetalRenderer` batches basic rect/line geometry through Metal and
`SvgSceneRenderer` serializes the same scene for browser-compatible SVG. Text,
image resources, path tessellation, and advanced shader effects retain
explicit fallback behavior.

## Plotting

`PlotDataTable` is a stable-key numeric x/y source with validity masks,
patch/append/rollover updates, versioning, and `csv()` for non-visual output.
`PlotSpec` is a versioned declarative layer list with line/scatter/bar marks,
field encodings, and stable JSON inspection. `plot_from_spec()` compiles its
numeric subset into `Plot`.

`Plot` owns linear scales, axes, grid, legends, line/scatter/bar marks,
nearest-point hit testing, inverse mapping, pan/zoom, and accessibility
summary output. `set_line_point_limit()` enables extrema-preserving line LOD.
`PlotRuntime` adds pointer/touch pan, scroll zoom, hover/selection overlays,
Escape reset, and semantic selection state. The software, Metal, and SVG
scene paths consume the same plot output; the portable shaper remains
approximate and native text is backend-specific.

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
| Plotting | [`src/moxi/plotting.mojo`](../src/moxi/plotting.mojo), [`src/moxi/plot_data.mojo`](../src/moxi/plot_data.mojo), [`src/moxi/plot_spec.mojo`](../src/moxi/plot_spec.mojo), [`src/moxi/plot_runtime.mojo`](../src/moxi/plot_runtime.mojo), [`src/moxi/svg.mojo`](../src/moxi/svg.mojo) |
| Performance | [`src/moxi/performance.mojo`](../src/moxi/performance.mojo), [`docs/performance.md`](performance.md), [`scripts/benchmark.sh`](../scripts/benchmark.sh) |
| Platform targets | [`src/moxi/platform.mojo`](../src/moxi/platform.mojo), [`src/moxi/platform_adapters.mojo`](../src/moxi/platform_adapters.mojo), [`src/moxi/targets.mojo`](../src/moxi/targets.mojo) |
| Text shaping | [`src/moxi/text_shaping.mojo`](../src/moxi/text_shaping.mojo), [`src/moxi/coretext.mojo`](../src/moxi/coretext.mojo), [`native/macos_text.m`](../native/macos_text.m) |
| Reactivity and tasks | [`src/moxi/reactivity.mojo`](../src/moxi/reactivity.mojo), [`src/moxi/tasks.mojo`](../src/moxi/tasks.mojo) |
| Capabilities and conversation | [`src/moxi/capability.mojo`](../src/moxi/capability.mojo), [`src/moxi/conversation.mojo`](../src/moxi/conversation.mojo) |
| Native adapter | [`src/moxi/macos.mojo`](../src/moxi/macos.mojo), [`native/macos_window.m`](../native/macos_window.m) |
| Contract tests | [`tests/`](../tests/) |
