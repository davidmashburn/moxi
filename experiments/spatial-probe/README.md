# Spatial S0: executable hosting and renderer comparison

D05 only. Run the actual Moxi AppKit host with a depth-tested Metal viewport
beside ordinary Moxi buttons. Switch between a bounded extension of the existing
Metal bridge and an optional SceneKit adapter. Neither changes the shipping
renderer, adds a package dependency, nor implements spatial S1–S4.

```sh
bash experiments/spatial-probe/build.sh comparison
./dist/spatial-probe/comparison
# Optional adapter entirely excluded from this binary/link graph:
bash experiments/spatial-probe/build.sh bridge
./dist/spatial-probe/bridge
# Focused assertions, measurements, genuine captures and offline slideshow:
python3 experiments/spatial-probe/gallery.py
open artifacts/demo-slideshows/spatial-probe/index.html
```

Requires macOS, its GUI session, Metal hardware and Xcode command-line tools.
No Mojo toolchain is needed: the executable directly uses the same native Moxi
host as Mojo consumers. Builds use ARC, optimization and warnings-as-errors;
SceneKit deprecation warnings alone are suppressed. Build/replay logs are under
`/tmp/d05-*.log` (override the prefix with `MOXI_SPATIAL_LOG_PREFIX`). The gallery builder has a 180-second subprocess timeout.

Drag in the viewport to orbit, Shift-drag to pan, wheel to dolly, Shift-wheel to
scroll the clipped image. Tab/Shift-Tab moves focus through the six surrounding
controls and viewport; Enter activates a focused control. Arrow keys orbit only
with viewport focus; +/- dolly. Escape, host focus loss, resize and disposal end
a camera drag. Navigation is view state; ending a drag retains its camera. The
screen overlay resets the camera and intercepts pointer input. All controls use
Moxi native draw commands; this is not a web UI or a separate SceneKit window.

## Decision and confidence

**Keep this as an executable experiment; select no production rendering path.**
The common CPU-image embedding path correctly supports depth, camera changes,
clipping, ordinary overlays, owner isolation and lifecycle in this fixture.
Confidence is high for those tested properties, moderate for choosing the
bounded bridge extension for further local probes, and low for extrapolating
performance to a production scene renderer. Current evidence does not meet a
60 Hz end-to-end presentation gate at the larger measured viewport.

Both candidates execute on the real Metal device and queue initialized by
`native/macos_metal.m`. `renderer.m` includes that source in an isolated translation
unit and adds its own mesh/depth pipelines and per-instance targets. This tests
an extension of the existing route, not the unchanged 2D shader as if it already
supported depth. SceneKit uses `SCNRenderer` to encode into the same target type
and completed command-buffer/readback boundary. Both have exactly the same
host embedding and color conversion costs. This is not a zero-copy comparison.

