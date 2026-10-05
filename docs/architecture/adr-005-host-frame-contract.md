# ADR-005: Separate native hosting from portable frame publication

Status: accepted for the current desktop slice.

## Decision

`WindowBackend` is the authoritative host lifecycle contract. It owns opening,
event pumping, normalized event delivery, monotonic time, deadline waits, logical
size/device scale, accessibility publication, presentation and closing.
`FrameHost` is its publication facet. `PlatformAdapter` remains a compatibility
model for portable surface/configuration tests; its contract backend does not
create a native window or supply OS events.

`FramePacket` contains logical surface metrics, invalidation, ordered
`PaintCommand` values, an optional `Scene` projection, paragraph resource
identities and an `AccessibilitySnapshot`. The packet imports no native host,
FFI or toolkit types. `PaintCommand` and `Scene` remain separate projections:
the scene is inserted at the selected canvas command, preserving popup order.

The host owns presentation. `submit_frame()` renders paint invalidations,
publishes semantics, then asks the host to present. An accessibility-only
invalidation publishes semantics without rendering or presenting. A failed
render or semantic publication prevents presentation. This resolves the
planning document's inconsistent assignment of `present()` to both the host
and renderer. Native rendering may prepare toolkit drawing state; it must not
silently finish a frame while updating accessibility.

`HostCapabilities` describes implemented window/input/clipboard/accessibility
services. `RendererCapabilities` describes implemented text, clipping,
incremental and GPU behavior. Neither record certifies a working display,
installed dependencies or acceptance checks. The old combined
`BackendCapabilities` remains for source compatibility.

## Resource ownership

The retained engine, flow/grid layout, focus and editor state remain in Mojo.
Kiwi remains the C++ constraint solver. CoreText and Pango remain native text
services. A native paragraph is measured once and pinned in the renderer's
resource cache before its frame is submitted. Packets carry retained keys,
mount identities, command indexes and publication generations rather than
native pointers. The renderer rejects retired, unbound, mismatched, duplicate
or stale bindings before starting paint.

These identities are scoped to one retained producer and its bound renderer.
They are not global IDs across applications, windows or producers. The current
native C hosts expose one window per process; multi-window surface IDs and
resource sharing require a separate extension. The provisional retained
snapshot and resource-binding adapter still own native paragraph payloads;
they are not the portable packet API.

## Scheduling and compatibility

The shared `App` drivers drain normalized events, advance tasks and requests
using elapsed monotonic time, render invalidations, then wait for the earliest
input/task/animation deadline. Animations explicitly request frame ticks;
ordinary input wakes do not introduce extra animation ticks. Framework work
is subtracted from the next deadline. Idle native hosts block on their event
source, while the portable fallback waits in bounded slices.

The standalone `NativeWindow.run()` helper also drains input before waiting;
it keeps the host responsive but does not dispatch application updates. Live
AppKit frame publication draws and flushes the current transaction before the
host can enter an indefinite idle wait.
Normalized input enqueued by asynchronous AppKit accessibility callbacks wakes
the native wait without requiring an unrelated keyboard or pointer event.

The canonical workbench uses `WorkbenchController`, `FramePacket` and
`NativeFrameRenderer`; its replay and benchmark use the same controller and
chart projection. Existing `Renderer` consumers retain their API with an
explicit `end_frame()` boundary. Their `App` driver has the same scheduling and
independent semantic update behavior; migration of every legacy demo to the
packet API is not a prerequisite for the desktop slice.

GTK4 is the current Linux host substrate because input-method and desktop
accessibility transport are part of this slice. Cairo produces pixels and
Pango produces measured text. GTK does not own Moxi layout or application
state. SDL, alternate GPU renderers and additional OS hosts remain independent
future adapters, rather than reasons to replace the working host during this
contract change.

## Evidence and limits

- `tests/frame_packet.mojo` checks portable publication order, semantic-only
  updates, metrics and rejection paths.
- `tests/frame_driver.mojo` checks due tasks/requests, animation cadence, idle
  waits, semantic-only updates and bounded clipped repainting.
- `tests/event_replay.mojo` checks exact normalized payload serialization,
  Unicode and bounded malformed-input rejection.
- `tests/layout_workbench_replay.mojo` checks the shared form/collection/modal
  controller, semantics, paragraph identities, clipboard routing and the exact
  software chart checksum.
- `tests/native_frame.mojo` checks native resource leases independently of a
  visible window. The native accessibility ABI check proves semantic publication
  does not implicitly present a frame.
- `tests/native_window_run.mojo` uses a bounded C event source to check both
  native aliases for queue draining, idle waits and close handling.
- `native/tests/macos_frame_test.m` checks initial and subsequent live-window
  painting before idle using the original AppKit canvas.
- `native/tests/macos_wait_test.m` checks idle wake-up for actual AX callbacks,
  addressed Unicode edits and asynchronous window closure, with a bounded
  fallback that fails the test if used.

Build, replay, GUI, real IME, external accessibility and performance observations
are recorded separately in [VM validation](../vm-validation.md). Physical input,
VoiceOver and Wayland acceptance are not inferred from these automated contracts.

The source plan on `project-planning` is a proposal at its recorded October 4
baseline. This ADR records the implemented decisions without rewriting that
independent planning branch.
