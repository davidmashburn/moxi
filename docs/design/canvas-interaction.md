# Native canvas interaction framework

Status: proposed architecture and delivery plan; no framework implementation is
claimed. This is coordinated with the [mind-map application](mind-mapping.md)
and does not override the [execution plan](../../PROJECT-PLANNING.md).

Build a reusable Mojo framework for direct manipulation on a large 2D surface:
pan, zoom, select, move, resize, connect, and edit objects using native moxi
components. The first substantial consumer is a mind map. A small freeform
node-and-edge editor is the second consumer and a required architecture check.
Both should feel immediate and tactile, with simple application code.

Keyboard interaction is a primary design axis. Every essential canvas
operation must be fast and discoverable without a pointer, including moving,
resizing, connecting, and navigating large documents. Direct manipulation
includes keyboard-driven previews and commits, not only dragging.

## Reference and scope

Take inspiration from xyflow's separation of custom nodes, connection handles,
edges, selection, and viewport. Its [concept guide](https://reactflow.dev/learn/concepts/terms-and-definitions)
provides the reference vocabulary. Its [layout guide](https://reactflow.dev/learn/layouting/layouting)
treats layout algorithms as integrations; our framework likewise separates
interaction from automatic placement. This is a native design, not a React
compatibility layer or a browser dependency.

Deliver two cooperating layers in a proposed `moxi_canvas` package:

- A canvas surface owns coordinates, visible objects, interaction sessions,
  selection, hit testing, overlays, and native component integration. Connections
  are optional; a diagram without edges must not need a graph document.
- A graph extension adds stable ports, edge records, connection/reconnection
  gestures, path geometry, and application-supplied connection rules.

Keep host events, pointer capture, text input, accessibility publication, and
scene rendering in moxi. Keep tree semantics, branch layout, file formats,
workflow execution, and domain validation in applications. Reuse the existing
renderer; this package is not another rendering backend. Package naming and
module boundaries are provisional until the first external consumer compiles.

Initial supported host: native macOS. Pure model, geometry, and event replay
contracts must run headlessly. Other host support requires actual linked input,
rendering, text, and accessibility checks. Touch-first interaction, rotation,
freehand drawing, collaboration, execution engines, arbitrary graph layout
solvers, and a general plugin system are outside the first release.

## Existing implementation evidence

Inspected implementation: `feat/data-workbench` at `c8c7cbb`. These are reusable
foundations, not evidence that a complete graph editor already exists:

- [Event payloads](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/event.mojo)
  include pointer IDs, scroll, drag, composition, and semantic actions. A native
  pinch/magnification route must be probed rather than inferred from scroll.
- [App dispatch](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/app_runtime.mojo)
  retains capture through drag events and gives embedded canvases first refusal
  on scroll. Canvas arbitration must preserve that outer-scroll contract.
- [ReorderInteraction](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/reorder.mojo)
  tracks a stable key and owning pointer, applies a drag threshold, and returns
  a command without mutating the collection. Its
  [tests](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/tests/reorder_interaction.mojo)
  provide lifecycle cases to retain when introducing 2D gestures.
- [Geometry](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/geometry.mojo)
  supplies affine transforms and checked inversion;
  [Scene](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/scene.mojo)
  supplies paths, clips, and transforms. A canvas container still needs a
  verified common transform for retained child input, painting, and semantics.
- [ColumnView](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/column_view.mojo)
  exposes canvas and component mounting. The
  [interaction showcase](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/interaction_showcase.mojo)
  does substantial application-specific coordinate and hit-test work. The new
  surface should remove this repetition for its consumers.

## Ownership and application contract

The application owns durable object/edge records and document transactions.
The framework owns transient interaction state and derived geometry. A standard
in-memory store and command reducer should make the common case small; an
application can adapt its own store through the same bounded record/change
interface. Do not require two synchronized authoritative node arrays.

Provisional concepts are `CanvasView`, `CanvasState`, `CanvasObject`,
`GraphEdge`, `Port`, `CanvasCommand`, `CanvasSnapshot`, and node/edge presenters.
The consumer supplies stable IDs, content, placement, presenters, and policy.
It mounts one surface and handles semantic commands. It must not implement
screen-to-world math, pointer capture, edge hit tests, drag thresholds, or
parallel selection geometry. Names and signatures are settled by a compiled
consumer, not a large up-front trait hierarchy.

Separate four kinds of state explicitly:

1. Document: stable objects, parent relationships where applicable, positions
   or placement constraints, dimensions, ports, edges, and content references.
2. View: camera, selection, focus, tool mode, hover, and presentation preferences.
3. Session: owning pointer, initial values, preview changes, snap target, and
   the document revision against which a gesture began.
4. Derived: measured sizes, routed paths, spatial index, visible set, and
   published paint/hit/semantic geometry.

Records use stable IDs, not array indices. Port IDs remain stable when port
order changes. Removing an object removes or rejects incident edges atomically
according to the document command. No dangling endpoints are published.
The framework supports graphs with cycles; cycle, duplicate-edge, port-type,
and capacity restrictions belong to the consumer's connection policy.

Gesture previews are local transient deltas over committed state. On release,
emit one validated command with before/after information for history. Escape,
capture loss, scope disposal, or invalidation of the target discards the
preview. Revalidate before committing; do not apply a stale gesture to a deleted
or replaced object. Begin with cancellation on conflicting document edits,
not automatic conflict resolution.

Content edits and canvas edits participate in one application history. A drag
is one undo unit; a no-op drag creates none. Pan/zoom and ordinary selection
are view state, not document undo entries. Embedded text editing owns its
typing coalescing while using the same history boundary for committed content.

## Coordinates and published geometry

Use distinct world, canvas-local logical, window logical, and device-pixel
coordinates. Keep conversions centralized and explicit. The camera is
translation plus uniform positive scale initially; rotation is deferred.
Zoom is anchored at the pointer or declared keyboard focus anchor. Clamp scale
and finite world bounds; an "infinite canvas" must not imply unbounded numeric
precision. Probe large-coordinate precision and use camera-relative rendering
if required without changing stored world positions.

One committed snapshot contains object bounds, port anchors, edge paths, label
bounds, z-order, hit regions, and accessibility bounds. Native text caret/IME
placement uses the same transforms. Presentation motion adds a sampled
transform used consistently by paint and hit testing; a moving node must be
clickable where it appears. World layout is independent of viewport motion.

Publish sizes after content measurement. Initial unknown sizes use explicit
provisional bounds and one scheduled correction; prevent measure/layout feedback
loops. Layout requests include document, size, and constraint revisions. Reject
stale asynchronous results. Changes affecting the actively dragged object defer
or cancel layout adoption according to a declared policy.

Use indexed broad-phase hit queries, followed by shape/path-specific tests.
Hit slop is measured in screen logical units so thin edges and small ports stay
usable across zoom. Tie-breaking follows published z-order and explicit target
priority: active editor/overlay, handle, node body, edge, background. Test this
order; do not let paint order and event order evolve independently.

Viewport culling is different from document visibility. Offscreen objects stay
in the document and navigation model. Hidden/folded descendants do not receive
canvas hits. Keep active editors and captured objects alive through culling,
or explicitly end their session before disposal. Cull edges by path bounds,
including edges crossing the viewport with both endpoints offscreen.

## Gesture and focus rules

One primary manipulation session owns the surface initially. Native trackpad
pan/zoom is a separate viewport interaction; define its interaction with an
active drag rather than allowing competing camera writes. Multi-touch object
manipulation is deferred. Every gesture has idle, armed, active, commit, and
cancel outcomes, a screen-space threshold, and deterministic replay inputs.

- Primary press on a node selects it; crossing the threshold moves the selected
  set. A press on an unselected node updates selection before arming. Modifier
  selection follows the host convention and is available as explicit commands.
- Background drag draws a rectangular marquee. A declared pan gesture such as
  middle-button drag or Space-drag pans instead. Space-pan is disabled inside
  text entry. The mind-map compatibility profile disables Space-pan and
  reserves Space for folding; the framework must not hard-code this binding.
- Wheel/trackpad scrolling pans; explicit zoom controls and a documented zoom
  modifier are required. Native pinch support is a probe/release capability,
  not a prerequisite for keyboard zoom. A consumed event cannot also scroll
  the outer container.
- Resize handles preview dimensions with minimum-size/aspect policies. Content
  controls consume their own gestures; entering a button or text field cannot
  accidentally start node dragging. Presenters declare drag regions.
- Connection drag shows a provisional edge, a compatible target halo, and a
  reason for rejected targets. Reconnection retains the old edge until commit.
  A click-source/click-target and keyboard command path provide alternatives.
- Escape cancels the innermost active action; focus traversal can leave the
  canvas. Deletion and context commands have visible equivalents. Closing a
  window, losing capture, or changing tools cannot leave a stuck gesture.

Snap and hover targets use hysteresis to avoid flicker near boundaries. Start
with grid/alignment guides for freeform placement and port snapping for edges;
mind-map insertion slots come from the app. Autopan at viewport edges is bounded
and time-based, preserves the grabbed world point, and stops immediately on
cancel. Replay includes timestamps; host frame rate must not change outcomes.

## Tactile feedback and native composition

The grabbed object follows input immediately; spring or easing motion must not
make it chase the pointer. Animate surrounding objects toward new layout only
when that helps preserve orientation. Retarget from current presentation state
when another edit arrives. No spring simulation runs indefinitely while idle.
Selection outlines, insertion indicators, snap guides, and connection feedback
appear during the gesture. Reduced motion removes transitions without changing
the resulting document. Physical vibration is optional future host support.

Custom nodes can contain ordinary moxi text inputs, buttons, and small controls.
Their identities, focus, selection, and composition survive camera movement and
unrelated node updates. Probe a real IME session at non-unit zoom and inside a
scrolled parent before claiming this works. If native overlays cannot transform
with the scene, use an explicit anchored editing surface with consistent bounds;
do not silently put an unscaled editor over a scaled node.

Transient toolbars and menus mount in a declared screen overlay layer. Clip
canvas content to the viewport, but position menus within the window. The app
does not manually synchronize floating controls with world coordinates.

Keyboard navigation and semantic actions are first-class. The generic graph
can use spatial navigation and node/edge lists; a tree consumer supplies tree
order. Selection, movement, resize, connection, and deletion need command paths
that do not depend on dragging. The native accessibility probe must verify
focus, labels, relationships, transformed bounds, and announcements. Virtualized
objects need reveal/focus actions; culling cannot erase the only accessible path.
xyflow's [accessibility guidance](https://reactflow.dev/learn/advanced-use/accessibility)
is a behavior reference, not evidence for native accessibility support.

## Graph paths, layout, and grouping

Ship straight and cubic curve paths with arrows, labels, stable endpoint ports,
selection styling, and hit testing. Orthogonal routing around obstacles and
editable waypoints are later extensions. Movement updates incident paths and
dependent labels; it does not remeasure all node text. Route geometry is shared
between drawing and hit testing, with bounded flattening tolerance where needed.

Freeform placement is the graph fixture's default. Automatic layout is an
explicit strategy: measured node sizes and edges in, positions/routes and a
revision tag out. The mind-map app supplies an ordered tree layout. A global
solver is not required for the first consumer. Optional future solvers must
meet the project's dependency/license policy.

Add one level of movable/resizable groups for the second consumer after basic
gestures work. Store child coordinates relative to the group and transform
exactly once. Moving a selection containing a group and its descendant must
not move the child twice. Cross-group edges use transformed port positions.
Group membership is distinct from a graph edge and from mind-map ancestry.
Arbitrary nested canvases and executable subflows remain deferred.

## Reactivity, performance, and developer experience

Track dirty content, geometry, edges, selection, and camera separately. Pan/zoom
changes projection/visibility, not document content or node measurement. A node
drag changes its presentation and incident edges; a selection change updates
decorations. Broad observer subscriptions must not rebuild every node for a
pointer move. xyflow's [performance guidance](https://reactflow.dev/learn/advanced-use/performance)
identifies broad node/edge subscriptions as a recurrent source of extra work;
our native implementation must demonstrate its own invalidation behavior.

Use bounded caches and a spatial index with incremental updates. Profile the
simple implementation before selecting a complex index. Report legitimate
global work separately: full layout, select-all, fit-all, and mass deletion
can touch the whole document. Never claim constant-cost mutation for those.

Proposed budgets, subject to the first recorded baseline:

- At 1,000 visible simple nodes and 2,000 edges on a recorded macOS host, p95
  hot drag/pan/selection CPU work through scene submission is at most 8 ms.
  Report p99, worst case, allocation counts, and GPU/presentation separately.
- Target the next available 60 Hz frame; measure input-to-presentation latency.
  A 120 Hz target requires a separate 8.33 ms frame-budget measurement.
- Camera-only updates cause zero node-text measurements; dragging one isolated
  node does not rebuild unrelated node content. Retained work counters prove it.
- Stress 100/1,000/10,000 objects, high-degree hubs, 20,000 edges, offscreen
  crossings, repeated group moves, zoom extremes, and retained editor state.
  Stress sizes are test workloads, not an advertised capacity until measured.

Record cold construction, steady interaction, large transactions, index/cache
memory, and history memory separately. Bound document size and numeric ranges
from evidence. Benchmarks use simple and rich-node fixtures so cheap rectangles
do not stand in for native controls and shaped text.

An external consumer must build a useful custom-node editor using public APIs.
Record glue code, manual geometry/state synchronization, compile time, diagnostic
quality, and required generic parameters. Reject an API that relocates the
existing application event switch into boilerplate callbacks with no reduction
in ownership complexity.

### Keyboard command and navigation contract

Provide scoped command registration with stable command IDs, titles,
enablement/rejection reasons, shortcut bindings, and dispatch. Menus, the
searchable command palette, contextual key hints, accessibility actions, and
pointer affordances invoke those commands. Reuse existing moxi command/action
facilities where sufficient; add only demonstrated gaps. Applications supply
domain commands and navigation policy rather than their own raw-key routers.

Define focus, selection, and the selection anchor separately. Use a single
roving canvas focus entry, then navigation commands within the canvas; Tab must
not require traversing thousands of nodes before reaching another panel.
Provide an explicit route into/out of a focused node's controls and a focus
cycle among canvas, outline/list, inspector, and toolbar. Closing an overlay
restores the invoking target if it still exists, otherwise a deterministic
nearby target. Reveal focus by minimal camera motion, not repeated fit-all.

The navigation strategy can be spatial, tree-based, or graph-adjacency-based.
The framework supplies deterministic tie-breaking and reveal/focus mechanics;
the consumer supplies semantic neighbors. Make the active strategy visible.
Disconnected or offscreen objects remain reachable through a searchable object
list. A focus change alone does not mutate the document.

Support distinct normal, text-edit, move, resize, and connect sessions with
visible state and short local key hints. These are temporary action states,
not an additional mandatory modal editing language. Common actions remain
available directly, and a user can invoke any mode through a named command.
Escape cancels the active preview before clearing selection or leaving focus.
Enter commits an action only when an embedded text/IME interaction has not
consumed it. Document shortcuts never steal cursor movement, deletion, or
composition keystrokes from a text editor.

- **Navigate/select:** arrows follow the active strategy; a declared range
  command extends from the anchor in a deterministic order. Toggle membership,
  select neighbors, and select all are separate commands. Selection and focus
  are never conflated with text selection inside an active node editor.
- **Move:** keyboard nudges support ordinary and fine/coarse steps with visible
  snap feedback. Semantic destinations supplied by an app can replace numeric
  movement: show the candidate destination, then commit or cancel. Repeated
  nudges form bounded/coalesced undo units instead of one entry per repeat.
- **Resize:** start an explicit resize action, show active edge/dimensions,
  adjust with keys, and commit/cancel. Minimum size and aspect constraints are
  identical to pointer resize; announce constraint limits.
- **Connect:** choose a source port, search/navigate compatible destination
  objects and ports, preview the edge, then commit. Reconnect uses the same
  session while retaining the old connection until success. No dragging is
  needed, and incompatible destinations give the same reason as pointer input.
- **View:** keyboard zoom anchors at focused content; fit selection, fit all,
  reset zoom, and pan commands are always discoverable. Empty selection has an
  explicit viewport-center fallback. A minimap is not the only navigation path.

Shortcut profiles must distinguish logical shortcuts from physical key codes,
declare scope/conflict precedence, and support application compatibility
profiles adapted to the platform modifier policy below. The mind-map consumer
defaults to the pinned Freeplane profile in its
[plan](mind-mapping.md#keyboard-editing-and-accessibility), including justified
platform overrides; compatibility does not override the primary-modifier policy.
Generic Tab traversal, Space-pan, arrow nudges, palette, and Escape
handlers must not shadow its creation, folding, restructuring, or idle root
navigation commands. Cancel the innermost active session first, then dispatch
idle keys through the application profile. Host conflicts require explicit
resolution rather than silently replacing compatibility bindings. Set effective
bindings through native testing, including non-US layouts. Keep the command
interface stable even if bindings change. Expose remapping through one table
initially; a graphical shortcut editor and chord-heavy profiles are follow-ups.

#### Platform modifier policy

Use **Primary = Cmd on macOS, Ctrl on Windows/Linux** for ordinary application
commands across canvas, mind mapping, and math editing. Bind actions to the
semantic modifier, not a literal Control key inherited from another platform.
`Ctrl` always means physical Control, even on macOS; `Cmd` means Command.
`Alt` displays as Option on macOS. Unmodified keys and Shift retain their roles.
Menus, palettes, hints, accessibility descriptions, and platform-specific user
help must show the resolved chord, not the word Primary or an ambiguous
“Ctrl/Cmd”. Cross-platform specifications may use Primary with this definition.

Represent Primary, literal Control, Command, Alt/Option, and Shift distinctly
in the shared binding model. Resolve platform bindings before conflict detection
and dispatch; do not add Control as an automatic macOS alias. Preserve the
native text editor's clipboard, selection, and navigation behavior in its scope.
Use Cmd+Z / Cmd+Shift+Z for undo/redo on macOS; Ctrl+Z / Ctrl+Y on Windows/Linux,
with Ctrl+Shift+Z as an additional redo binding where it does not conflict.

An exception needs a per-command record: exact chord and scope, semantic reason,
platform, conflict checks, discoverable alternative, and native verification.
A terminal's Control-based interrupt protocol is a valid kind of reason;
copying an upstream key table or preserving muscle memory alone is insufficient.
No literal-Control exception is approved for these app profiles by this plan.
This policy takes precedence over reference shortcut matching.

Primary substitution is a baseline, not proof that every resulting chord is
available. Check operating-system reservations and application conflicts,
especially Primary+Space and Primary+comma. For a conflict, choose and document
a nonconflicting platform binding before release, preserve the command's
meaning, and expose it in menus. Do not default back to literal Control or
require users to disable system shortcuts. User remapping may override defaults
but does not excuse a broken shipped profile.

Validate resolved tables for all three hosts without requiring a native host
implementation: Primary resolves correctly; literal Control stays distinct;
conflicts are checked after expansion; displayed hints match dispatch; math
and map scopes do not leak keys to the canvas. Run native checks on each host
before claiming support there, with IME and non-US layouts. Pending platform
checks must be reported separately from passing portable table tests.

Keyboard feedback must be as immediate as pointer feedback: a focused object,
prospective destination, ghost position, snap target, or connection preview
updates on each key action. Preserve orientation through minimal scrolling and
bounded transitions. Announce results or errors without speech spam on held
keys. Native key repeat, key-up loss, focus changes, and IME composition must
not leave a repeating action running.

## Delivery and validation

Proposed files, to be created on an implementation branch: `src/moxi_canvas/`
for viewport, records, interaction, geometry/index, presenters, graph, and
history integration; `tests/canvas_interaction.mojo` for deterministic model
and replay checks; `tests/canvas_consumer.mojo` for public API consumption;
`examples/canvas_graph.mojo` for the second consumer. Modify moxi host/runtime
files only for generic integration gaps demonstrated by those consumers.

Proposed task names below do not exist yet. Each milestone adds its task and
fixture alongside implementation; passing a headless task does not certify
native behavior.

1. **C0: prove the seams.** Compile a custom node with text input and button
   under pan/zoom; verify capture, IME placement, clipping, and semantic bounds.
   Define coordinate types, snapshot ownership, and a standard transaction
   path. Add `pixi run canvas-probe`. Exit with native evidence and a small
   consumer, or an explicit host gap with a bounded remedy.
2. **C1: reusable direct manipulation.** Implement selection, viewport,
   marquee, move, resize, preview/commit/cancel, history integration, and
   overlays. Add `pixi run canvas-contract` and deterministic replay. Exit:
   pointer, keyboard, and command actions agree, cancellation is clean, and
   the mind-map app can provide reparent targets without forking gestures.
   Include scoped command routing, roving focus, command search, and keyboard
   move/resize preview sessions in this gate, rather than deferring them to C3.
3. **C2: connections and incremental geometry.** Add ports, paths, validation,
   reconnection, hit index, culling, and bounded autopan. Add fixtures for
   deletion during drag, edge crossings, rich nodes, and stale layouts. Exit:
   both consumers use the same interaction/geometry code and satisfy counters.
   Source/target port selection, connection, and reconnection work keyboard-only.
4. **C3: composition and native quality.** Add group behavior, minimap/fit
   controls, full keyboard paths, and native accessibility/IME acceptance.
   Add `pixi run canvas-native-check` and `pixi run canvas-benchmark`. Exit:
   recorded native sessions meet the supported-host contract and budgets.
5. **C4: package and prove reuse.** Run `pixi run canvas-consumer`, clean install,
   full replay, license inventory, and API documentation checks. Exit: both apps
   use only the public surface and neither owns duplicate canvas geometry.

C0 precedes application node editing; C1 supports branch manipulation; C2
supports crosslinks. C3/C4 complete the framework's initial scope. Do not delay
the first useful mind map for all graph features. Calendar estimates follow C0.

Replay must cover pointer ownership, threshold crossing, Escape/capture loss,
zoom during drag, scroll containment, text-edit arbitration, crossing edges,
removed ports, group movement, clipping, and stale worker results. Validate
coordinate inverses and zoom anchors with tolerances, not only screenshots.
Replay full keyboard-only creation/editing/move/resize/connect/delete/undo
journeys, large-document navigation, command enablement, focus restoration,
shortcut conflicts, repeat coalescing, and mixed pointer/keyboard cancellation.
Run the mind-map compatibility fixture as a consumer test, including Tab and
Shift+Tab creation, Space folding, structural modifier+arrows, and idle Escape.
Native checks include physical keyboard layouts, repeated keys, and IME; a
synthetic key event suite alone is insufficient.
Use native recordings/visual review for tactile behavior and real assistive
technology for accessibility; synthesized events alone cannot establish either.

## Licensing, shared work, and remaining decisions

Use the repository's permissive license for original framework code. xyflow's
[repository license](https://github.com/xyflow/xyflow/blob/main/LICENSE) is MIT;
any reused material needs its actual license/notices recorded. The proposal
requires no JavaScript runtime, paid example code, or third-party layout engine.

Share only proven primitives with [math editing](math-editing.md): committed
geometry, focus/IME integration, transforms, request revisions, and interaction
feedback. A formula's structural caret is not a graph port; math editing does
not require this package, and the canvas does not require a CAS.

Confidence is high in separating generic interaction from application layout
and topology. Confidence is moderate in transformed native component/IME
integration and the proposed performance budgets. C0 failures, excess consumer
glue, or invalidation measurements showing unavoidable broad work would change
the proposed API and delivery sequence. No native probes or benchmarks were
run while drafting this plan.
