# D06: native geometry explorer (S1/S2)

An executable **experimental** consumer of the public `moxi_spatial` package.
Generated surfaces, camera navigation, selection, annotations and constrained
edits run in the actual Moxi AppKit host with the bounded Metal depth bridge.
This continues D05's experiment; it selects **no production renderer** and makes
no 60 Hz or input-to-photon acceptance claim. No SceneKit dependency is added.

```sh
bash examples/spatial-explorer/check.sh
./dist/spatial-explorer/explorer
# Or open the locally built app bundle:
open dist/MoxiSpatial.app
# Rebuild, exercise real native state, capture and generate this gallery only:
python3 examples/spatial-explorer/gallery.py
open artifacts/demo-slideshows/spatial-explorer/index.html
```

Requires macOS with its GUI session, Metal, Xcode command-line tools and the
repository's pinned Mojo environment (`pixi run` is used automatically). No
installation, signing, device configuration or independent spatial event loop.
The example owns the existing `MacOSWindowInstance` pump/wait loop. The public
package owns the bounded computation worker, not application scheduling.

## Public surface and ownership

`src/moxi_spatial` exports `SpatialViewport`, typed camera/object/point records,
tool/command/state/policy types, projected lines and anchors, and the move-only
`CompositionSurface`. The build emits `moxi_spatial.mojoc`,
`libmoxi_spatial.a`, `window.o`, and `text.o` under `dist/spatial-explorer`.
`tests/spatial/public_consumer.mojo` compiles from a clean temporary directory
with the precompiled package and those native link artifacts, without `src` or
the explorer host. `public_composition.mojo` separately demonstrates ordinary
Moxi window ownership with direct public copied-image composition. Neither
consumer implements camera math, hit tests, constraints, resource tables or a
parallel application loop. See `check.sh` for exact link arguments.

Mount a viewport to one live F02 owner, set its logical rectangle and backing
scale, route events, poll completion, render, then close before the window.
`render(image_slot)` binds the viewport's resource to that one image slot.
A different owner is rejected even after disposal. Create a new viewport for a
new window. The resource boundary in `native/macos_composition.h` copies bounded
premultiplied RGBA8 sRGB bytes; opaque spatial output has alpha one. It restores
the previously selected F02 context on every path. No private image registry
identity or Metal object escapes into Mojo.

Publication requires a strictly increasing serial. Composition retains the
published snapshot; publishing again does not mutate an already composed
frame. Release clears a draw slot only if it still contains this resource's
snapshot. Closing or destroying an owner immediately invalidates its tokens; weak-owner
retired slots are collected on the next composition call. Capacity is 32
resources, each at most two 2048×2048 snapshots (up to 32 MiB of pixel storage,
plus platform overhead). Explicit close releases promptly. Spatial sessions
are capped at 16; renderer targets and buffers are owned per session. All
public calls and native ownership are main-thread confined. The existing Metal
device/queue initialization remains process-wide in the isolated bridge TU;
link one bridge, not both this TU and a second `macos_metal.m` implementation.
This is copied-image composition, not a generic GPU interop API.

## State and frame agreement

- **Document:** stable nonzero object IDs, generated-shape parameter, positions,
  Z rotations, uniform scales and a bounded shared undo/redo history. Neutral
  object replacement validates all records atomically (maximum 16 instances).
- **View:** camera, projection and viewport/backing scale. Navigation, selection,
  tool choice and focus do not create document history.
- **Gesture:** frozen object transform, pivot, constraint anchor and document,
  geometry, camera, viewport and generation revisions. Preview is separate from
  committed document state. A geometry/camera/viewport change, capture or focus
  loss, Escape, selection/tool change, or disposal cancels the preview.
- **Derived:** accepted mesh, world triangles, vertex colors, projection matrix,
  screen handles, anchor visibility, retained Metal buffer and published image.
  A render freezes the whole revision tuple, camera and viewport; publication
  requires that exact tuple. The example publishes each dispatched event before
  routing the next. Worker completion is polled on the UI thread, never applied
  concurrently to an in-flight frame. Rendering, picking and annotation tests
  use the same accepted geometry and camera. Camera frames update matrices and
  screen overlays without rebuilding/uploading vertices or unrelated controls.

The worker accepts immutable generation/revision/parameter requests, with one
active job, one latest pending request and one latest completed result. There
is no unbounded queue. Parameter changes generate actual vertices asynchronously;
the optional 700 ms demonstration delay occurs on the worker. Navigation stays
available using the last accepted mesh. Requested and displayed parameters are
both visible. Stale generations or revisions are rejected before publication.
A transform while work is pending also invalidates and reschedules the request.
The fixed generator emits 4,560 expanded vertices per surface; the general
session bound is 100,000 vertices. Destruction interrupts the artificial delay
and joins bounded work. There is no arbitrary user job executor in this stage.

## Coordinates, picking and operations

World space is right-handed, +Y up; the camera looks along local -Z. Angles are
radians; transforms bake object-to-world vertices. Matrices are column-major,
column vectors, projection × view, with Metal depth [0,1]. Perspective is 45°
vertical FOV, near/far 0.1/100. Orthographic half-height is
`distance * tan(22.5°)`. Window coordinates are top-left logical points, +Y down;
render dimensions round logical size × backing scale. Camera pitch is bounded
to ±1.4, distance to [0.5,60], positions to radius 20 and scales to [0.1,5].
The demo has a fixed 1100×760 window; the public viewport supports validated
resizing up to 2048 device pixels per dimension.

