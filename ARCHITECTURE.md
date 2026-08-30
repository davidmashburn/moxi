# Moxi architecture: 0.5 baseline and post-0.5 slices

This document describes the stable 0.5 contracts and the experimental
post-0.5 slices currently implemented in the tree. It is the current source
of truth for the public architecture; the larger
[SPEC.md](SPEC.md) is long-term design material and includes proposals that are
not implemented.

## Core contract

Moxi components are Mojo values. A component owns application state, builds a
lightweight declarative view, and handles events:

```mojo
trait Component(ImplicitlyCopyable):
    def build(self, bounds: Rect) -> ColumnView:
        ...

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False
```

`build(bounds)` returns the current view description for the supplied root
rectangle. `update()` returns `True` when the component changed and its view
should be rebuilt. Components do not own native window or renderer handles.
`App.dispatch()` adds the hit-test or focus target and its stable action id to
the event before calling the component.

`CounterState` is the reference implementation of this contract. The counter
example uses the same lifecycle as a user component:

```mojo
var app = App[CounterState](
    CounterState(),
    Rect(0.0, 0.0, 384.0, 184.0),
)

if app.dispatch(event):
    app.render(renderer)

if app.resize(bounds):
    app.render(renderer)
```

This is a static, value-based component contract. `ComponentSlot[Child]` adds
typed composition without a dynamic registry: a parent owns a child value,
embeds the child's flat view under a namespaced container, and routes events
back to the child's local ids. `ViewNode` action ids provide a small stable
dispatch vocabulary without requiring dynamic callbacks or registries.
`App` is the small lifecycle convenience layer and callers can still use
`ColumnRuntime` directly when they need manual control.

`CapabilityBus` is the explicit policy boundary for side-effectful work.
Descriptors form a fixed manifest, invocations carry caller/arguments/approval
metadata, and exclusive entries can be leased with `authorize()`/`complete()`.
`invoke()` is intentionally executor-less and returns
`CAPABILITY_EXECUTOR_REQUIRED`; registered typed handlers use
`invoke_handler()`, which records successful completion in a bounded recent
history for idempotent replay.
The bus also provides a bounded FIFO with observable overflow status and
`manifest_json()` for tool adapters. It authorizes but does not own transport,
LLM sessions, or application mutation; an application applies authorized work
through its own value state. `ConversationContext` keeps historical
role/content turns separate from a fresh active-state injection at each turn
boundary and can append structured capability results.

The event vocabulary is intentionally small: pointer, click, scroll, drag/drop,
key, text, IME composition, resize, frame-tick, task-result, touch, and
semantic-action events. Logical key constants and modifier flags are defined in
`event.mojo`; native key codes do not cross the backend boundary.

## Frame and event lifecycle

The current pipeline is:

```text
Component state
      │ build(root bounds)
      ▼
ColumnView + ViewNode children
      │ layout()
      ▼
App ── route ──> focus/hit-test ──> Component.update(Event)
 │                                      │
 │ rebuild + reconcile                  │ state change
 ▼                                      ▼
ColumnRuntime ──> retained Widgets ──> PaintCommands
                                           │
                                           ▼
                                  Renderer ──> AppKit canvas
                                           ▲
                    Event ◄── WindowBackend
```

The retained paint stream can also be translated with `scene_from_paint()` to
the backend-neutral `Scene` IR. Scene rendering is an explicit second seam; it
does not change the widget reconciliation contract. `Scene` can be consumed by
the deterministic software renderer, the macOS Metal renderer, or the SVG
serializer used by the Web-target export path.

For capabilities, a component constructs an invocation from the same routed
event or from an agent adapter, sends it through `CapabilityBus`, then applies
the authorized mutation and rebuilds. This keeps policy and mutation
ownership separate while preserving one observable state path.

`App` owns component state, root bounds, and the current view. `ColumnRuntime`
owns retained widget data, the active declaration order, and
focused/hovered/pressed ids. The renderer owns platform handles. The core
package never stores an AppKit object.

## Views and layout

`ViewNode` is the lightweight leaf/slot descriptor. Its `kind` covers labels,
buttons, single-line and multiline text inputs, checkbox/switch/radio controls,
progress and sliders, images, combo boxes, lists, tables, trees, menus,
dialogs, tabs, canvases, separators, spacers, and nested containers. It carries
a stable, tree-unique id, optional stable action id, text, preferred
height/width, focusability, optional cursor and selection positions, clip
policy, enabled state, resource handle, control values, semantic metadata, and
the bounds assigned by layout. A child records its parent id, so nested trees
remain simple flat values suitable for Mojo package boundaries.

