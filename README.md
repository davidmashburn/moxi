# Moxi

Moxi (pronounced “mox-ee”) is an experimental native UI library for Mojo based on Rust's [Xilem](https://xilem.dev/) by Raph Levien. The
name is a portmanteau of Mojo+Xilem and also plays off the meanings of "mojo" / "moxie." It's also a nod to the `xi` lineage behind
Xilem. Notably, Xilem is based on SwiftUI, another major Chris Lattner project.

The `0.5.0` release surface provides a small interactive view
tree:
declarative children are laid out into retained bounds, reconciled into an
ordered backend-neutral command stream, and drawn by native AppKit. A small
`App` helper owns the component/update/rebuild loop, while backend-neutral
events, focus state, and semantics make keyboard interaction and headless
validation possible.

## What works

- Mojo package precompilation through Pixi.
- Retained runtime state for the declarative control catalog.
- Composable `ColumnView` containers with ordered `ViewNode` children.
- Deterministic vertical layout with uniform padding and spacing.
- Backend-neutral `PaintCommand` and `Renderer` contracts.
- Ordered `PaintCommands` streams for a complete frame.
- Backend-neutral RGBA `Color`, `Style`, and rounded `Panel` primitives.
- Separate `WindowBackend` and `WindowConfig` contracts.
- A native macOS AppKit window and canvas renderer.
- Resize-aware root layout and repainting in the native counter example.
- A visible demo that renders multiple labels and buttons from Moxi commands.
- An interactive counter demo with primary-pointer events and state updates.
- A value-based `Component` contract used by the counter example.
- Typed `ComponentSlot` composition with namespaced child ids and local event
  routing.
- Stable action ids that decouple component handlers from view ids.
- Opt-in root and nested-container clipping with paint-command clip metadata.
- Optional incremental renderer dispatch for changed and removed regions.
- A high-level `App` lifecycle helper and a component example.
- A backend-neutral event model for pointer, key, text, and resize input.
- Focus preservation, Tab/Shift-Tab traversal, and keyboard button activation.
- Directional focus navigation between semantic controls with arrow keys.
- Reusable label, button, and text-input control descriptors.
- Reusable checkbox and determinate progress control descriptors with
  retained state, keyboard focus, semantics, and native AppKit painting.
- A single-line text input with Unicode-safe cursor movement, selection,
  insertion, and deletion.
- Backend-neutral marked-text composition with native macOS IME delivery,
  inline rendering, commit/cancel handling, and candidate-window anchoring.
- Visible native text selection plus portable copy, cut, and paste commands.
- Pointer down/move/up routing with hover, pressed, enabled, and click state.
- A horizontal row layout with fixed-width children and flexible slots.
- Stack, grid, split, and clipped portal containers with persistent scroll
  offsets and fixed-extent virtual-range math.
- Opt-in deterministic intrinsic text and control measurement.
- Opt-in deterministic wrapped text measurement with intrinsic-height updates.
- Start/center/end and space-between main-axis distribution, with cross-axis
  alignment for columns and rows.
- Nested column/row containers in one flat, parent-aware view tree.
- Backend-neutral accessibility semantics with stable roles, labels, values,
  state, bounds, and parent ids.
- A native macOS accessibility tree generated from those semantics, including
  catalog roles, AX actions, value changes, and semantic action routing.
- A deterministic capability bus with a fixed manifest, side-effect policy,
  exact agent approval checks, typed handler execution, replay, and explicit
  exclusive-call leases.
- Backend capability reporting for headless, macOS AppKit, GPU, Windows, and
  Linux targets, with unsupported targets reported rather than silently used.
- Text layout requests, a small rich-text span model, and explicit reporting
  when headless measurement falls back from native shaping/bidi.
- Identity-based minimal reconciliation that reuses retained nodes across
  rebuilds while preserving declaration order.
- Deterministic min/max size constraints with conflict normalization.
- View-tree validation for duplicate ids, invalid parents, and cycles.
- Frame-tick events, explicit scalar animation, merged invalidation regions,
  and paint-command changed/removed metadata.
