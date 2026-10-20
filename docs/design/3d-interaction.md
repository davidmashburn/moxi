# 3D interfaces, interaction, and components

Status: broad scope and proposed architecture; no 3D implementation or delivery
schedule is claimed. This proposal complements the
[canvas framework](canvas-interaction.md) and preserves the priorities and
current plotting non-goals in the [execution plan](../../PROJECT-PLANNING.md).

Moxi should make spatial applications feel like coherent, reactive interfaces:
ordinary controls can drive a 3D view, objects can be manipulated directly, and
both paths update the same application state with immediate feedback. The
developer should compose components and semantic actions without repeatedly
implementing camera math, picking, gesture arbitration, or synchronization.

Think of 3D as several composable capabilities, rather than one scene-editor
widget. Begin with desktop windows and embedded viewports. Keep world-space UI,
specialist visualization, and immersive input in the design space, with separate
evidence gates before promotion. Physical haptic devices are optional; tactile
interaction first means predictable ownership, stable constraints, responsive
feedback, and reliable cancellation.

## Interface families and possible consumers

The following is a discovery catalog, not a first-release feature checklist.

### Embedded 3D content in ordinary UI

Model previews in inspectors, product configurators, procedural geometry
explorers, molecular or robotics viewers, and interactive illustrations belong
inside normal panels. A viewport participates in layout, resizing, scrolling,
focus, and application commands like any other component.

Useful components include an orbitable preview, selectable model, orientation
indicator, fit/reset controls, material swatches, object inspector, scene
outline, and annotations. Loading, empty, unsupported, and error states remain
ordinary UI. A static thumbnail can become an interactive preview on demand.

### Spatial workspaces and authoring

Assembly arrangement, scene composition, rig or coordinate-frame inspection,
path editing, construction planes, and geometric constraints need precise
manipulation. Add translation axes/planes, rotation rings, scale handles,
pivots, snapping, alignment, bounding boxes, and explicit coordinate readouts.

Support several views of one document: perspective plus orthographic views,
independent cameras, shared selection, and edits reflected everywhere.
Semantic hierarchy, transform parenting, and resource instancing are distinct.
An assembly inspector is a useful consumer without requiring a CAD kernel,
boolean modeling, meshing system, physics engine, or full content-creation suite.

### Scientific and computational interfaces

Surface plots, point clouds, vector fields, trajectories, sampled geometry,
slices, volumes, and simulations suggest reusable probes: point markers,
distance/angle measurements, crosshairs, clipping planes, region boxes, legends,
transfer-function controls, and linked charts.

Separate the interface from the computation. A plane manipulator can drive an
application-owned slice request; a parameter slider can request a new mesh.
Slow computation must leave navigation and previews responsive and identify
which revision is displayed. Rendering a volume, solving a simulation, or
sampling a function is an optional specialist integration. This proposal does
not promote the existing plotting package's deferred 3D feature catalog.

### UI attached to spatial content

Distinguish three presentation modes:

- **Screen overlays:** toolbars, inspectors, numeric editors, and menus stay
  readable at normal UI scale while controlling a scene.
- **Projected anchors:** a label, callout, or editor follows a world point but
  is laid out in screen coordinates. Occlusion and offscreen behavior are
  explicit policies.
- **World-space surfaces:** an actual panel lies in a 3D plane, with perspective,
  depth, clipping, and input mapped into its local 2D component coordinates.
  A planar panel is the first experiment; curved interactive surfaces are later.

Each serves a different purpose. A projected annotation need not require
rendering the full UI into a texture. A textured panel does not automatically
provide native text editing, accessibility, or correct pointer capture.
Applications should choose a mode explicitly rather than accept an accidental
mixture of screen and world behavior.

### Spatial layout and relational views

Explore layouts that place components along a plane, row, grid, ring, path, or
object-relative anchor. Connections can express relationships between spatial
objects, with selectable paths, endpoints, labels, and control points. Layered
networks and exploded hierarchies are candidate consumers, provided depth helps
the task and a searchable structural view remains available.

Separate component layout from camera-dependent label placement and from
physical simulation. A panel may use ordinary 2D layout internally while its
outer frame has a spatial pose. Layout strategies consume measured extents and
return placements; application constraints decide whether those placements are
authored or derived. World-relative size, fixed screen size, and camera-facing
orientation are explicit presentation choices.