`ColumnView` stores an ordered `List[ViewNode]`. Its `ColumnLayout` applies one
uniform padding value on all sides and one spacing value between children. The
column gives every child the same content width and uses the caller-provided
preferred height. `set_row_layout()` switches the same lightweight container
to `RowLayout`, which gives fixed-width children their requested widths and
shares remaining width among flexible children. Main-axis start/center/end and
space-between distribution plus cross-axis start/center/end/stretch alignment
are available for both axes. A `SPACER_KIND` child reserves space without
producing a paint command. `add_column()` and `add_row()` create nested
containers; `add_column_to()` and `add_row_to()` allow a container to own
another container, while `add_to()` and the typed helpers attach leaf children.
`add_stack*`, `add_grid*`, `add_split*`, and `add_portal*` select z-stack,
fixed-column grid, split-pane, and clipped scrolling portal containers. Portal
offsets are bounded and persistent through `App` rebuilds. `layout()` must be
called after adding children; the older `layout_children()` spelling remains a
compatibility wrapper. `ScrollState`, `VirtualListState`, and
`visible_range()` provide portable scroll and fixed-extent range math.
`VirtualRecycler` adds stable-key slot ownership, overscan, release-before-
allocate recycling, measured item extents, cumulative offsets, binary-search
range lookup, clamped offsets, and `ensure_visible()`. `VirtualizedList` builds
only active slots through a typed item builder; `set_item_height_preserving_offset()`
keeps the current content anchor stable when an earlier item changes size.
Scrollbar painting remains a separate follow-up.

Text measurement is deterministic and backend-neutral. `measure_text()` uses
the current style's font size and codepoint count to provide a stable
single-line estimate. `measure_text_wrapped()` adds explicit newline handling
and greedy codepoint wrapping for a caller-provided width. `ViewNode` exposes
`set_wrap()`/`set_wrap_text()` as an opt-in contract; when wrapping is enabled,
`intrinsic_size()` derives line count and height from the node's preferred
width, while preserving the existing control chrome.
`TextLayoutRequest`/`TextLayoutResult` make backend selection and fallback
explicit, and `RichText` stores styled spans as portable data. The
`PortableTextShaper` emits deterministic cluster-aware approximate runs with
fallback-face classes. `MacOSTextShaper` delegates to CoreText and retains
native glyph ids, source clusters, positions, advances, bidi direction, and
font fallback through the same `ShapedText` contract. The headless rasterizer
still does not invent glyph pixels.

`ViewNode` supports independent minimum and maximum width/height constraints.
Setting a conflicting bound deterministically normalizes the other bound so
`min <= max`; zero means unconstrained. `ColumnView.is_valid()` checks that
ids are non-negative and unique, parent ids name containers, and parent chains
do not cycle. `ColumnRuntime.reconcile()` refuses an invalid tree without
discarding the previously retained runtime and exposes the result through
`validation_failed()`.

`ColumnView` can carry one optional `Panel` and a root surface `Style`. Leaf
styles are selected by the default constructors or supplied with styled
helpers. The public descriptors cover the complete 0.5 catalog, and
`SelectionState`, `ComboBoxState`, `ListState`, `TableState`, `TreeState`,
`MenuState`, `DialogState`, `TabsState`, and `CanvasState` provide small
portable state machines for the stateful catalog controls. Buttons, toggles,
and catalog controls can be disabled; the runtime excludes disabled controls
from hit-testing and focus. Progress and slider values are clamped to `[0, 1]`
and exposed through semantic values.
Each node also carries backend-neutral `Semantics` (role, label, value, hint,
state, bounds, and parent id), exposed through `App.accessibility()` and the
paint command stream. The native adapter currently uses fill, text color,
corner radius, and font size.

`ColumnView.hit_test()` checks laid-out focusable bounds and the root/ancestor
clip chain, returning the matching view id or `-1` when there is no target.
`ColumnRuntime` applies the same visibility rule and preserves the focused
id across reconciliation when that id remains focusable; otherwise it selects
the first focusable child. Tab traversal wraps in declaration order.
Arrow keys can move between the nearest enabled semantic control using laid-out
geometry; text editing keeps its left/right behavior when a text input owns
focus. The macOS renderer exposes the same tree through a native
`NSAccessibilityElement` hierarchy, including the catalog roles and semantic
press, increment/decrement, pick, expand/collapse actions.

The current layout intentionally does not include baseline/flex negotiation,
intrinsic window resize policies, dynamic component registries, or arbitrary
action callbacks. Portable rich-text painting remains a fallback contract
rather than a custom shaping engine. Rectangle clipping is opt-in at the root
or container level. A caller can rebuild the root with new bounds;
`App.resize()` supplies that relayout path for the native demo.