[Apple marks SceneKit deprecated](https://developer.apple.com/documentation/scenekit/scnrenderer).
It is a credible native renderer comparator, but not a recommended new production
dependency. The adapter adds only an Apple system framework; no vendored assets,
material compiler, codecs, package installs or third-party license payload are
included. Both binaries inherit the existing Moxi bridge's system frameworks
and process-wide initialization cost. Binary size is **not** total resident or
installed framework size. Apple SDK/framework distribution terms still apply.

A public per-window compositable GPU resource interface, sustained presentation
measurements and a maintained renderer candidate would change the production
assessment. Do not promote this experiment's private host-image injection or
shared bridge device ownership into a public API by copying it unchanged.

## Frozen experiment contracts

- World coordinates: right-handed, +Y up, camera looks along local -Z; arbitrary
  world units. Column vectors, column-major matrices, `projection * view * model`.
  Fixture vertices contain baked object-to-world transforms. Camera yaw/pitch are
  radians; pitch clamps to ±1.4, distance to [2, 40]. Viewport geometry is planar
  triangles; no transform hierarchy, quaternions, picking or manipulation API.
- Perspective has 45° vertical FOV; orthographic half-height is
  `distance * tan(22.5°)`. Near/far are 0.1/100. Bridge clip depth is [0,1].
  SceneKit receives the same camera parameters through its native camera API;
  its projection internals stay in the adapter. Two-camera, non-square raw image
  comparisons verify that boundary. A trial custom projection matrix failed
  orthographic output; it is not the shipped adapter path.
- Window/viewport coordinates are top-left logical points, +Y down; device
  dimensions round logical size times actual `backingScaleFactor`. The stored
  image is top-row-first RGBA8, tagged sRGB. Host scrolling changes its window
  placement and clip, not the scene camera. The observed capture scale is in the
  manifest; other scale factors are unverified.
- Vertex colors and render-pass clear RGB are linear. The sRGB target stores
  encoded **linear-premultiplied** clear RGB. Readback converts partially
  transparent pixels to encoded-premultiplied sRGB before AppKit source-over.
  The fixture has opaque mesh faces and a half-alpha background. Independent
  expected center/background byte checks exercise color and alpha; they do not
  establish correct sorted transparent geometry, HDR or every display profile.
  Calibration reads raw tagged bytes: `colorAtX:` returned a device-color value
  on this host and would have introduced an extra color-space interpretation.
- Every frame carries scene, camera, geometry, viewport and resource-generation
  revisions. Publication requires all five to match; disposal or recreation
  invalidates earlier generations. Invalid sizes/cameras return no frame, clear
  current displayed content and leave ordinary UI usable. The replay explicitly
  rejects an old frame after disposal and recreation. This synchronous probe
  does not claim an exercised asynchronous render/pick pipeline.
- Per-renderer ARC ownership covers its pipeline, vertex buffer, depth/color
  targets, SceneKit scene/camera and CPU image. Work completes before readback or
  replacement. F02's explicit window handle selects every host publication;
  the same image ID in two owners refers to distinct images. The private
  in-memory resource-table access is confined to `probe.m`. Old renderer weak
  references clear after disposal. The bridge device/queue and its existing
  global caches remain process-owned until exit; full bridge teardown, concurrent
  rendering and independent per-window GPU queues are not claimed.
- Target cap: 2048×2048 device pixels. Geometry bounds: 1–256 cubes, 1–128
  triangle repetitions per cube; unsupported inputs fail. Those are defensive
  bounds, not measured production capacities. One fixture material with per-face
  colors, no MSAA, no lighting engine (flat face shading), no textures/shadows/PBR.
  Camera-only renders do not rebuild/upload geometry. Moxi host draw commands
  are reissued on a changed frame; unrelated UI-content rebuild elimination
  remains an open optimization gate.

## Evidence and its limits

[Measurements](../../artifacts/demo-slideshows/spatial-probe/measurements.json)
record hardware, raw calibration, comparison, idle and per-case distributions.
[Provenance](../../artifacts/demo-slideshows/spatial-probe/provenance.json) records
base commit, a hash of all compiled/capture source inputs, individual hashes,
compiler/SDK, binary bytes/hashes, link graph and measured build wall time. The
source fingerprint and scoped working-tree status distinguish committed captures
from captures containing local changes.

Each renderer is measured for 60 warmed camera-changing frames after one
separately reported cold frame. Cases vary 256 vs 768 square pixels, 2 vs 64
concatenated cube objects, 24 vs 3,072 triangles (duplicate-triangle overdraw),
and static vs per-frame geometry replacement. The mesh-heavy case is explicitly
synthetic overdraw, not evidence for a complex imported mesh. CPU process time
includes harness overhead and geometry updates; encoding, completion wait,
texture `getBytes`, alpha conversion, geometry updates and total frame-to-CPU-image
are separately labeled wall times. GPU time is
[completed-command-buffer GPU end minus start](https://developer.apple.com/documentation/metal/mtlcommandbuffer/gpustarttime).
Unavailable GPU timings stay unavailable. Nearest-rank p99 over 60 samples is
coarse and equals the maximum. Samples are sequential, not a controlled thermal
or power benchmark.

Frame-to-image excludes host publication, window-server composition and display
scanout. The replay includes one explicitly labeled host-publication wall sample;
it is not an input-to-photon measurement. Idle checks run each visible candidate
for 0.3 seconds and count adapter submissions, with whole-process CPU time kept
separate. Zero adapter submissions does not prove zero driver/compositor work.
No continuous animation timer is installed; interactive idle blocks on the host.

Executable assertions cover depth independent of submission order, both cameras,
independent expected color/alpha values, non-square candidate agreement, invalid
bounds/nonfinite camera rejection, retained mesh during navigation, overlay input
priority, clip/overlay pixels, focus scoping and cancellation, target resize,
stale generation rejection, release/recreate, and F02 image/event isolation.

Remaining gates: physical keyboard/trackpad and compositor/scanout measurement;
VoiceOver (paused); full color-management/display-profile QA; high-DPI changes
while moving between displays; long-duration leak/idle/thermal tests; complete
maximum-capacity stress; independently varied material count, annotations, real
instancing/one expensive mesh, active native text editors and concurrent viewport
throughput; production zero-copy composition/resource API; maintained portable
renderer and non-macOS host validation. Screenshots do not close these gates.

## Parent integration evidence

The integrated source at `c228b15` was rebuilt and replayed on November 6, 2026.
Both bridge-only and comparison binaries passed the contracts above. The parent
reviewed all 15 fresh content-view captures; all 30 slideshow/contact-sheet images
loaded and first/next/previous/last/wrap navigation passed. All nine gallery
manifests validated. Ten source-file hashes, two executable hashes and 15 PNG
hashes match the recorded provenance; compiled capture sources were clean.

The integrated run recorded worst 768-pixel frame-to-CPU-image p95 values of
25.21 ms for the bridge and 34.69 ms for SceneKit. Other implementation workers
were active, so this is not a controlled performance comparison. The initial
worker run also exceeded 16.67 ms at that size. These observations reinforce the
need for presentation-inclusive measurements before selecting a production path.
The non-square perspective and orthographic comparisons each had zero pixels
differing by more than two byte values. Both candidates submitted zero adapter
frames in their 0.3-second idle intervals.

Parent logs: `/tmp/moxi-d05-parent-gallery.log`,
`/tmp/moxi-d05-parent-replay.log`, and
`/tmp/moxi-d05-parent-bridge-only.log`. The comparison includes fresh F02 owner
isolation assertions. The unchanged full Mojo lifecycle suite, API inventory,
shared gallery unit tests, full repository suite, sanitizers and remote CI were
not rerun for this isolated experiment. Physical input, compositor behavior and
other acceptance gates listed above remain unverified; VoiceOver remains paused.
