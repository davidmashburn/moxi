# Moxi canvas interaction

D03 adds the `moxi_canvas` package and two running Moxi consumers: a rich-node
composition probe and a freeform processing graph. Both mount ordinary
`Component` implementations containing text input, buttons and sliders. They
share the same document, interaction, geometry, history and native presenter.
The public graph is an editor fixture; it does not execute processing pipelines.

The executable C0–C4 paths are implemented. **Native/human acceptance is still
open, and the proposed 1,000-visible-node performance budget is not met.**
The galleries establish actual window rendering and replayed behavior, not
physical IME, tactile quality, assistive-technology acceptance or frame latency.

## Run and reproduce

With the repository's Mojo environment installed:

```sh
pixi run canvas-contract
pixi run canvas-consumer
pixi run canvas-probe
pixi run canvas-graph
pixi run canvas-native-check
pixi run canvas-gallery
pixi run canvas-interaction-benchmark
```

`canvas-native-check` compiles both executables, opens each native window,
replays ordinary input and canvas commands, asserts native editor identity and
geometry, and captures its actual content view. It requires an available macOS
GUI session. It does not send input to other applications or change devices.
`canvas-gallery` validates and renders each separate version-1 manifest using
[`demo_slideshows.py`](../scripts/demo_slideshows.py). It creates:

- [Rich-node gallery](../artifacts/demo-slideshows/canvas-rich-node/index.html)
- [Freeform graph gallery](../artifacts/demo-slideshows/canvas-graph/index.html)

The PNGs and generated HTML remain ignored local artifacts. Track the manifests,
this recipe and the capture code. Each sequence covers controls, native editing,
zoom/parent clipping, move preview/cancel, resize/undo, invalid/reconnected edges,
and group/fit/minimap. A deterministic AppKit `NSView` bitmap capture is used;
these are real native windows, not a browser imitation or generated picture.
The parent scroll fixture is a retained Moxi parent offset with ancestor clipping,
not an `NSScrollView` integration claim.

The version-1 `revision` field records the base commit during uncommitted work.
The visible `fixture` metadata identifies whether source is committed and includes the
source digest; `source_state` records that distinction too. The current images
must not be presented as captures of the base commit alone. After the parent's
review/commit, rerun both commands to stamp the final commit. No commit is made
by these scripts.

`canvas-benchmark` already names the repository's existing raster benchmark.
D03 preserves it and uses `canvas-interaction-benchmark` for the new workload.
Full build, replay, capture and measurement logs are written to `/tmp/d03-*.log`.

## Public API and ownership

See the small, independent [consumer](../tests/canvas_consumer.mojo) and the two
[component implementations](../examples/canvas_demo/nodes.mojo). The package has
one generic parameter: `CanvasView[YourComponent]`. A consumer can use an ordinary
component with a discriminated model to represent several node kinds. The
package does not require a canvas-specific control subclass.

1. Create a `CanvasDocument`, add stable-ID `CanvasObject`s and fractional `Port`s,
   and connect `GraphEdge`s through a `ConnectionPolicy`.
2. Construct `CanvasView[YourComponent](document)` and `mount(id, component)`.
   Child IDs must be unique within their mount and in `[0, 998)`.
3. Put it in `App`, route host events through `dispatch_canvas`, and use
   `invoke_canvas` for commands. The adapter handles focus, text/clipboard/IME
   priority, pointer capture and standard commands. The consumer does not copy
   a canvas event switch.
4. On macOS, use `moxi_canvas.native.render_canvas` with the existing Moxi native
   renderers. Other backends can consume the same projected view and Scene;
   their native presenters have not been verified by D03.

`canvas-consumer` precompiles `moxi.mojoc` and `moxi_canvas.mojoc`, copies the
consumer into a fresh temporary directory, and compiles/runs with only those
packages on the import path. It does not rely on the examples or source checkout.
The graph fixture itself imports only public canvas APIs. The shared host adds
window pumping, OS clipboard plumbing, rendering and deterministic capture;
no consumer manually synchronizes ports to its control geometry.

Document geometry and edges, camera/focus/selection, transient gestures, and
derived publications are separate. World points and camera math use Float64;
Moxi layout rectangles use Float32. Positive uniform scale is clamped to
0.1–4. World origins are bounded to ±1,000,000; object sizes to 100,000.
Interactive resize has a 120×180 minimum and an optional aspect constraint.
There is one level of groups, with child coordinates relative to the group.
Moving a selected group and its selected child applies the movement once.

A mount retains its component and local layout. Camera motion projects that
layout without rebuilding or measuring its text. Extent changes remeasure the
changed mount and publish ports from the new bounds in the same update. Hidden
or culled objects keep their component state; the active editor is pinned.
Paint, hit testing, native editor placement and clipped semantics consume this
publication. `ColumnView.published_geometry` is the only shared-core change:
it preserves explicitly published bounds when the generic App requests layout.
Ordinary views default to the existing layout behavior.

`CanvasState` owns preview/commit/cancel. Pointer and keyboard use the same
reducer. A committed move, resize or connection is one history transaction;
selection/camera, cancellation and no-op movement do not enter history.
Component content is retained alongside document snapshots for undo/redo.
Text edits coalesce until focus leaves the editor or a canvas command runs.
Slider/button activation is flushed at completion. History is bounded to 100
transactions and currently stores full before/after snapshots, not deltas.

