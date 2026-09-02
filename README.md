# Moxi

Moxi (pronounced “mox-ee”) is an experimental native UI library for Mojo based on Rust's [Xilem](https://xilem.dev/) by Raph Levien. The
name is a portmanteau of Mojo+Xilem and also plays off the meanings of "mojo" / "moxie." It's also a nod to the `xi` lineage behind
Xilem. Notably, Xilem is based on SwiftUI, another major Chris Lattner project.

The `0.5.1` release surface provides a small interactive view
tree:
declarative children are laid out into retained bounds, reconciled into an
ordered backend-neutral command stream, and drawn by native AppKit. A small
`App` helper owns the component/update/rebuild loop, while backend-neutral
events, focus state, and semantics make keyboard interaction and headless
validation possible. The current `main` branch also contains experimental
post-0.5 slices for Metal scene presentation, CoreText shaped runs, true
stable-key view recycling, and the first Moxi Plot API; those are described
separately below and are not being presented as a 0.5 compatibility promise.

## What works

- Mojo package precompilation through Pixi.
- Retained runtime state for the declarative control catalog.
- Composable `ColumnView` containers with ordered `ViewNode` children.
- Deterministic vertical layout with uniform padding and spacing.
- Backend-neutral `PaintCommand` and `Renderer` contracts.
- Ordered `PaintCommands` streams for a complete frame.
- Backend-neutral RGBA `Color`, `Style`, and rounded `Panel` primitives.
- Semantic spacing, radius, typography, and color tokens with dark, light,
  zinc, and emerald theme presets, plus reusable button, badge, and card
  recipes.
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
- Stack, grid, split, and automatic overflow scrolling for roots, linear
  containers, typed component slots, and explicit portals, with persistent
  offsets and fixed/variable-extent virtual-range math.
- Opt-in deterministic intrinsic text and control measurement.
- Opt-in deterministic wrapped text measurement with intrinsic-height updates.
- Start/center/end and space-between main-axis distribution, with cross-axis
  alignment for columns and rows.
- Nested column/row containers in one flat, parent-aware view tree.
- Backend-neutral accessibility semantics with stable roles, labels, values,
  hints, checked/expanded state, numeric ranges, bounds, and parent ids.
- A native macOS accessibility tree generated from those semantics, including
  catalog roles, AX actions, value/state changes, nested hit testing, and
  semantic action routing.
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
- A macOS Metal scene renderer with offscreen checksums, batched geometry,
  dynamic vertex-buffer growth, blending, rounded rectangles, gradients,
  nested clips, transform/layer state, embedded ASCII GPU glyphs, CoreText
  Unicode text textures, registered image textures, curve/elliptical-arc paths,
  concave polygon tessellation, resize/Retina handling, and a visible CAMetalLayer
  window demo.
- A shaped-run contract carrying glyph ids, source clusters, fallback-face
  metadata, and a native CoreText adapter on macOS.
- A stable-key `VirtualRecycler`/`VirtualizedList` that builds only the
  visible/overscan window, reuses slots, clamps scrolling, and supports
  ensure-visible behavior.
- A first-class Plot model, typed stable-key data source, executable
  declarative spec, composable core and statistical recipes (histogram,
  density, ECDF, box, heatmap/hexbin, regression), field encodings,
  transforms, independent facet scales, lasso/linked selection, line/scatter
  level-of-detail reduction, accessibility summary, deterministic software
  output, and Web-compatible SVG serialization.
- An optional ordered `PlotRenderPacket` fast path for dense line, marker,
  bar, and rectangle marks, with software parity and instanced Metal
  expansion.
- Shared platform host bridges for iOS, Android, and Web that normalize
  touch/pointer/key/text/resize input and provide deterministic software/SVG
  fallbacks. SDK-backed host artifacts now include an arm64 iOS simulator app,
  an arm64 Android API-35 debug APK, and a browser Canvas demo; the Mojo
  package itself remains target-neutral until Mojo iOS/Android/Web runtimes
  are available.
- Stateful combo-box, list, table, tree, menu, dialog, tabs, and canvas models,
  with theme coverage for every public catalog kind.
- A native form demo showing the complete interaction path.
- A native row demo showing reusable controls and horizontal layout.
- Native alignment and nested-container demos for the first 0.5 slice.
- A wxPython-style teaching demo that maps frames, panels, box sizers, and
  controls onto the same public component/view contracts.