## Retained runtime

`ColumnRuntime.reconcile()` matches the current `ViewNode` list against active
retained `(id, kind)` slots. Matching nodes are updated in place; new logical
nodes are created, removed slots are reclaimed for later identities, and a
separate active-index list preserves declaration order. `paint()` emits an
ordered `PaintCommands` stream. Each
`PaintCommand` contains a kind, stable id, backend slot, text, final bounds,
a backend-neutral `Style`, focus/hover/pressed/enabled state, cursor and
normalized text-selection bounds, optional transient IME composition text and
its marked selection, optional `wrap_text` and clip metadata, a stable action
id, plus `Semantics`. A frame begins with a surface command, may contain panel
commands, and then emits the complete catalog of leaf commands; container and
spacer nodes are layout only. Composition text is never folded into the
committed text value: an update replaces the marked span, and a commit arrives
as ordinary text input.

The runtime exposes the last reconciliation's created, reused, updated,
removed, and moved counts for deterministic contract tests. `LocalizedExecution`
now records state-scope dependencies, propagates parent invalidation, and
accounts for consumed component builds; `App` uses it for root lifecycle
accounting. The current generic `App` still calls the component's complete
`build()` method, so typed subtree execution and dependency-scoped paint
submission remain future work. `PaintCommand` carries a transient
`changed` bit; `PaintCommands` reports changed/removed command counts and the
union of their bounds. When a retained command moves, the runtime includes both
its previous and current bounds in that union. `App.paint()` folds that region
into its pending `Invalidation`, and `App.render()` clears it after the frame
completes. A renderer can opt into incremental dispatch with
`supports_incremental()`;
Moxi clears removed regions and submits only changed commands. The default
remains complete-frame dispatch, and `MacOSRenderer` currently uses that
conservative path.

`Animation` provides scalar frame-stepped easing without owning a timer.
`FrameEvent` and `App.tick(delta_seconds)` let a component advance its own
animation state through the regular update path. `App.run()` and
`App.run_with_clipboard()` centralize the standard window pump, event dispatch,
and render loop.

The original `Runtime`, `CounterRuntime`, `Label`, and `Button` entry points
remain available as compatibility helpers. New composed code should use
`Component`, `App`, `ColumnView`, and `ColumnRuntime`.

## Rendering and windowing

`Renderer` has these relevant operations:

- `begin_frame()` clears the backend's previous command slots.
- `update_accessibility(snapshot)` publishes the current semantic tree to an
  optional platform accessibility bridge.
- `supports_incremental()` opts a retained-surface backend into changed-command
  dispatch; `clear_region()` clears stale removed-command bounds.
- `draw()` dispatches surface, panel, and every public catalog leaf command.
- The draw methods translate backend-neutral geometry and style.

`MacOSRenderer` sends commands across the narrow Objective-C C ABI. The AppKit
shim currently supports up to 128 slots for each leaf kind per frame and draws
them on one native canvas; rejected slots are counted by
`MacOSWindow.command_overflow_count()` instead of disappearing silently.
`MacOSWindow` owns the resizable window lifecycle, reports its current content
size, and translates pointer down/move/up, key, committed text, marked-text
composition, and resize input into logical `Event` values. Its native FIFO holds
64 pending events and exposes `event_queue_depth()` and
`dropped_event_count()` for backpressure diagnostics. AppKit replacement ranges
for committed text cross the event boundary as codepoint offsets. Buttons and
checkboxes expose hover, pressed, enabled, and focus state;
focused controls draw a native keyboard
focus ring and the text field draws a simple caret, selection highlight, or
underlined marked-text composition.
When `wrap_text` is set, the AppKit shim uses character-boundary line breaks
inside the command bounds; the core's deterministic measurement and the
native rectangle therefore agree on the opt-in line-count behavior.
When a command carries clip metadata, AppKit saves the graphics state and
clips that command to the rectangle before drawing it.
Command-C/X/V are routed through the portable text-input clipboard state; a
`MacOSClipboard` can synchronize those commands with the system pasteboard;
the core remains backend-neutral and `MemoryClipboard` covers headless tests.
The canvas also implements `NSTextInputClient`: AppKit delivers marked-text
updates, committed strings, cancellation, and command selectors through the
same bounded event queue. The candidate window is anchored to the focused
text-input caret for the requested character range. After each rendered frame,
`MacOSRenderer` publishes the semantic snapshot as an owned
`NSAccessibilityElement` hierarchy rooted at the canvas, including container
ancestry and screen-space frames. Catalog `AXPress`, `AXIncrement`,
`AXDecrement`, `AXPick`, `AXExpand`, and `AXCollapse` actions are routed back
through the normal event queue where the role exposes them. Existing semantic
values are compared by stable Moxi id and post native value-change
notifications when they change. The runtime's structural identity diff is
backend-neutral; the native renderer still repaints the complete command
stream under the current renderer contract.