Consumers can call `propose_destination(proposed_document, title,
expected_revision)` during a move to supply a domain-specific destination or
reparent proposal. The common presenter previews it; Enter commits one unit,
Escape discards it, and stale revisions are rejected. The consumer validates
its domain semantics; the canvas validates stable identity/order, bounds and
one-level groups. This hook changes placement/parentage only; graph and content
edits use their normal commands. Unchanged proposals are rejected without history. This is an integration hook, not a mind-map implementation.

## Input and discoverability

Arrows navigate in document order; Shift+arrows extend a deterministic range.
Enter enters a selected node's controls; Escape leaves them after cancelling
an inner composition. Tab keeps ordinary traversal inside controls. One canvas
entry and the toolbar are the default tab stops; thousands of objects do not
become tab stops. The command/object search reaches offscreen objects.

| Action | Default input |
| --- | --- |
| Move / resize | M / R, arrows to adjust, Enter commit, Escape cancel |
| Coarse / fine adjustment | Shift+arrow / Option+arrow |
| Connect | C, `[` cycles source, arrows choose destination, Enter validates/commits |
| Select an edge / reconnect | `]` / E; the old connection remains until valid commit |
| Search commands and objects | `/`, type query, arrows choose, Enter |
| New / group / ungroup | N / G / U |
| Fit all / zoom / reset | F / + or − / 0 |
| Undo / redo | Cmd+Z / Cmd+Shift+Z on macOS; Ctrl+Z / Ctrl+Y elsewhere |
| Additional actions | Search: fit selection, toggle selection, neighbors, pan, snap, aspect |
| Pointer manipulation | Header drag; bottom-right resize handle; background marquee; middle-button pan |
| Viewport / parent scroll | Wheel within viewport pans; Primary+wheel zooms; wheel in outer margin scrolls parent |

The screen drag threshold is four points. Ports acquire within 11 screen points
and retain a current target through 16 points of hysteresis. Edge hits use the
same flattened cubic/straight path as painting, with seven-point hit tolerance.
Autopan is bounded to 240 points/second and a 50 ms timestep, preserving the
grabbed screen point. Camera zoom and unrelated scroll are frozen during a
manipulation/control drag. Foreign pointer IDs and stale document revisions
cannot commit an active gesture.

A `CanvasBinding` table overrides idle bindings; commands numbered 1000 and up
are returned through `take_application_command()`. Text and active previews
retain priority. The compatibility fixture verifies Tab/Shift+Tab creation,
Space folding, Primary+arrow structural commands and idle Escape-to-root across
macOS/Windows/Linux modifier mappings. These are command-delivery tests, not
claims that the D04 mind-map actions exist here. Actual non-US layouts and host
reserved chords remain native acceptance work.

## Geometry, scale and native integration limits

The spatial grid supports incremental insert/remove; unchanged selections cause
zero index writes. The retained path cache invalidates on endpoint, path or label
changes and is bounded to 20,000 entries. Removed edges are pruned. Crossing
paths remain visible when both endpoints are offscreen. Minimap rendering uses
bounded occupancy bins above 512 objects. Public mutation methods cap documents
at 10,000 objects, 40,000 ports and 20,000 edges; those are tested stress ceilings,
not advertised interactive capacities.

Publication currently scans the document and copies snapshots/index storage.
Pan changes projected indexes and paths; fit/select-all/group operations are
global work. Camera-only updates avoid child layout, but are not constant-cost.
Large histories retain full document and component snapshots. These are material
costs in the recorded benchmark, not hidden incremental-performance claims.

The native ordered painter currently accepts label/button/panel/text/native
widget slots, but omits slider slots. The optional canvas presenter paints the
actual `SliderControl` PaintCommand through Scene; its ordinary state, input and
accessibility are unchanged. This is a presenter implementation, not a substitute
control or screenshot overlay. Native ordered paint is capped at 1,024 commands;
custom lines at 32,768 and custom text at 256. The presenter raises on these
limits instead of silently truncating. The native custom ABI has one global clip;
the Canvas adapter analytically clips line segments and intersects filled shapes
against the Scene clip stack. Partially clipped edge labels are omitted. Ordinary
control text retains the native control clip. Large native scenes require a shared
renderer capacity change. Instance-owned ordered custom slices put connections
behind node controls and interaction overlays above them. Each slice retains its
own clip and bounded command ranges; legacy whole-scene painting is unchanged.

The AppKit extension stores custom slices in `MoxiWindowState`; its focused pixel
test checks layer order, clip retention, capacity rejection and window isolation.
Run `pixi run canvas-native-layers` to reproduce it. Native Cocoa/QuartzCore
are linked through the optional presenter ABI. The capture-only Objective-C
helper reads the live view/editor; it does not replace native ownership.

No third-party source or dependency was added. `moxi_canvas`, its demos and tests
use the repository's [MIT license](../LICENSE). The existing [NOTICE](../NOTICE)
and dependency licenses still apply to Moxi. No xyflow implementation was copied.

See [D03 evidence and acceptance gates](canvas-interaction-evidence.md) for the
measured results and exact remaining checks.