- An interaction lab that renders and exercises stable-key collection/table,
  tree disclosure, scrollbar geometry, nested popup layers, and pointer reorder
  state in one live component.
- A searchable Moxi Playground, inspired by wxPython's demo browser, that
  catalogs every checked-in example, mounts stateful component pages, and
  exposes runnable Pixi tasks.
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

The capability-bus concept is credited to David Ash and was seeded from [The
Mythophor capability-bus article](https://www.mythophor.com/agent-ready-architecture-the-capability-bus-pattern/). The
Moxi implementation adapts that seed into an in-process UI policy boundary.

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
  Portable glyph shaping and rich-text painting remain outside the headless
  rasterizer; the explicit portable shaper is approximate, while CoreText
  supplies native shaping/bidi on macOS. Overflow scrolling is bounded and
  persistent. `VirtualRecycler` provides fixed estimates plus measured
  variable-height item recycling; static track/thumb painting is part of the
  retained path, while interactive scrollbar input remains follow-up work.
  The animation API is
  frame-stepped; it does not provide a hidden platform scheduler.
- The macOS adapter translates pointer down/move/up, key, committed-text,
  IME-composition, and resize events into Moxi events. Single-line inputs
  render marked text inline and anchor the macOS candidate window to the
  requested caret range. Committed text carries AppKit replacement ranges
  through the event boundary. `MacOSClipboard` provides optional system
  pasteboard synchronization for copy/cut/paste. The native event queue is
  bounded and exposes depth/drop counters for diagnostics.
- The native adapter is a small Objective-C AppKit shim. `WindowConfig`
  size-limits, resizability, and fullscreen flags are passed to AppKit.
  iOS, Android, and Web have shared lifecycle/event/scale contracts, named
  host bridges, native accessibility surfaces, deterministic fallbacks, and
  host demos under `native/ios`, `native/android`, and `native/web`. Metal
  covers the supported geometry/text/resource slice; AppKit remains the stable
  widget renderer.
- The core exposes dirty regions and changed commands, and `TestRenderer`
  exercises incremental dispatch. The native AppKit renderer conservatively
  submits a complete frame. `SceneRenderer` has both a deterministic software
  backend and a macOS Metal backend. Metal renders printable ASCII text on a
  fast geometry path, rasterizes Unicode through CoreText textures, supports
  registered file-backed images, quadratic/cubic (`Q/C/S/T`) paths, and
  elliptical arcs; it tessellates concave simple polygons plus bounded
  even-odd compound/self-intersecting paths, while malformed/overlarge paths
  and unregistered resources remain explicit fallback behavior.
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
pixi run live-script-demo
pixi run hello-window-demo
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
pixi run interaction-showcase-demo
pixi run theme-showcase-demo
pixi run demo-browser
pixi run interactive-fractal-demo
pixi run plot-demo
pixi run plot-gallery
pixi run plot-svg
pixi run plot-analytics-benchmark
pixi run plot-large-benchmark
pixi run plot-metal-benchmark
pixi run metal-benchmark
pixi run fractal-benchmark
pixi run harfbuzz-demo
pixi run benchmark
pixi run package-consumer
pixi run check
pixi run ios-build
pixi run android-build
```

`pixi run demo` opens the Moxi Playground. Search or filter the catalog, read
the selected example's overview/source, and mount its real component page in
the same window. The `Editable Live Component` watches
`examples/editable_showcase.mojo`: save that file in your editor and its
exported scene is rebuilt and swapped into the existing canvas. Close the
window to end the event loop. `pixi run live-reload-check` validates that
build/load/render ABI without a GUI. `pixi run hello-window-demo` retains the
smallest native window example.
The generated `dist/` files and native object file are local build artifacts.

`pixi run ios-build` requires Xcode and produces a signed arm64 simulator app
at `output/ios-host-sim/MoxiHost.app`. `pixi run android-build` requires the
Android SDK/NDK and produces a signed arm64 API-35 APK at
`output/android/moxi-host-debug.apk`. To inspect the browser host, serve the
repository and open `native/web/host_demo.html`, for example:

```sh
python3 -m http.server 8765
```

The plotting contract is documented in
[docs/plotting.md](docs/plotting.md); [docs/visual.md](docs/visual.md) lists
the visual acceptance surfaces.

To build the distributable Pixi package:

```sh
pixi publish --path pixi.toml --target-dir output/moxi
```

The resulting conda package contains the compiled `moxi` Mojo package. The
native AppKit demo remains a repository-level example and is not bundled into
the library artifact.

For the public-surface inventory, see [docs/API.md](docs/API.md). The
accessibility/native-widget contract is documented in
[docs/accessibility.md](docs/accessibility.md). For the visual acceptance
surface and source-controlled reference, see [docs/visual.md](docs/visual.md).
`pixi run check` generates compiler API
metadata at `dist/moxi-api.json`; `pixi run benchmark` runs the local layout
comparison harness.

`pixi run counter-demo` opens the interactive counter. Click `Increment` to
regenerate the composed view and repaint the updated count; resize the window
to see the root column relayout.

`pixi run demo-browser` opens the Moxi Playground. Use the catalog search and
category filters, inspect an overview or source excerpt, and mount the
stateful component examples in the `Demo` tab. Scene and plotting pages render
their component-owned canvas in this same window. `Plot Scene` and `Plot
Gallery` are live surfaces: hover/click/keyboard selection, pan/zoom,
shift-brush, option-lasso, mark visibility, and a deterministic streaming
update are all exercised in place. The headless `plot-gallery` replay also
demonstrates linked selection. Select `Editable Live
Component`, edit `examples/editable_showcase.mojo`, and save to hot-reload the
scene in place. Press `Escape` to clear the search query.

`pixi run interactive-fractal-demo` opens the interactive line-fractal port of
Xilem's paint example. Its dense canvas uses Metal when available, with AppKit
as a fallback. Uniform line endpoints are uploaded once per frame and expanded
to quads in an instanced Metal vertex shader; visible frames use a three-slot
asynchronous ring. `pixi run fractal-benchmark` measures expansion, endpoint
upload, Metal encoding, GPU completion, and synchronized frame time. The
methodology and comparison caveats are in [docs/performance.md](docs/performance.md).

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
`pixi run interaction-showcase-demo` opens the interaction lab: select and
reorder sparse stable-key rows, inspect tree disclosure and scrollbar movement,
and open nested menu/modal layers. The same component is available as
`Collection & Interaction Lab` in the Playground, where its pointer, keyboard,
scroll, and popup paths are covered in-process.
`pixi run theme-showcase-demo` opens the token and recipe showcase. Switch
between the built-in palettes and exercise the primary, secondary, destructive,
outline, ghost, input, checkbox, and switch recipes; the same page is available
as `Theme & Recipe Showcase` in the Playground.
`pixi run plot-demo` renders the shared first-class plot through the software
scene backend. `pixi run plot-gallery` exercises typed fields, categorical
color, per-row size/opacity/tooltips, temporal axes, facets, declarative
interactions, linked selection, and a reactive source refresh. It also runs
the shared histogram, box, heatmap, and regression recipes with lasso-ready
selections. `pixi run plot-analytics-benchmark`
repeats those recipes and links stable-key selections. `pixi run plot-svg`
prints the same scene as Web-compatible SVG;
`pixi run plot-large-benchmark` measures a 10k-point line and bounded 100k
scatter scene. `pixi run plot-stress-benchmark` runs the 1M-row scatter stress
case with a 50k geometry limit. `pixi run plot-metal-benchmark` measures the
packetized dense-mark path and complete plot composition.
`pixi run metal-window-demo-build` compiles
the visible Metal window; run the resulting binary locally when a GUI session
is available.

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

### Experimental collection interaction foundation

The post-0.5 interaction slice adds renderer-independent contracts for features
mined from MojoGUI-UI: `CollectionSelection` retains focus and selected rows by
stable key across reconciliation and reorder; `ReorderInteraction` owns a
pointer-threshold/cancel/drop lifecycle and emits stable-key reorder commands;
`TreeCollectionState` tracks visible disclosure state; `ScrollbarState` computes
thumb geometry and step/page commands for fixed or variable content; and
`PopupLayerState` manages nested combo/menu/dialog layers, keyboard dismissal,
stable action IDs, and focus restoration. These are state and geometry
primitives, not painted collection widgets or native menu/dialog ownership.
The shared 10,000-row workload is available from
`make_interaction_foundation_scenario()` and the repeatable benchmark is
`pixi run interaction-benchmark`.

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

`TextLayoutRequest`, `TextLayoutResult`, `ShapedText`, `ShapedRun`, and
`ShapedGlyph` make portable text behavior inspectable. The portable shaper is
deterministic and explicitly approximate, with script/direction/fallback runs,
stable source clusters, wrapping, and auto-direction; native
`MacOSTextShaper` uses CoreText and preserves glyph ids, source clusters, bidi
direction, and measured advances. `HarfBuzzTextShaper` is an optional native
adapter that supplies OpenType substitution/positioning and UTF-8 clusters
when linked with `scripts/harfbuzz_check.sh`; custom fallback chains remain
host policy.
`MacOSRenderer.backend_capabilities()` reports AppKit text support, while
`MacOSMetalRenderer.backend_capabilities()` reports the initialized Metal
scene capabilities.

`VirtualListState` and `visible_range()` provide range math; `VirtualRecycler`
and `VirtualizedList[Builder]` add stable-key recycling, overscan, bounded
active slots, measured variable heights, prefix-offset lookup,
anchor-preserving updates, and `ensure_visible()`. `ScrollState` clamps
offsets against content and viewport extents. `Scene`, `SceneCommand`, and
`SceneRenderer`
form a richer rendering seam; `SoftwareSceneRenderer` is a deterministic
raster backend and `MacOSMetalRenderer` is the batched GPU path. Its ASCII,
  CoreText Unicode texture, image, curve/arc, and concave-simple-path support is
resource/capability dependent, with unsupported inputs counted as fallbacks.
The named iOS, Android, and Web
bridges normalize host events and provide fallback output. SDK-backed host
artifacts are checked by `pixi run host-check`; the Mojo package remains
capability-gated for native availability because it is currently published as
an `osx-arm64` package.

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

The first component slice is in
[examples/hello_window.mojo](examples/hello_window.mojo):

```mojo
var app = App[ShowcaseState](
    ShowcaseState(SHOWCASE_HELLO_WINDOW), bounds
)
var window = MacOSWindow()
var renderer = MacOSRenderer()
window.open(WindowConfig("Moxi · Hello Window", 560.0, 320.0))
app.run(window, renderer)
```

The event-driven composition slice is in
[examples/counter.mojo](examples/counter.mojo). It lays out a title, count
label, and button, then regenerates the view and command stream after each
click on `Increment` or root-size change. The smaller lifecycle example is in
[examples/hello_component.mojo](examples/hello_component.mojo).
For a source file that can be edited and reloaded while the host stays open,
see [examples/editable_showcase.mojo](examples/editable_showcase.mojo) and
[docs/demo-browser.md](docs/demo-browser.md#editable-source-and-hot-reload).
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

PlotSpec + PlotDataTable -> PlotView/PlotRuntime -> Scene (oracle/export/fallback)
                                               └-> PlotRenderPacket -> Software | Metal
```

The Mojo core does not own AppKit handles. The platform adapter owns the native
window and translates paint commands across a narrow C ABI boundary; a
`PaintCommands` stream can also be translated into the backend-neutral
`Scene`/`SceneRenderer` path.

## Roadmap

The 0.5 core is intentionally small: one stable declarative component API,
deterministic layout and identity reconciliation, native macOS rendering,
keyboard/text/IME input, accessibility, headless testing, and explicit
animation/invalidation primitives. Post-0.5 slices now add a hardened batched
Metal scene path, CoreText shaped runs, stable-key recycling, localized
execution accounting, target host bridges, and the first Plot library. The
plot foundation now has typed data, executable statistical transforms,
composable marks, independent facet scales, lasso/linked selection, a
view/runtime boundary, and bounded large-data geometry. iOS, Android, and Web
have portable event/fallback bridges plus host-side accessibility surfaces,
but are not yet supported Mojo package targets; the portable shaper remains
approximate, while complex GPU typography, async pacing, and full
cross-platform resource backends remain staged follow-ups. The separate
[Specification High-Performance Agent-Re.md](Specification%20High-Performance%20Agent-Re.md)
remains design material for a future transport/agent bridge; the in-process
authorization boundary is now part of the Moxi core.

## License

Moxi is available under the [MIT License](LICENSE).