`Scene` and `SceneRenderer` are a richer shape/resource boundary separate from
the widget paint stream. `SceneRecorder` preserves commands for tests, and
`SoftwareSceneRenderer` provides deterministic headless pixels for basic
rectangles, gradients, conservative line/path bounds, clipping, opacity
layers, and affine transforms. `MacOSMetalRenderer` batches supported
rectangles, rounded rectangles, gradients, and lines into a reusable/growing
buffer and ordered draw submissions per frame; `MacOSMetalWindow` presents the
same scene through an AppKit `CAMetalLayer`, including drawable-size/scale
handling. Metal renders printable ASCII glyph geometry, registered file-backed
image textures, and `M/L/H/V/Z` polygon paths; unsupported Unicode glyphs,
unregistered images, and curves remain explicit fallbacks. The software path
remains the deterministic oracle.

`Plot`, `PlotDataTable`, `PlotSpec`, and `PlotRuntime` form the first
application library on the scene contract. A plot owns data-space series and
linear scales, emits axes/grid/legend/core and statistical mark geometry,
supports inverse mapping, pan/zoom, nearest-point hit testing, independent
facet scales, stable-key lasso/linked selection semantics, and
extrema-preserving line LOD. `SvgSceneRenderer` serializes the same scene for
browser-compatible SVG and escapes arbitrary text labels.

`BackendCapabilities` is the runtime capability matrix for a renderer. The
shipped `MacOSRenderer` reports native windowing, AppKit shaping/bidi,
accessibility, and rectangle clipping; `MacOSMetalRenderer` reports readiness
only after its device/pipeline is initialized; `TestRenderer` inherits the
deterministic headless profile and opts into incremental dispatch. Generic GPU,
Windows, and Linux descriptors are explicit contracts so callers can gate
features without probing platform internals.

`PlatformTarget`, `SurfaceConfig`, `PlatformSurface`, `PlatformAdapter`, and
`HostContract` define the common lifecycle/scale contract for macOS-style
hosts, iOS, Android, and Web. Named iOS/Android/Web adapters normalize host
input and provide deterministic software fallbacks (plus SVG frame export on
Web). `native/hosts/` contains the platform-owned UIKit/Metal, Android-NDK,
and browser lifecycle/input shims, but this macOS package does not link their
SDK/runtime surfaces; `HostContract` and the adapters therefore still fail
closed for native availability until a target app and integration harness are
built.

`TestRenderer` records a frame without a platform window. `TestWindow` queues
backend-neutral events and exposes the same window lifecycle shape, allowing
component and event-loop tests to run deterministically in headless builds.
`WindowManager` provides the corresponding bounded portable ownership model
for multiple window ids; native AppKit multi-window ownership is still a
follow-up adapter.

The package build target remains macOS on Apple Silicon, with native host
source slices for iOS, Android, and Web documented separately. The capability
bus is implemented as an in-process authorization/lease boundary; transport,
serialization, and agent-session orchestration remain outside the core. The
capability design note in
[Specification High-Performance Agent-Re.md](Specification%20High-Performance%20Agent-Re.md)
is maintained as a truthful future-adapter guide rather than an implementation
claim.

## Performance contract

`PerformanceCounters` records deterministic per-frame reconcile, layout, paint,
scene, and rasterized-pixel work. `PerformanceReport` combines those counters
with host-supplied elapsed time and checks the 60 Hz (16.67 ms) or 120 Hz
(8.33 ms) frame budget. `scripts/benchmark.sh` repeats the retained pipeline,
portable/statistical plot, dense plot generation, and synchronized offscreen
Metal cases; `MOXI_BENCHMARK_RUNS=1` is the quick path and the default is
three runs.

The retained runtime's open-addressed identity index and the recycler's
release-before-allocate behavior are measured hot-path improvements. The Metal
bridge reports CPU-side vertex counts, draw submissions, buffer growth, and a
deterministic offscreen checksum;
the visible CAMetalLayer demo currently waits for completion, so its timings
are correctness-oriented rather than an asynchronous frame-pacing claim. See
[docs/performance.md](docs/performance.md) for workload definitions and
interpretation.

## Validation surface

The shared counter scenario is exercised by:

