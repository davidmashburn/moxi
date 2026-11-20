# Browser API usability

Status: proposed; implementation is not authorized by this planning update.
Observed November 20, 2026 against published `main`
`b99d9f2cc89e16e456ec467916d63589f2f6046a`.

## Intent and first deliverable

Make a Moxi application useful as an embedded interactive surface in an ordinary
web page: authors write a Mojo application, build its Wasm module, and mount it
without copying the FDG demo's event translation and teardown code. Preserve
local Mojo interaction and the existing bounded runtime safety contract.

The first deliverable is an explicitly experimental browser API demonstrated by
both FDG and a small application using the existing `moxi.authoring` API. It is
not a general supported web target. Success means the second application needs
only application-specific Mojo setup, declared capabilities and normal page
mount/unmount calls; no edits to the shared JS runtime or host.

This extends [browser execution](browser-execution.md). It does not depend on
[server-backed views](server-backed-views.md) or
[Jupyter integration](jupyter-integration.md), and does not reopen their work.

## Current behavior and evidence

Source links below are pinned to the inspected implementation revision:

- [Mojo bridge](https://github.com/davidmashburn/moxi/blob/b99d9f2cc89e16e456ec467916d63589f2f6046a/experiments/browser-moxi/browser.mojo):
  `BrowserState` owns `App[GraphApp]`; creation imports graph input, dispatch uses
  `dispatch_graph_event`, and rendering combines control paint with graph scene
  commands. This is a real application path, but not a generic component adapter.
- [JS runtime](https://github.com/davidmashburn/moxi/blob/b99d9f2cc89e16e456ec467916d63589f2f6046a/experiments/browser-moxi/runtime.mjs):
  `instantiateMoxi(bytes)` returns `create`, `stats` and `dispose`; app owners
  expose `event`, `text`, `resize`, `render`, `inspect` and `dispose`. Graph input,
  control IDs and inspection fields are mixed with reusable runtime machinery.
- [Mounting code](https://github.com/davidmashburn/moxi/blob/b99d9f2cc89e16e456ec467916d63589f2f6046a/experiments/browser-moxi/demo.mjs):
  explicitly maps keys and wheel units, forwards text, schedules frames, presents
  SVG and semantics, and separately cleans up host listeners and app ownership.
- [Web host](https://github.com/davidmashburn/moxi/blob/b99d9f2cc89e16e456ec467916d63589f2f6046a/native/hosts/moxi_web_host.mjs)
  already owns much of browser input, resize, presentation and listener teardown.
  Reuse it rather than creating a competing host abstraction.
- [Counter model](https://github.com/davidmashburn/moxi/blob/b99d9f2cc89e16e456ec467916d63589f2f6046a/src/moxi_demo/authoring_examples/counter.mojo)
  demonstrates `Screen`, `UI[Self]`, labels and method-bound buttons. Its current
  native/headless availability does not prove browser compilation or rendering.
- [Runtime contract and recorded checks](https://github.com/davidmashburn/moxi/blob/b99d9f2cc89e16e456ec467916d63589f2f6046a/docs/browser-moxi-runtime.md)
  establish a bounded FDG experiment with native parity and browser interaction
  evidence. They explicitly exclude general application packages, full text
  editing, broader engines and long-session guarantees.

This planning pass inspected source and existing evidence; it ran no application,
compiler, browser, performance or human-accessibility checks. Unrelated dirty
implementation files concern other demos and are not inputs to this proposal.

## Proposed public surface

Illustrative API, not available today (`controller` is an optional caller-owned
`AbortController`):

```js
import { mountMoxi } from './moxi-browser.mjs';

const view = await mountMoxi(document.querySelector('#simulation'), {
  module: './simulation.wasm',
  initial: simulationInput,
  signal: controller.signal, // optional AbortSignal for pending startup
  onError(error) { showFailure(error.message); },
});

// The mount owns input, resize, presentation and scheduling.
// Teardown is explicit and idempotent.
view.dispose();
```

`module` selects one already-compiled application, not an arbitrary Mojo type at
runtime. `initial` is optional application input validated by that application's
adapter. No graph schema or FDG action IDs belong in the shared mount API. Keep
low-level creation/event APIs available for tests and advanced hosts, but ordinary
embedding must not require them. Defer a broader command/subscription API until
one of the two consumers needs it.

An internally created runtime is owned and destroyed by the mount. An optional
advanced shared-runtime path must make ownership explicit: disposing a mount
releases only its app and host; disposing the runtime invalidates all its apps.
Do not introduce that path merely to shorten the first implementation.

## Implementation slices and acceptance

### 1. Separate application policy from the bounded runtime

- Define a minimal compile-time Mojo application adapter around creation, event
  dispatch, paint/scene projection and semantics. Start with the existing
  `App[Component]` and `HandlerHost` seams; do not redesign Moxi authoring.
- Produce one Wasm module per application with the same common lifecycle ABI.
  Keep FDG graph import, commands and inspection in its adapter. Move reusable
  allocation, handles and host transfer code into a shared browser support area.
- Specify how `initial` crosses the boundary before freezing the API: use a
  bounded input transfer contract or an explicit application-owned host adapter,
  validated before mutation. Prove it with FDG graph input and Counter startup;
  no arbitrary imports or assumed JSON support. Record the encoding/schema,
  limits and compatibility behavior with the versioned ABI.
- Version the common ABI and declare capabilities/limits. Validate required
  exports, version and capabilities before creating an app; give mismatched
  modules an actionable error. Preserve existing wire values and rejection
  behavior. Use named types/constants for finite protocol states and choices.
- Parameterize the pinned build recipe for an application entrypoint and output
  directory. Retain compiler-version checks, import allowlisting and IR audit;
  do not imply arbitrary Mojo dependencies become portable automatically.

Acceptance: FDG still passes its independent native/Wasm parity and lifecycle
checks after extraction. The authoring Counter compiles through the same recipe,
executes its normal button method, and renders without graph-specific imports or
changes to shared runtime code. If `HandlerHost` cannot cross this boundary,
record the concrete compiler/runtime blocker before inventing a new UI API.

### 2. Own the browser lifecycle in one mount layer

- Build `mountMoxi` on `MoxiWebHost`. Centralize pointer, wheel, modifier and key
  translation plus the currently supported basic text path. Avoid duplicate text
  delivery, preserve focus and prevent default only for handled input.
- Accept an optional `AbortSignal` for cancellation while startup is pending;
  reject an aborted mount and release resources even if compilation completes
  later. Once resolved, `dispose()` owns teardown. No view handle exists before
  the mount promise resolves.
- Own DOM children, semantics, resize observation, animation callbacks, listeners
  and app teardown. Never remove unrelated page children or handlers. On failed
  fetch, instantiation or partial mount, release every acquired resource.
- Keep CSS and logical coordinates consistent under resize and device scale.
  Handle hidden/zero-sized targets by deferring layout; report unsupported sizes
  explicitly rather than silently mismatching the hit-test and visible surfaces.
- Render on input/state invalidation; schedule frame ticks only for applications
  that request animation. Pause work when hidden and resume without a large
  accumulated timestep. Export enough invalidation/animation state to support
  this, rather than reading FDG's `paused` or `alpha` fields in shared JS.
- Report startup failures through the rejected mount promise; report later
  failures once through `onError` and stop dispatch. Preserve module-wide trap
  poisoning and require a fresh module after a trap. Teardown must still release
  host resources when Mojo object destruction is no longer safe.

Acceptance: the FDG page uses the shared mount path without a hand-written key
map, text listener, frame loop or cleanup routine. Counter uses that same path.
Repeated mount/dispose, failed startup and cancellation during startup leave
no live app, observer, listener, animation callback or stale semantics owned by
the mount. Two surfaces retain independent focus, state and teardown behavior.

### 3. Publish an honest experimental authoring path

- Add a minimal example and build/run guide beside implementation code. Show the
  Mojo model, adapter entrypoint, module build and page mount together. Keep the
  application-specific seam visible; do not hide it behind an FDG-specific demo.
- Publish supported input, rendering, runtime and browser capabilities, including
  missing native widget chrome/caret and unavailable operations. Capability
  errors must be explicit and must not substitute a different implementation.
- Keep SVG as the initial renderer. Describe semantics as an accessibility
  projection, not proof of screen-reader usability. Preserve the existing FDG
  experiment's runnable entrypoint or document a deliberate migration.

Acceptance: from a documented clean environment, build and run both examples
without modifying shared host/runtime files. A small Counter method/label edit
rebuilds and appears in the browser. Record an independent authoring exercise
when available; an agent following the guide does not establish human comfort.

## Verification contract

| Scenario | Required evidence |
| --- | --- |
| FDG regression | Existing native oracle comparisons, graph limits, invalid input, stale handles, allocator and poisoning checks pass against extracted code. |
| Second application | Real pointer and keyboard activation update the shared Counter model; native/headless expected count matches browser output. |
| Embedding | Two simultaneous surfaces; state independence; resize, scroll, device scale and narrow supported viewport hit testing; surrounding HTML remains usable. |
| Scheduling | Idle app produces no continuous frame/render work; animated FDG advances; hidden/resumed surfaces behave correctly. |
| Lifecycle and failure | Repeat mount/interact/dispose cycles; double dispose; detach then explicit dispose; startup cancellation; missing asset, wrong ABI, unsupported memory64, rejected input and module trap. No stale callbacks or owned DOM remain. |
| Text boundary | Basic text, deletion, selection and modifiers work only as declared; composition/clipboard gaps are visible and never advertised as supported. |
| Reproducibility | Clean pinned build, source/artifact hashes, browser/version, viewport, steps, expected/observed result and capture time in a reusable verification record. |

Reuse existing Node and browser harnesses; add regression checks for ownership,
ABI compatibility and behavior that the new abstraction changes. Preserve
independent literal wire-value checks at the ABI boundary. Exercise actual
browser flows after the final code change, including failed startup and remount.
Capture relevant UI states and errors with synthetic data. Report tests not run,
blocked environments and any mismatch between running code and inspected source.
Do not treat successful compilation or screenshots alone as interaction proof.

Collect startup, Wasm size, tracked memory, dispatch/scene/transfer/DOM submission
costs separately for both apps; compare FDG before/after under the same conditions.
Record regressions and resolve material ones before extraction is accepted. Do
not claim universal throughput or physical display latency from short samples.

## Separate support gates and non-goals

A nicer mount API does not repair the experimental compiler route. Keep fail-closed
retargeting until an official portable target or maintained compatible toolchain
passes both app suites and runtime audits. Newly imported operations or host ABI
assumptions require additional validation, not an expanded allowlist by default.

Full IME/composition, clipboard, caret/selection appearance, mobile multitouch and
native paint parity need their own input/presentation work and acceptance. Test
other browser engines by capability and actual behavior before advertising
support. Long-session memory, sustained rendering and human accessibility remain
open. VoiceOver remains paused; this plan does not resume it.

No React/Vue wrapper, server transport, notebook adapter, remote kernel, arbitrary
package loader, dynamic Mojo compiler, GPU renderer rewrite or framework-wide
layout redesign is included in these slices.

Confidence is high that the current duplication and FDG coupling are concrete
usability barriers, based on the inspected bridge and mount code. Confidence is
moderate that these slices suffice for a useful second consumer: a failure to
compile/render the existing authoring model, an incompatible input contract or a
material extraction regression would change the proposed boundary. Start with
slice 1's second-app compilation and parity checks before investing in packaging.