Triangle picking is two-sided, rejects degenerate/behind-ray intersections,
selects the nearest hit, and breaks distance ties within 1e-7 of the global nearest hit by lowest stable
ID. Projected tool handles have an 8-point hit tolerance and precedence over
scene triangles; ordinary controls/numeric focus take precedence over viewport
routing. Outside the active handle, a transform tool still selects geometry.
Axis constraints use closest ray/axis points; plane constraints use ray/plane
intersection. Near-parallel constraints reject the sample (1e-5 denominator
threshold) without an unstable fallback. An invalid move retains the previous
valid preview; cancellation restores the committed transform.

X/Y/Z axes, XY/XZ/YZ planes, a Z rotation ring and uniform scale are bounded S2
operations, not a general CAD system. Pointer, numeric and keyboard routes use
one `Operation` validator and preview/commit path. Translation snap rounds the
delta to 0.25 units, angle snap to 15°, scale factor snap to 0.1. One completed
gesture adds one history entry; rejected, canceled and no-op operations add
none. History stores at most 64 document snapshots and includes parameters and
object replacement. There is no history entry for view changes.

The golden bounding outline is conservative (local ±1.13 encloses every allowed
generated radius); handles, outline and decorative floor lines are explicitly
always-on-top screen overlays. Projected annotations support `HIDE_OCCLUDED`
and `ALWAYS_VISIBLE`; both hide anchors behind the near plane, beyond the far
plane or offscreen. Hidden-occluded anchors use the same triangle rays with a
1e-4 world-distance tolerance. No leader-line layout, label collision solver,
world-space UI or depth-tested overlay claim. The demo's annotation is a fixed
world marker, not a computed surface measurement.

## Interaction

Orbit/Pan/Select choose navigation or picking. Drag the visible active handle
to preview a constrained edit and release to commit. Shift-drag in Orbit pans;
wheel or +/- dollies; Fit frames all committed objects. The outline selects the
same stable IDs as triangle picking. The inspector shows preview position,
angle and scale (readouts truncated to three decimals). The numeric field
accepts a translation delta, rotation delta in radians or scale factor. Invalid
text/NaN/out-of-bounds edits are rejected; Apply or Enter uses the same operation
path. Plane numeric entry changes the first component; keyboard Up/Down changes
the second component.

Tab/Shift-Tab cycles controls, Enter activates, V focuses the viewport, N selects
the next object, O/P/S select tools, F fits. With viewport focus, arrows navigate
or edit the selected constraint. Escape cancels a preview. Cmd-Z / Shift-Cmd-Z
undo/redo the shared document. Focus/capture loss and resize also cancel. Native
text editing uses the existing AppKit editor; the replay drives its callback,
not a physical IME session.

Dispose removes the viewport image and input capture while retaining document,
history and camera. Recreate uses a new generation and requests geometry again.
Unsupported creation and render failure have explicit states and show an
unavailable/retry UI. Invalid inputs return failure without a hidden fallback.
Destroyed owners cannot be rebound to new windows. Empty object lists render
an empty scene and clear selection. No fault-injection toggle is exposed in the
normal UI; unsupported/failure/empty cases are tested at the public boundary.

## Verification and remaining gates

`check.sh` runs portable spatial-contract/spatial-interaction tests (independent
numeric projection/ray expectations; adversarial and overlapping triangles;
all pointer constraints; frozen frame agreement; routing; snapping; history;
work rejection; cancellation; disposal/recreation), native composition/F02/Metal
assertions, a clean packaged consumer, and the public Mojo composition consumer.
Logs: `/tmp/moxi-d06-{build,contract,native,consumer,public-composition}.log`.

Additional local checks used for this implementation:

```sh
clang++ -std=c++20 -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer \
  native/spatial/core.cpp tests/spatial/contract.cpp -o /tmp/moxi-d06-contract-sanitized
/tmp/moxi-d06-contract-sanitized > /tmp/moxi-d06-sanitizers.log 2>&1
pixi run bash scripts/native_lifecycle_check.sh > /tmp/moxi-d06-f02-regression.log 2>&1
```

The gallery recipe drives real AppKit pointer/focus callbacks, the host key event queue and public module. It also
checks capture/focus/resize cancellation and camera-only/idle counters. All 17
PNG captures use AppKit `cacheDisplay` and are correctly marked
**offscreen-render**, not compositor/native-window evidence. PNGs and generated
HTML are ignored local artifacts. The compact manifest, source provenance and
timing JSON are in this demo's own gallery folder. The recipe does not edit the
master gallery/index or planning history. Provenance records HEAD plus scoped
uncommitted source status, per-source hashes, executable hash and PNG hashes.

`timing.json` records all 60 camera samples and p50/p95/p99/worst in milliseconds:
process CPU, encode wall time, command wait, GPU command timestamps, readback,
publication, and frame-to-host-image total. The ranges overlap: CPU is process
CPU, GPU timing is device command duration, and wait includes queue/sync time.
Publication includes the copied image and composition, not AppKit presentation.
Total ends before end-frame/compositor/scanout. p99 is the maximum with only 60
samples. Camera uploads/derived rebuilds/control rebuilds and idle submissions
are asserted zero. These bounded samples do not reverse D05's performance gate
or support a production 60 Hz claim.

Confidence is high for the exercised local contracts, limited for sustained
performance or general-purpose spatial applications. A second public consumer,
sustained compositor measurements, hardware input and human accessibility
acceptance could change that assessment. Physical mouse/keyboard/IME,
independent human usability, screen-reader behavior, other platforms, full CI,
GPU/native sanitizers, thermal runs and input-to-photon latency were **not**
verified. VoiceOver remains paused. D03 canvas integration and D07 hierarchy,
linked views, measurements and clipping are outside this change; neutral IDs,
records and public lifetime seams are available without a premature framework.
