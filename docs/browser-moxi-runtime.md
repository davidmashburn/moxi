# Experimental Mojo/Moxi browser runtime

P01 now has a running local browser path through the existing Mojo FDG
application. Browser pointer/key/text/scroll/resize events enter
`App[GraphApp]`; Moxi dispatches them, builds controls, produces scene commands,
serializes SVG, and exports accessibility semantics. The existing
`native/hosts/moxi_web_host.mjs` presents both outputs. Two apps have independent
state and explicit teardown. No server or JavaScript solver participates in
immediate input.

The [executable recipe](../experiments/browser-moxi/README.md) and
[capture gallery](../artifacts/demo-slideshows/index.md) are the entry points.
This remains an opt-in experiment, not a supported general web package or a
replacement for the earlier standalone FDG solver probe.

## Supported experimental subset

| Boundary | Contract |
| --- | --- |
| Application | Existing FDG `GraphApp`, `Layout`, `App`, scene/SVG renderer and accessibility snapshot |
| Input | Single desktop pointer, drag/release/cancel, pan, wheel zoom, basic key/text editing, semantic actions, resize, frame ticks |
| Graphs | Sample graph or indexed graph input: up to 256 nodes and 1024 links; generated `node-N` IDs; nonnegative finite weights ≤1e6; bounded integral group/index fields |
| App surface | Width/height 320–4096 CSS pixels; finite event coordinates bounded to ±1e6; finite scalar value bounded to ±1000; modifier mask 0–15 |
| Text | UTF-8, at most 512 bytes per insertion and conservative 512-byte retained-query bound; replacement at the full bound may reject even if selection would make room |
| Lifetime | Up to 8 live apps per module; monotonic opaque signed-i64 handles, never reused; forged/stale handle rejection before dereferencing memory |
| Memory | Single-threaded, synchronous imports; checked aligned allocation/free, splitting/coalescing, a 64 MiB linear-memory ceiling; memory does not shrink after freeing |
| Errors | Invalid supported inputs return rejection. A trap or unsupported diagnostic import poisons the entire module, rejects reuse, and requires discarding/recreating it |
| Browser gate | Actual memory64 feature detection before compilation; clear failure if absent; no alternate graph implementation |

The host registry is trusted and private to each module instance. Handle
identities are scoped to that registry, not cross-module capabilities. The
supported JS owner validates graph data before synchronous imports expose it
to Mojo. `invoke` exists for ABI checks; arbitrary reentrant imports, malicious
Wasm modules, general foreign calls, and concurrent access are outside the
contract. A foreign exception cannot run Mojo destructors, so trap recovery
discards memory rather than claiming successful per-object cleanup.

Rendering uses the existing `scene_from_paint` projection plus the FDG graph
scene. It is a reduced SVG presentation: control labels and hit regions work,
but it does not reproduce native widget decoration, text-field chrome/caret,
or all native paint semantics. Search is exercised through real keyboard
events as well as UTF-8 bridge tests. IME, clipboard, mobile multitouch,
screen-reader usability, and full text-editing parity are not claimed. File
export returns unsupported or an explicit app message. File/network access,
async tasks, general exception formatting, and arbitrary application packages
are excluded.

## Toolchain feasibility and audit

Validated locally on Apple Silicon with Mojo `1.1.0 (8189361e)`, Apple Clang
`21.0.0 (clang-2100.3.34.2)` and LLD `24.0.0`. The direct
`wasm64-unknown-unknown` Mojo build fails with:

```text
could not construct host target info: No available targets are compatible with triple "wasm64-unknown-unknown"
```

The working route emits Apple-host LLVM IR, removes host target metadata and
unsupported optimization/lifetime hints, translates LLVM 24 floating-literal
syntax to LLVM 21, then compiles/links Wasm64. It preserves 64-bit pointer/Int
widths; it cannot reverse all compile-time host layout or ABI decisions.
Compiler versions fail closed, unknown runtime imports are rejected, and other
recognized architecture-specific intrinsics/inline assembly are rejected.
This is a bounded audit, not proof that arbitrary host IR is portable.

