# Moxi 0.5 API inventory

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
portable scrolling and fixed-extent virtualization math; a full recycling
view builder is still a post-0.5 item.

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
and explicitly marks GPU, Windows, and Linux bridges unavailable in 0.5.
`MacOSWindow` adds native queue depth, dropped-event, and draw-command-overflow
counters for adapter diagnostics.

`Scene`, `SceneCommand`, and `SceneRenderer` are the richer drawing boundary.
`SoftwareSceneRenderer` is a deterministic headless rasterizer for basic
shapes, gradients, lines, path bounds, clipping, layers, and transforms. It
does not invent glyph or image pixels, and it is not a GPU compositor.

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
| Reactivity and tasks | [`src/moxi/reactivity.mojo`](../src/moxi/reactivity.mojo), [`src/moxi/tasks.mojo`](../src/moxi/tasks.mojo) |
| Capabilities and conversation | [`src/moxi/capability.mojo`](../src/moxi/capability.mojo), [`src/moxi/conversation.mojo`](../src/moxi/conversation.mojo) |
| Native adapter | [`src/moxi/macos.mojo`](../src/moxi/macos.mojo), [`native/macos_window.m`](../native/macos_window.m) |
| Contract tests | [`tests/`](../tests/) |