- `tests/component.mojo` — component trait, rebuild, resize, and command flow
- `tests/layout.mojo` — exact layout, command order, and hit-testing
- `tests/counter.mojo` — state updates through the component API
- `tests/form.mojo` — text editing, cursor movement, IME composition, focus,
  and activation
- `tests/headless.mojo` — controls, row geometry, pointer lifecycle, Unicode
  editing, semantics, and headless backends
- `tests/alignment.mojo` — 0.5 main/cross-axis distribution contracts
- `tests/nested.mojo` — 0.5 nested-container geometry and semantic ancestry
- `tests/measurement.mojo` — opt-in intrinsic measurement contracts
- `tests/wrapped.mojo` — deterministic wrapping and intrinsic-height contracts
- `tests/composed.mojo` — typed component slots and stable action routing
- `tests/clipping.mojo` — rectangle intersection and nested clip metadata
- `tests/capability.mojo` — manifest policy, agent approval, and exclusive leases
- `tests/controls.mojo` — checkbox/progress semantics and paint commands
- `tests/backend.mojo` — shipped and reserved backend capability profiles
- `tests/platform.mojo`, `tests/platform_adapters.mojo`, and `tests/targets.mojo` — target lifecycle, scale, and fail-closed adapters
- `tests/virtualization.mojo` and `tests/virtual_view.mojo` — stable-key recycling and typed visible-window building
- `tests/execution.mojo` — dependency propagation and localized build accounting
- `tests/plotting.mojo`, `tests/plot_data.mojo`, `tests/plot_spec.mojo`, `tests/plot_runtime.mojo`, `tests/plot_statistics.mojo`, and `tests/plot_selection.mojo` — plot data, spec, scene, statistical recipes, LOD, lasso, and linked interaction
- `tests/svg.mojo` — escaped Web-compatible scene output
- `tests/performance.mojo` and `benchmarks/plotting_large.mojo` — work counters and dense-plot workload
- `tests/text_shaping.mojo` — portable clusters/fallback metadata
- `native/macos_metal.m` and `examples/metal_window.mojo` — native GPU bridge and visible scene demo
- `tests/text_layout.mojo` — deterministic layout and explicit fallback flags
- `tests/wx_style.mojo` — the complete shared wx-style showcase scenario
- `tests/diff.mojo` — stable identity, reorder, update, removal, and slot reuse
- `tests/constraints.mojo` — size constraints, invalid-tree rejection, and
  topmost hit-testing
- `tests/animation.mojo` — easing, frame ticks, invalidation, paint deltas,
  and canonical event-loop helpers
- `tests/extended_controls.mojo` — slider, switch, radio, image, and multiline
  control contracts
- `tests/catalog_state.mojo` — state transitions for the catalog controls
- `tests/style_theme.mojo` — theme coverage for every catalog kind
- `tests/accessibility_contract.mojo` — semantic roles, actions, ancestry, and
  snapshot validity
- `tests/scene_renderer.mojo` — deterministic scene pixels and scope markers
- `tests/property_contracts.mojo` — generated edge cases for ranges, scroll,
  trees, and accessibility identities
- `tests/reactivity_tasks.mojo` — action queues, task completion, and bounds
- `tests/windowing.mojo` — portable multi-window ownership and limits
- `tests/package_consumer.mojo` — package-boundary import and render smoke test
- `examples/counter.mojo` — native event loop and visible rendering
- `examples/hello_component.mojo` — minimal public component API
- `examples/form.mojo` — native keyboard and text-input scenario
- `examples/row.mojo` — native controls and horizontal-layout scenario
- `examples/alignment.mojo` — native alignment scenario
- `examples/nested.mojo` — native nested-container scenario
- `examples/wx_style.mojo` — wxPython-style frame/panel/sizer lesson
- `examples/animation.mojo` — deterministic frame-clock and dirty-region lesson
- `examples/wrapped_text.mojo` — opt-in wrapping and resize-aware intrinsic height
- `examples/composed.mojo` — typed child composition and namespaced event routing

The visual acceptance surface is documented in
[docs/visual.md](docs/visual.md), with source-controlled references at
[docs/wx-style-showcase.svg](docs/wx-style-showcase.svg) and
[docs/wx-style-advanced.svg](docs/wx-style-advanced.svg). The public API
inventory is in [docs/API.md](docs/API.md).

Run the checks with:

```sh
pixi run test
pixi run counter-demo
pixi run form-demo
pixi run row-demo
pixi run alignment-demo
pixi run nested-demo
pixi run wx-style-demo
pixi run wrapped-text-demo
pixi run composed-demo
pixi run benchmark
pixi run package-consumer
pixi run release-check
```

The distributable package contains the core Mojo module. The native AppKit
example remains a repository-level demo and is not bundled into the package.