The app adds two requirements beyond the earlier solver probe. Mojo's UTF-8
validator emits AArch64 `TBL1`; the converter lowers that exact 16-byte lookup
to portable LLVM with zero for out-of-range indices, following the
[Arm intrinsic contract](https://documentation-service.arm.com/static/6245c734b059dc5ff9a8bdab).
An independent compiled test checks every byte index in every lane (4,096
cases). The wasm64 i128 multiplication helper writes a 128-bit result through
the ABI result pointer; 625 limb combinations test both halves. Rounded
Float32 literal conversion, rejecting host-specific operations and unknown
imports, and diagnostic poisoning also have focused checks.

Runtime imports are limited to allocation/free, local trigonometric/min/max
math, the i128 helper, registry/input/output bridges, and seven explicitly
unsupported diagnostic functions. Their exact linked list is recorded in the
evidence JSON. These error functions throw; they do not pretend to supply
stdio or a complete Mojo runtime.

## Verification and measured evidence

The native oracle directly instantiates `App[GraphApp]`, independently of the
Wasm exports. It records all 36 nodes' position/velocity/pin/screen coordinates,
app state, and initial/final SVG while stepping, dragging/releasing,
selecting, panning/cancelling, zooming, pausing/restarting, resizing, and
searching. Node and browsers replay the event fixture. This is app-level
parity, not a screenshot-only demonstration.

The 2026-11-06 run passed 6,371 numeric comparisons plus exact SVG text/structure
comparison. Solver fields use `1e-8` tolerance; screen/app and SVG numeric
fields use `0.001`. The largest observed absolute difference was `0.000200000000177`
in the Float32/render path. Invalid operations, forged and stale handles,
capacity rejection, empty and maximum graphs, two instances, 100
create/frame/render/dispose cycles, UTF-8 text, memory exhaustion, and the
forced unsupported gate passed. All 40,339 tracked allocations were freed in
the ordinary verification lifecycle; the exhausted module is deliberately
discarded. Maximum-graph SVG output was 226,761 bytes.

Validated engines: Node `26.10.0`, collaborative-preview Chromium `154`, and
local headless Chrome `156.0.8078.81`. Safari, Firefox, wasm32, alternate CPU/OS
toolchains, long sessions, and Jupyter/remote-kernel integration were not run.
The browser automation checks real pointer dragging, release, pan, wheel,
keyboard selection and typed search, Moxi controls, resize, isolated state,
accessibility-overlay removal, stale-handle rejection, and recreation. There
were no page exceptions. DOM semantics are inspected; no human screen-reader
or physical IME test was performed.

The application Wasm artifact is 533,498 bytes. The verification module reached
a heap high-water address of 5,687,760 bytes and 5,701,632 bytes of committed
linear memory. These are tracked Wasm figures, not browser process/JS/DOM/GPU
memory. Compilation/instantiation, layout+dispatch, scene+SVG serialization,
Wasm-to-JS string/semantics transfer, DOM submission, callback-to-next-animation
frame, and Chrome CPU paint events are recorded separately in
[evidence.json](../artifacts/demo-slideshows/browser-fdg/evidence.json).

These short diagnostic samples include warm/cached browser compilation and
coarse timer resolution; observed zero-duration samples do not imply zero
cost. Scene timing includes app paint/accessibility work. DOM submission is
not rasterization. Chrome trace `Paint` events measure CPU paint tasks, not
per-frame GPU completion or physical input-to-display latency; callback-to-RAF
also starts after browser input dispatch. No throughput, long-session,
cross-engine performance, or end-user latency claim follows from these samples.

## Remaining gates and integration

Confidence is **high** that this bounded FDG app executes real Moxi interaction
and rendering in the tested engines, supported by native parity and actual
browser input checks. Confidence is **moderate** that the retargeting route
extends safely beyond these fixtures. Additional application layouts, runtime
operations, compiler revisions or engines could invalidate that assessment.

An official portable Mojo target or a maintained compatible LLVM/runtime
toolchain, broader ABI/layout validation, native paint/text parity, full
runtime errors, accessibility/IME testing, broader browser coverage, and
real display-latency measurements remain gates to calling this a general web
target. P04 notebook lifecycle/transport integration remains separate work;
this module offers explicit create/dispose boundaries but does not implement
notebook comms or remote kernels. No P02 server transport changes are included.