- Canonical `App.run()` and `App.run_with_clipboard()` event-loop helpers.
- Headless renderer/window backends for deterministic integration tests.
- A backend-neutral scene/resource boundary plus a deterministic software
  scene renderer for shape, gradient, line, path-bound, clipping, layer, and
  transform contract tests.
- Stateful combo-box, list, table, tree, menu, dialog, tabs, and canvas models,
  with theme coverage for every public catalog kind.
- A native form demo showing the complete interaction path.
- A native row demo showing reusable controls and horizontal layout.
- Native alignment and nested-container demos for the first 0.5 slice.
- A wxPython-style teaching demo that maps frames, panels, box sizers, and
  controls onto the same public component/view contracts.
- A visible agent-approval path: `Agent reset` creates a blocked request and
  `Approve reset` is enabled only after a trusted approval is available.

## 0.5 scope

This release combines the focused native UI core with its first platform and
agent-integration contracts. `CapabilityBus` is an in-process authorization boundary: it does not
pretend to be a network transport or an LLM protocol. UI and agent adapters
construct the same `CapabilityInvocation`; destructive or policy-marked calls
must carry a bus-issued approval bound to the exact request, and asynchronous
adapters can hold an exclusive lease with `authorize()`/`complete()`. The
bounded FIFO, `manifest_json()`, and `ConversationContext.turn_payload()` cover
the queue, tool-manifest, and fresh turn-boundary seams without forcing a
network client or LLM session into the UI core. `invoke()` is deliberately
executor-less and returns `CAPABILITY_EXECUTOR_REQUIRED`; typed handlers use
`invoke_handler()`.

The component surface includes labels, buttons, single-line and multiline text
inputs, checkbox/switch/radio controls, determinate progress and slider
controls, image/resource descriptors, combo boxes, lists, tables, trees, menus,
dialogs, tabs, canvases, separators, spacers, nested containers, and typed
component slots. The catalog state models are deliberately small, but each
kind has a portable semantic role and a deterministic headless behavior path.
The wx-style showcase is the shared scenario for these controls, stable action
routing, clipping, scroll state, wrapped text, rich-text fallback reporting,
backend capabilities, capability authorization, and a typed embedded counter
component.

Text layout is an explicit contract: headless layout is deterministic and
codepoint-based, while the macOS renderer delegates shaping and bidirectional
display to AppKit. `RichText` preserves styled runs as data and reports the
current flattening fallback during portable measurement.

## Core scope

This is a focused 0.5 UI core rather than a full cross-platform framework.

- Supported demo target: macOS on Apple Silicon (`osx-arm64`).
- The current layout supports vertical columns, horizontal rows, stack/grid/
  split/portal containers, alignment modes, fixed/flexible slots, spacers,
  min/max constraints, intrinsic estimates, and deterministic wrapping.
  Portable glyph shaping, bidirectional layout, and rich-text painting remain
  outside the headless core; AppKit supplies those operations for the native
  demo. Portal scrolling is bounded and persistent, while virtualization is
  currently fixed-extent range math rather than a full item-recycling view
  builder. The animation API is frame-stepped; it does not provide a hidden
  platform scheduler.
- The macOS adapter translates pointer down/move/up, key, committed-text,
  IME-composition, and resize events into Moxi events. Single-line inputs
  render marked text inline and anchor the macOS candidate window to the
  requested caret range. Committed text carries AppKit replacement ranges
  through the event boundary. `MacOSClipboard` provides optional system
  pasteboard synchronization for copy/cut/paste. The native event queue is
  bounded and exposes depth/drop counters for diagnostics.
- The native adapter is a small Objective-C AppKit shim. `WindowConfig`
  size-limits, resizability, and fullscreen flags are passed to AppKit.
  Cross-platform and GPU targets have capability contracts and explicit
  unavailable descriptors, but no native bridge is shipped for them yet.
- The core exposes dirty regions and changed commands, and `TestRenderer`
  exercises incremental dispatch. The native AppKit renderer conservatively
  submits a complete frame. `SceneRenderer` has a deterministic software
  backend, but no GPU/Metal compositor yet.
- The 0.5 public boundary is the APIs documented here and in
  [ARCHITECTURE.md](ARCHITECTURE.md); larger facilities remain explicit
  follow-up work.