Specialist controls can include a slider along a path, angular dial, spherical
direction selector, or interactive coordinate frame. Each should bind to a
semantic value with a numeric/keyboard alternative. These are candidate
components, not a requirement to build a spatial layout solver before S1.

### Depth in conventional UI

Layered cards, perspective transitions, exploded diagrams, stacked data planes,
and constrained 2.5D arrangements may add useful orientation without a freely
orbiting camera. Explore these as small composition primitives. Depth must
communicate hierarchy, relationships, or state, with a reduced-motion and
readable flat presentation where appropriate.

### Immersive and specialized interaction

Future extensions include head-tracked views, tracked controllers, hand input,
ray pointing, direct touching, two-handed manipulation, spatial audio, and
device feedback. Desktop six-degree-of-freedom controllers and gamepads are
also possible adapters. These need explicit coordinate origins, tracking
validity, device loss, action bindings, and host lifecycle behavior.

XR is a separate host/runtime project, not a switch on a desktop viewport.
Stereo rendering, frame pacing, tracking, comfort, permissions, and native
text/accessibility routes require their own acceptance evidence. Preserve the
ability to express those inputs later without making them initial dependencies.

## Fit with moxi and existing evidence

Source inspection on October 20, 2026 used implementation commit
[`c8c7cbb`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
The useful foundations are native UI hosting, component state and event routing,
localized invalidation, resource identities, and the separation between scene
description and backend execution.

The inspected [Scene](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/scene.mojo)
describes 2D shapes, text, images, clipping, and layers.
[Transform](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/geometry.mojo)
is a 2D affine transform. The
[Metal adapter](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/metal.mojo)
implements that scene contract; GPU acceleration does not establish a mesh,
perspective camera, depth-buffer, or 3D material contract.
[ResourceStore](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/resources.mojo)
provides image/font identities but does not establish shared GPU texture
ownership, synchronization, or lifetime guarantees for a new renderer.

The accepted
[scene ownership decision](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/architecture/adr-001-scene-ownership.md)
keeps backend types out of public scene values. Preserve that rule. Extend
generic hosting only where a compiled spatial consumer demonstrates a gap.
Do not add a third coordinate to existing 2D types or require 3D dependencies
for ordinary moxi applications.

The [canvas plan's native component probe](canvas-interaction.md#c0-rich-node-acceptance-scenario)
is relevant to transformed controls, focus, and IME. Reuse its evidence where
the mechanism is shared; a passing affine 2D probe does not establish
perspective surface interaction or occlusion-aware accessibility.

## Architecture and ownership

Use a provisional `moxi_spatial` package with four cooperating responsibilities.
Names and API signatures remain subject to a small compiled consumer.

1. **Viewport hosting:** mount a 3D output in moxi layout, manage camera and
   projection, route focus/input, compose overlays, and handle resizing and
   renderer availability.
2. **Spatial description and resources:** stable object identities, transforms,
   geometry/material references, cameras, instances, visibility, and semantic
   metadata. Applications project their own domain model into these records.
3. **Interaction and components:** picking, selection, camera controls,
   manipulators, probes, annotations, and optional UI-surface presenters.
4. **Renderer adapters:** consume neutral records and resources, report actual
   capabilities, and return compositable output plus optional picking/depth
   information through a bounded lifetime contract.

Moxi owns native windows, text input, accessibility publication, command routing,
and frame scheduling. Spatial code participates in that scheduling rather than
starting an independent application loop. Rendering backends own GPU objects
behind adapters. Applications own document semantics, domain units, computation,
and history. An imported renderer's scene graph must not become a second
authoritative application document.

Separate document state, view state, gesture sessions, and derived data as in
the canvas plan. Geometry resources can be shared across object instances while
selection and transforms use instance identity. Pick results map back to stable
application IDs; raw triangle indices are not durable semantic references.

Each manipulation previews a delta over committed state and emits one validated
command. Numeric editors, keyboard actions, and pointer handles use the same
constraint and commit path. No-op commits create no history entry. Camera
navigation is view state unless the app explicitly edits an authored camera.

Keep transform ancestry, document ancestry, and event/semantic ownership
explicit. A button on a world panel belongs to its UI component; a mesh's
transform parent need not be its command owner. Flattening or instancing render
geometry must not erase those identities.

Share command scopes, capture lifecycle, history integration, resource handles,
revision tracking, and feedback conventions with 2D canvas work. Keep 3D
projection, depth ambiguity, ray queries, and constrained transforms specialized.
Avoid a dimension-generic framework until two working consumers demonstrate a
real simplification.

## Rendering and embedding choices

Start by probing a 3D viewport rendered offscreen and composed into normal moxi
UI. Define output size, device scale, clipping, alpha convention, color space,
resource ownership, GPU completion, and disposal. CPU readback may help an early
correctness probe; measure its cost and do not disguise it as a production
zero-copy path. A native child surface is an alternative only if clipping,
overlays, resize, and input composition remain correct.

The public 2D scene should reference a neutral compositable resource or bounded
viewport primitive, not acquire material/shader internals. Keep 3D depth inside
the spatial pass initially. Screen overlays composite afterward; world-space
labels and surfaces participate in the declared spatial depth policy.
Crossing a depth boundary is explicit, particularly for always-visible handles.

First rendering capabilities are intentionally modest: triangle meshes,
instances, simple lit/unlit materials, depth testing, useful lines/points,
perspective and orthographic cameras, clipping, and selection feedback.
PBR materials, shadows, transparency quality, environment lighting, volumes,
skinning, and custom shader authoring are separately advertised capabilities.
Minimal lighting must still make orientation and shape understandable.

The backend decision is open. Evaluate a small number of concrete routes:

- **Extend the existing Metal bridge for a bounded mesh/depth slice.** This tests
  native integration directly, but creates new renderer maintenance and supplies
  no automatic portability. Do not let a successful triangle demo implicitly
  commit moxi to building a general rendering engine.
- **Integrate an existing renderer such as Filament.** Its
  [project description](https://github.com/google/filament) offers a rendering
  engine with material and asset tooling. The inspected root
  [license](https://github.com/google/filament/blob/main/LICENSE) is Apache-2.0.
  Probe the native bridge, build/toolchain burden, resource sharing, and the
  cost of adapting its scene lifecycle.
- **Use a rendering abstraction such as bgfx.** Its
  [overview](https://bkaradzic.github.io/bgfx/overview.html) describes a
  cross-platform rendering library with a C/C++ API and BSD-2-Clause license.
  This could reduce backend portability work, while leaving more scene,
  materials, and interaction work with moxi.

These are investigation candidates, not selected dependencies or equivalent
products. Compare native embedding, idle behavior, build/distribution size,
debuggability, shader tooling, supported-host evidence, and the actual
transitive dependency/license inventory. Prefer permissive dependencies and
keep optional adapters optional. An engine's root license is not a complete
audit of bundled tools, codecs, assets, or sample content.

## Coordinates, geometry, and frame agreement

Use distinct object-local, world, view, clip, viewport-logical, window-logical,
and device-pixel spaces. Freeze handedness, axis conventions, matrix composition,
angle representation, and clip-depth conversion in the first contract. Adapt
backend conventions at one boundary. Keep world units explicit and display
units separate; camera distance is not a substitute for document scale.

Store rotations in a representation suitable for composition, with a declared
Euler presentation order when showing editable angle fields. Handle singular
transforms, negative scale, nonuniform parent scale, and near-parallel ray/plane
intersections explicitly. Initial manipulation may reject unsupported shear or
singular cases with a visible reason rather than corrupting an object's pose.

A published frame identifies scene, camera, geometry, and viewport revisions.
Rendering, projected labels, picking, and accessibility projection consume
compatible snapshots. Recompute hover when the camera or scene moves under a
stationary pointer. Stale asynchronous pick/computation results cannot activate
an object at a location from an earlier view.

Use a bounded near/far range and scene scale. Probe large-coordinate precision
before deciding between higher-precision document coordinates, camera-relative
rendering, or origin rebasing. Reversed depth and other precision techniques
are backend choices that must preserve the public projection/picking contract.

## Navigation, selection, and manipulation

### Camera and view controls

Start with orbit, pan, dolly, fit selection/all, reset, standard axis views,
and perspective/orthographic switching. Expose the orbit pivot and preserve a
predictable anchor during zoom. Distinguish perspective dolly from changing
field of view and from orthographic scale.

Viewer and editor profiles may bind camera gestures differently. In an editor,
ordinary selection and object manipulation must not compete with background
orbit. Trackpads, two-button mice, and keyboards must have complete routes;
a middle mouse button or numeric keypad cannot be required. Walking/flying,
collision-aware navigation, and cinematic camera rigs are later extensions.

### Picking and selection

Define pickability separately from visual opacity. Use a clear nearest eligible
target policy within the active layer; do not dispatch the same press to every
object along a ray. Screen UI, active manipulators, scene objects, and background
have declared precedence. Pointer capture keeps a manipulation owned by its
session; moving over another object does not give that object the gesture.

Offer deliberate ways to reach occluded content: cycle candidates, inspect a
hit list, isolate objects, use an outline, or enable a visible through-selection
mode. Marquee/lasso policies distinguish visible fragments from all intersecting
objects and containment from intersection. Do not silently select hidden objects.

Pick results may include object/instance ID, sub-element reference, world/local
position, normal, and distance. Sub-element editing is a later capability unless
a first consumer requires it. CPU geometry queries and GPU ID/depth picking are
alternative implementations; evaluate latency and agreement. Avoid synchronous
GPU readback on every pointer event. Deferred results must be revision-checked.

### Precise transformation and constraints

Provide translation along an axis or plane, rotation about an axis, and uniform
scale first; add local/world frames, custom pivots, nonuniform scale, and multiple
selection deliberately. Define shared-pivot versus individual-origin behavior.
Selecting both a parent and descendant must not apply the same transform twice.

The gesture chooses a constraint frame at its start and keeps a stable anchor.
If the view makes an axis almost unobservable, use a declared screen-space
fallback or ask the user to choose another constraint; never allow huge jumps
from an ill-conditioned intersection. Define whether camera movement is allowed
during each manipulation and how the anchor survives it.

Snapping can target a grid, angle, vertex, edge, surface, or application-defined
feature. Show the candidate and resulting constraint before commit. Use
screen-space acquisition thresholds and hysteresis, while numeric increments
remain in explicit scene/display units. Geometry-aware snapping can arrive
after axis/grid manipulation without changing the command contract.

### Tactile feedback

Handles remain discoverable across camera distance, with bounded screen-space
sizes and hit regions. Show the active axis/plane, pivot, provisional pose,
snap target, and numeric delta. Convey depth through appropriate occlusion,
orientation cues, and reference geometry; color alone cannot identify axes.

The grabbed handle follows input immediately. Optional damping belongs to a
declared camera or presentation behavior, not hidden lag in object manipulation.
Retarget animations from their current presentation, stop idle work, respect
reduced motion, and cancel previews on Escape, capture loss, device loss,
target deletion, or conflicting edits. Physical vibration and force feedback
remain device-specific extensions with no effect on command correctness.

## Reusable component catalog

Compose useful pieces rather than require a monolithic editor shell:

- **View and navigation:** viewport, camera controller, orientation widget,
  axis/grid guides, fit controls, saved views, linked viewport group.
- **Scene presentation:** mesh/instance presenter, line/point batches, material
  binding, selection outline, bounds, visibility/isolation controls.
- **Manipulation:** axis/plane handles, rotation rings, scale cage, pivot editor,
  snap guides, placement preview, numeric transform editor.
- **Layout and relationships:** plane/grid/radial placement, object anchors,
  paths/connectors, label placement, and spatial value controls.
- **Inspection:** object tree, searchable selection list, property inspector,
  coordinate readout, resource/loading status, object tooltip.
- **Measurement and analysis:** marker, ruler, angle probe, slicing plane,
  clipping box, region selector, annotation, linked chart cursor.
- **Spatial UI:** screen overlay host, projected anchor, billboard label,
  planar component surface, focus/reveal affordance.
- **Time and computation:** playback/scrubber controls, time cursor, revision
  status, stale-result indicator, and cancellable computation binding.

The first consumer selects the initial subset. Every manipulable component
defines state ownership, constraints, command semantics, visual representation,
and accessible/numeric alternatives. One component state may drive different
representations in perspective and orthographic views.

## Keyboard, text input, and accessibility

Use the canvas plan's
[platform modifier policy](canvas-interaction.md#platform-modifier-policy):
Primary is Cmd on macOS and Ctrl on Windows/Linux. Resolve bindings and conflicts
per host; do not inherit literal Control or numeric-keypad requirements from
a reference tool. A future compatibility profile needs its own source and
native verification.

Use one navigable viewport focus entry, with explicit entry into object controls
and exit back to the surrounding UI. Navigation, camera control, object
manipulation, and text entry are distinct scopes. Menus, palettes, hints,
accessibility actions, and pointer affordances call the same commands.

Keyboard users must be able to select an object by name or hierarchy, reveal it,
choose a standard view, enter move/rotate/scale, choose an axis or plane, type a
value with units, preview, commit, cancel, and undo. Provide commands for changing
coordinate frame, pivot policy, and snap settings. Arrow behavior follows the
active scope and is shown locally; ordinary navigation must not accidentally
change scene geometry.

Ordinary text editors retain clipboard, cursor, selection, deletion, and IME
behavior. Do not assign bare letter tool shortcuts while an editor owns focus.
Escape cancels the innermost action; composition confirmation gets first refusal
before a transform commit. Repeated nudges coalesce into bounded history units.

Expose object names, roles, selection, hierarchy, available actions, and values
through native semantics and a searchable outline/inspector. Three-dimensional
positions need meaningful descriptions and numeric controls, not merely
projected bounding rectangles. Offscreen or occluded objects remain reachable
through intentional navigation without becoming accidental pointer targets.

Projected labels declare hide, fade, leader-line, or edge-indicator behavior.
Moving an object behind the camera must not produce invalid overlay coordinates.
World panels require an input mapping from hit position to local layout,
pointer capture beyond panel edges, focus continuity, and a screen-space route
for editing when perspective, distance, or occlusion makes text impractical.
Probe real IME and assistive technology; drawing controls on a texture alone
is insufficient. Fully occluded panels must not retain invisible click targets.

## Reactivity, computation, and resources

Separate changes to camera, pose, geometry, material, selection, and UI content.
Orbiting should not rebuild mesh data or ordinary controls. Moving an instance
updates its pose, bounds, and affected queries; changing a material should not
re-upload unchanged geometry. Shared selection updates relevant views without
creating camera or document feedback loops.

Use demand-driven frames while idle and explicitly scheduled frames during
animation, navigation, or simulation playback. The host owns pacing and
visibility suspension. Multiple viewports must not each start an unbounded
frame loop. Report CPU submission, GPU time, resource uploads, picking delay,
and input-to-presentation latency separately.

Long-running geometry or simulation work receives immutable inputs and revision
tags. Cancel superseded work where possible, reject stale output, and keep the
last valid result visibly identified while work runs. Fast preview quality and
final quality may differ, but the selected/editable geometry must be clear.
Playback state is separate from recorded document edits.

Use explicit resource lifetime and sharing. Probe resize, hide/show, viewport
disposal, device failure, and restoration without leaked buffers or invalid
in-flight references. Bound uploaded data and caches. Asset import, coordinate
conversion, geometry processing, and texture decoding are optional adapters;
start with generated fixtures so an asset pipeline does not block interaction.
Serialization stores application records and stable resource references, never
opaque renderer objects. Export formats are consumer requirements.

## Reference lessons

The following primary documentation was consulted on October 20, 2026 for
design comparisons, not as proof of native moxi behavior:

- [Three.js TransformControls](https://threejs.org/docs/pages/TransformControls.html)
  separates object transformation from camera controls and exposes axis,
  snapping, and transform modes.
  [OrbitControls](https://threejs.org/docs/pages/OrbitControls.html) illustrates
  pivot-based navigation and explicit damping. Preserve useful behaviors,
  while choosing moxi gesture ownership and platform bindings independently.
- [React Three Fiber events](https://r3f.docs.pmnd.rs/api/events) shows how
  ray-based events differ from ordinary 2D dispatch: events can reach multiple
  intersections, and capture adds a target to hit results. Moxi should define
  target priority and exclusive gesture ownership explicitly rather than
  importing these semantics by analogy with DOM events.
- [VTK.js widget architecture](https://kitware.github.io/vtk-js/docs/develop_widget.html)
  separates widget state, representation, and behavior and supports state
  shared across views. This is a useful model for manipulators and scientific
  probes; moxi should integrate them with its command/focus system rather than
  create an unrelated interaction manager for every domain.
- [Godot viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)
  illustrates render targets, multiple cameras, and input forwarding across
  viewport boundaries. Treat presentation and input mapping as separate
  obligations when embedding 3D output or displaying UI on a spatial surface.

## Proposed delivery gates

These are scope gates, not calendar commitments. Proposed tasks and source paths
do not exist yet. Keep broad exploration separate from the first useful release.

1. **S0: hosting and renderer decision.** Build `spatial-probe`: a depth-tested
   scene with a perspective/orthographic camera embedded beside normal moxi
   controls. Exercise resize, scrolling/clipping, overlays, focus, resource
   disposal, and camera input. Record color/alpha correctness, frame latency,
   idle behavior, build footprint, and any readback. Compare the existing-bridge
   route with one credible renderer adapter before selecting a production path.
   Freeze coordinate, frame-revision, and resource contracts from evidence.
2. **S1: useful reactive viewport.** Deliver a small geometry explorer with
   generated geometry, orbit/pan/fit, picking, selection, outline/inspector,
   projected annotation, and parameter-driven updates. Add `spatial-contract`
   for math, routing, and replay. Keyboard-only selection/navigation works;
   stale computation cannot replace current output.
3. **S2: precise manipulation.** Add constrained transforms, grid/angle snapping,
   numeric entry, preview/commit/cancel, and shared undo. Add
   `spatial-interaction` replay and native recordings. Include near-parallel
   constraints, camera changes, overlapping targets, and cancellation.
4. **S3: reuse across views and applications.** Add a small assembly inspector
   as a second consumer, with linked perspective/orthographic views, transform
   hierarchy, shared selection, a measurement probe, and a clipping plane.
   Both consumers use public APIs and share manipulation state machines.
   Compare glue, duplicated geometry, resource reuse, and update counters.
   This completes the initial desktop interaction scope.
5. **S4: world-space component experiment.** Mount a planar UI with text input,
   button, and slider. Verify ray-to-local mapping, perspective, occlusion,
   clipping, capture, focus, IME, and semantics. Compare the experience with a
   projected screen-space editor. Promote world panels only if the experiment
   produces a coherent, usable contract; S1–S3 can ship independently.
6. **Separate extensions.** Volumes, dense scientific data, advanced materials,
   asset pipelines, freeform modeling, simulation adapters, and XR each need
   their own consumer, ownership boundary, license review, and acceptance plan.
   No general physics engine, ECS, shader language, or collaborative scene
   protocol is required by this proposal.

Suggested implementation locations are `src/moxi_spatial/`, optional renderer
adapter modules, `examples/spatial_explorer.mojo`,
`examples/spatial_assembly.mojo`, and focused `tests/spatial_*.mojo` fixtures.
Package boundaries and dependencies follow S0; no exact API is frozen here.

## Validation and decision criteria

Headless checks cover projection/unprojection, transform composition, rays and
constraints, deterministic target priority, capture/cancellation, revision
rejection, history, and keyboard command parity. Test with tolerances and
adversarial geometry. A 2D software renderer is not automatically a 3D pixel
oracle: use numerical checks and a declared GPU/reference-image strategy, with
backend-specific differences reported.

Native checks cover layered viewport composition, device scale, text/IME,
screen readers, physical keyboards and trackpads, and focus transitions between
scene, world panels, inspectors, and menus. Use recordings to assess stable
grabs, snapping, camera orientation, and reduced motion. Synthetic events and
screenshots alone do not establish those qualities.

S0 records the baseline hardware and scenes. Initial targets are responsive
interaction at the host's 60 Hz presentation rate and no continuous frame
submission while fully idle. Report p50/p95/p99 and worst-case CPU/GPU/latency
separately; select numeric budgets and advertised capacities after the baseline.
Higher refresh rates require their own evidence.

Vary object count, triangle count, material count, annotations, viewport count,
and geometry-update rate independently. Include static-heavy scenes, many small
instances, one expensive mesh, and active native editors. Check that camera-only
frames perform no mesh rebuild/upload or unrelated UI-content rebuild, and
measure any necessary query/index updates separately.

The developer-facing gate is a small public consumer with no duplicate camera
math, hit testing, gesture state, or renderer lifetime bookkeeping. Inspect
compiler diagnostics and required glue alongside visual quality. A second
consumer validates the boundary more convincingly than a large showcase alone.

Confidence is high that desktop viewports, precise manipulation, and shared
commands fit moxi's purpose. Confidence is moderate in the proposed composition
boundary and low in any cost estimate for world-space native text or XR before
probes. Source inspection and primary documentation support this scope; no
renderer integration, native 3D probe, performance benchmark, or device trial
was run. S0 embedding failures, S3 consumer duplication, or S4 text/accessibility
failures would change the boundaries and delivery sequence.