For the implemented architecture, see [ARCHITECTURE.md](ARCHITECTURE.md).
[SPEC.md](SPEC.md) is long-term design material and includes ideas that are not
implemented in this release.

## Quick start

Install [Pixi](https://pixi.sh), then run:

```sh
pixi run mojo --version
pixi run build
pixi run test
pixi run demo
pixi run counter-demo
pixi run component-demo
pixi run form-demo
pixi run row-demo
pixi run alignment-demo
pixi run nested-demo
pixi run wx-style-demo
pixi run animation-demo
pixi run wrapped-text-demo
pixi run composed-demo
pixi run benchmark
pixi run package-consumer
pixi run check
```

`pixi run demo` opens the native window. Close the window to end the event loop.
The generated `dist/` files and native object file are local build artifacts.

To build the distributable Pixi package:

```sh
pixi publish --path pixi.toml --target-dir output/moxi
```

The resulting conda package contains the compiled `moxi` Mojo package. The
native AppKit demo remains a repository-level example and is not bundled into
the library artifact.

For the public-surface inventory, see [docs/API.md](docs/API.md). For the
visual acceptance surface and source-controlled reference, see
[docs/visual.md](docs/visual.md). `pixi run check` generates compiler API
metadata at `dist/moxi-api.json`; `pixi run benchmark` runs the local layout
comparison harness.

`pixi run counter-demo` opens the interactive counter. Click `Increment` to
regenerate the composed view and repaint the updated count; resize the window
to see the root column relayout.

`pixi run form-demo` opens the 0.5 interaction scenario. The name field starts
focused; type, use the arrow/Home/End keys, press Tab to focus `Submit`, and
activate it with Enter or Space.

`pixi run row-demo` opens a horizontal action bar. Move over a control to see
hover state, press and release it to exercise the pointer lifecycle, and click
to rebuild the selected control.

`pixi run alignment-demo` shows centered cross-axis alignment and main-axis
distribution. `pixi run nested-demo` shows an editable control tree composed
from nested column and row containers. `pixi run wx-style-demo` is a guided
wxPython-style lesson: a frame owns a panel, the panel owns vertical and
horizontal box sizers, and the controls demonstrate routed events, stable
actions, capability authorization, focus, clipboard handling, checkbox/progress
state, wrapped/rich-text contracts, clipping, backend reporting, and a typed
embedded counter component.
`pixi run wrapped-text-demo` shows opt-in codepoint wrapping with intrinsic
height recomputation as the root width changes.
`pixi run composed-demo` shows a parent component owning a typed counter child;
the child is embedded with namespaced ids and still handles its local action.

## Components

Components own state and produce lightweight views. `CounterState` is the
reference component. `App` owns the current view and retained runtime:

```mojo
from moxi import App, CounterState, Event, Rect

var app = App[CounterState](
    CounterState(),
    Rect(0.0, 0.0, 384.0, 184.0),
)

# After the window backend produces an Event:
if app.dispatch(event):
    app.render(renderer)

# The same root can be rebuilt after a window resize:
if app.resize(Rect(0.0, 0.0, width, height)):
    app.render(renderer)
```

`Component.build(bounds)` receives the current root rectangle. `update()` and
`resize()` return whether `App` rebuilt its view and retained runtime. Components
are static Mojo value types in this release. `ComponentSlot[Child]` lets a
parent own a typed child, embed its view under a namespaced container, and
route targeted events back to the child's local ids. Views can also expose
stable action ids through `set_action()`/`set_action_id()`; `App` attaches the
matching action to routed events so handlers can survive view-id changes.
`App.dispatch()` adds the current focus or hit-test target to each event before
it reaches the component.

`CheckboxControl`, `SliderControl`, `SwitchControl`, `RadioControl`, and the
catalog descriptors extend the same pattern for stateful controls. The
`control_state` module supplies bounded selection, disclosure, dialog, tab, and
canvas state machines that are easy to own inside a component. Pointer, key,
and semantic-action paths share one update contract. `CapabilityBus` can sit
beside component state as the policy boundary for those mutations. Register a
`CapabilityDescriptor`, construct a `CapabilityInvocation`, and call
`authorize()` when the application owns the mutation. Use `invoke_handler()` for
a registered typed executor; plain `invoke()` rejects executor-less work.
Exclusive authorizations return a lease token that must be supplied to
`complete()`.

`ColumnView` keeps explicit preferred sizes as the default. Call
`set_intrinsic_width()` or `set_intrinsic_height()` on a node to opt into the
stable `measure_text()` estimate. Call `set_wrap()` or `set_wrap_text()` to
measure a node against its preferred width and derive a deterministic
intrinsic height. `ViewNode.intrinsic_size()` and `ColumnView.intrinsic_size()`
expose the measured result. Call `set_clip_to_bounds()` on a root or
`set_clip_children()` on a nested container to attach rectangle clip metadata
to descendant paint commands. Arrow keys navigate
between semantic buttons and text inputs, while left/right remain text editing
keys when a single-line input owns focus.

View ids must be unique within a tree and stable across `build()` calls.
`ColumnRuntime` matches active nodes by `(id, kind)`, updates only the matched
retained slot, and keeps declaration order in a separate index list. The
`last_created()`, `last_reused()`, `last_updated()`, `last_removed()`, and
`last_moved()` counters make reconciliation behavior observable in tests.
`ColumnView.is_valid()` checks tree identity and parent links; an invalid view
is rejected by `ColumnRuntime.reconcile()` and can be observed through
`validation_failed()` or `App.view_is_valid()`.

`Animation` is advanced explicitly with `advance(delta_seconds)`. Components
can receive the same clock through `app.tick(delta_seconds)`, which delivers a
`FrameEvent` and follows the ordinary update/rebuild path. `App.paint()` merges
the runtime's changed and removed command bounds into its pending
`Invalidation`; `App.render()` clears that invalidation after the renderer and
accessibility snapshot complete. `PaintCommands.changed_count()`,
`removed_count()`, and `dirty_region()` let a backend or test inspect the
frame delta.
Renderers default to complete-frame dispatch. A retained-surface backend can
override `supports_incremental()`; `App.render()` then clears removed regions
and submits only changed commands.

`TextLayoutRequest` and `TextLayoutResult` make portable text behavior
inspectable. The headless result reports deterministic estimate metrics and
explicitly marks native-shaped, RTL, or rich-text requests as fallbacks.
`MacOSRenderer.backend_capabilities()` reports that AppKit supplies shaping and
bidirectional display at paint time. `backend_capabilities()` also reports the
currently available headless and AppKit targets plus the reserved, unavailable
GPU/Windows/Linux targets.

`VirtualListState` and `visible_range()` provide the fixed-extent virtualization
contract without forcing an application to build every item. `ScrollState`
clamps offsets against content and viewport extents. `Scene`, `SceneCommand`,
and `SceneRenderer` form a richer rendering seam; `SoftwareSceneRenderer` is a
deterministic raster backend for shape, gradient, clipping, layer, and
transform tests, while text/image pixels remain resource-dependent.

`MacOSWindow.event_queue_depth()`, `dropped_event_count()`, and
`command_overflow_count()` expose native backpressure and the current
128-slot-per-kind draw limit. Core action/capability/task queues accept
configurable capacities; the native arrays remain bounded and report overflow
instead of treating dropped input or draw slots as silent success.

For a standard loop, open a `WindowBackend` and call `app.run(window,
renderer)`. Use `app.run_with_clipboard(window, renderer, clipboard)` when
system copy/cut/paste synchronization is needed.

For system clipboard synchronization, pass a `MacOSClipboard` to
`app.dispatch_with_clipboard(event, clipboard)`. Headless callers can use
`MemoryClipboard` with the same API.

For a component that only needs a view, see
[examples/hello_component.mojo](examples/hello_component.mojo). For explicit
styling, use `add_label_styled()`, `add_button_styled()`, `set_surface_style()`,
and `set_panel()` on `ColumnView`.

## Examples

The static first vertical slice is in
[examples/hello_window.mojo](examples/hello_window.mojo):

```mojo
var runtime = Runtime()
var view = Label(1, "Hello from Moxi", Rect(32.0, 28.0, 320.0, 56.0))
runtime.reconcile(view)
var command = runtime.paint()

var window = MacOSWindow()
var renderer = MacOSRenderer()
window.open(WindowConfig("Moxi", 384.0, 144.0))
renderer.begin_frame()
renderer.draw_label(command)
window.run()
```

The event-driven composition slice is in
[examples/counter.mojo](examples/counter.mojo). It lays out a title, count
label, and button, then regenerates the view and command stream after each
click on `Increment` or root-size change. The smaller lifecycle example is in
[examples/hello_component.mojo](examples/hello_component.mojo).
The keyboard and text-input slice is in [examples/form.mojo](examples/form.mojo)
and uses the shared `FormState` scenario, including selection, marked-text IME
composition, and portable clipboard commands.
The reusable-control and horizontal-layout slice is in
[examples/row.mojo](examples/row.mojo) and uses the shared `RowState` scenario.
The first 0.5 layout slices are in [examples/alignment.mojo](examples/alignment.mojo)
and [examples/nested.mojo](examples/nested.mojo); both use shared component
scenarios and are covered by headless tests. The learning-oriented wxPython-
style slice is in [examples/wx_style.mojo](examples/wx_style.mojo) and uses
`WxStyleState` from [src/moxi/wxstyle.mojo](src/moxi/wxstyle.mojo). It keeps
the familiar `Frame -> Panel -> BoxSizer -> control` vocabulary while showing
the actual Moxi lifecycle: build, route, stable action, capability
authorization, update, rebuild, and render. It includes every currently
shipped control kind, stateful catalog interactions, a registered native image,
scrolling, and the typed embedded counter component.
`pixi run animation-demo` is a deterministic, headless frame-clock lesson
showing how `Animation` and `Invalidation` compose without a platform timer.

`TestRenderer`, `TestWindow`, `TextInputState`, and the control descriptors are
available from the package root for headless application tests. The
`AccessibilitySnapshot` returned by `App.accessibility()` mirrors the current
ordered view tree without requiring a platform bridge. `MacOSRenderer` also
publishes that snapshot as a native `NSAccessibilityElement` hierarchy; this
bridge routes catalog AX actions back through the same logical event path.
Existing semantic values also emit native AX value-change notifications when
they change between rendered frames.

`TextInputEvent("...", replacement_start, replacement_end)` can replace a
native-provided codepoint range; omitted ranges use the current editor
selection. `CompositionEvent("...", start, end)` carries transient marked text without
mutating the committed value. `CompositionEvent()` ends the current
composition. The native AppKit adapter implements `NSTextInputClient`, so
macOS input methods can update, commit, cancel, and position their candidate
window against a Moxi text input.

## Architecture

The implemented contracts and lifecycle are documented in
[ARCHITECTURE.md](ARCHITECTURE.md).

The current data flow is intentionally small:

```text
Component + root bounds -> App -> ColumnView/tree -> ColumnRuntime -> PaintCommands
       ^                         |       ^          |                 |
       |                         |       |          |           MacOSRenderer
       |                         |       |          |                 |
 Event <- WindowBackend <-------+       +-- focus --+-> AppKit canvas
                   pointer/key/text/resize/action
```

The Mojo core does not own AppKit handles. The platform adapter owns the native
window and translates paint commands across a narrow C ABI boundary; a
`PaintCommands` stream can also be translated into the backend-neutral
`Scene`/`SceneRenderer` path.

## Roadmap

The 0.5 core is intentionally small: one stable declarative component API,
deterministic layout and identity reconciliation, native macOS rendering,
keyboard/text/IME input, accessibility, headless testing, and explicit
animation/invalidation primitives. The current slice adds a capability bus,
checkbox/progress components, portable text-layout/rich-text contracts, and a
backend capability matrix. Cross-platform or GPU backends remain behind the
contracts until they have a native bridge and working demo; AppKit is the only
shaping/bidi-capable shipped renderer. The separate
[Specification High-Performance Agent-Re.md](Specification%20High-Performance%20Agent-Re.md)
remains design material for a future transport/agent bridge; the in-process
authorization boundary is now part of the Moxi core.

## License

Moxi is available under the [MIT License](LICENSE).
