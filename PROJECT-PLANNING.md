# Moxi Project Plan

This branch is the planning record for the work after the 0.5 preview. The
implementation worktree may remain dirty while these slices are developed;
existing changes are user-owned and must not be rewritten or silently folded
into a planning commit.

## Direction after 0.5

Moxi is a Mojo UI library with a retained view/runtime model, explicit backend
boundaries, deterministic headless rendering, native macOS presentation, a
capability bus, component state, accessibility semantics, and a broad control
catalog. The next phase is about making those contracts production-worthy,
starting with the rendering and performance path and then using it to build a
first-class plotting library.

The explicitly deferred post-0.5 work is:

- GPU rendering.
- Portable text shaping and font fallback.
- True virtualized view recycling rather than only visible-range math.
- Deep native widgets and platform-native interaction fidelity.
- Cross-platform backends.
- Localized component execution and dependency-scoped invalidation.

Performance is a release requirement, not a later optimization pass. Mojo is
being used for predictable, low-overhead UI work, so every renderer/runtime
slice must have a repeatable benchmark, a stated workload, and a recorded
reason for any tradeoff.

The first product built on these contracts is a first-class plotting library:
portable data and scene generation first, then GPU/native presentation and
interactive exploration.

## Core contract decisions

1. `View` remains declarative and platform-independent. It owns no native
   handles and is safe to rebuild.
2. Retained runtime state, component state, capability calls, and platform
   handles have explicit ownership boundaries. A callback or native handle
   does not cross a serialization or capability boundary implicitly.
3. A backend advertises what it actually supports. iOS, Android, and Web are
   named targets in the capability matrix before native implementations exist;
   they must report unavailable rather than masquerading as macOS or headless.
4. Scene commands are the portable rendering contract. Software rendering is
   the deterministic oracle; GPU renderers consume the same scene/resources
   where practical and may expose a documented capability-specific extension.
5. Text shaping is an adapter boundary. The fallback estimator remains useful
   for headless tests, but user-visible text must identify whether shaping,
   bidi, font fallback, and glyph rasterization are real on that backend.
6. Examples, tests, and benchmarks consume shared scenarios and data fixtures.
   A demo is a contract test, not a hand-built mirror of the API.

## Shared scenarios and references

The initial shared scenario set should live beside the library (planned
`src/moxi/scenarios.mojo` or a small `scenarios/` package) and be consumed by
tests, examples, benchmarks, and reference screenshots:

- A compact form and wxPython-style control tree.
- A long scrolling list with stable item identity and changing data.
- A mixed text scene containing wrapping, bidi, and editable text cases.
- A plotting scene with line, scatter, bar, axes, legend, and tooltip data.
- A 10,000-node stress tree for reconciliation/layout/paint measurements.

Where parity matters, compare against the real platform/reference behavior
(AppKit, UIKit, Android Views/Compose, and browser Canvas/SVG/accessibility
semantics) instead of maintaining a static imitation. Static SVGs and
headless scenes are useful documentation, not behavioral oracles.

## Performance policy

Every renderer/runtime change must update the benchmark story:

- Measure repeated runs, not a single timing; report workload size, pass count,
  checksum/validation signal, compiler/runtime version, and hardware notes.
- Keep quick benchmarks suitable for `pixi run check` and a fuller benchmark
  suitable for release/pre-submit runs.
- Cover at least reconcile, layout, paint/scene generation, software rendering,
  and virtualized scrolling. Once GPU work lands, add command encoding,
  resource upload, frame submission, and frame-time measurements.
- Compare 100-, 1,000-, and 10,000-node workloads where the stage supports it;
  track allocations or command counts when wall-clock allocation data is not
  portable.
- Treat a 60 Hz frame as a 16.67 ms budget and a 120 Hz frame as an 8.33 ms
  budget. State whether a result is CPU-only, GPU-inclusive, or a cold start.
- Optimize only after a baseline exists. Prefer stable identity, bounded work,
  batching, dirty-region/dirty-component scopes, resource reuse, and fewer
  allocations over speculative micro-optimizations.

The benchmark command and methodology belong in the repository, and release
notes should include the result artifact or a concise comparison table. A
regression should block a release when it breaks a stated budget or materially
increases work for a shared scenario.

## Backend and platform scope

Target the platforms in this order, while keeping the common contract usable:

| Target | First backend shape | Initial native surface | Current status |
| --- | --- | --- | --- |
| macOS | AppKit window + scene/software path; Metal target | windows, input, AX, text bridge | shipped baseline; GPU pending |
| iOS | UIKit/Metal surface adapter | app/window lifecycle, touch, safe areas, AX | capability contract only |
| Android | Android surface/input/accessibility adapter | lifecycle, touch, IME, density | capability contract only |
| Web | browser host + Canvas/WebGPU target | DOM focus/AX bridge, pointer/touch, resize | capability contract only |

The first cross-platform milestone is not “all widgets everywhere.” It is a
portable surface/window lifecycle, event vocabulary, scale-factor contract,
resource lifetime policy, accessibility mapping, and deterministic fallback.
The native adapters can then fill the matrix explicitly and share scene,
layout, component, capability, and plotting code.

## Milestones

### 0.6 — GPU-ready rendering and measurable performance

- Stabilize scene/resource ownership and renderer capability contracts.
- Implement a Metal-backed macOS renderer consuming scene commands, with the
  software renderer retained as an oracle/fallback.
- Add GPU resource lifetime, resize, scale-factor, clipping, transform, and
  readback/checksum test seams.
- Add repeatable CPU and GPU benchmark cases and use evidence to improve hot
  paths (batching, command storage, invalidation, and resource reuse).
- Keep the first implementation honest about unsupported text and effects.

Acceptance: the same scene renders through software and GPU paths, a native
window presents it, failures fall back predictably, and benchmark output makes
CPU/render/frame costs visible.

### 0.7 — Portable text and real virtualization

- Define a shaped-run/glyph-resource adapter with font fallback and bidi
  metadata; use platform shaping first and a portable implementation where
  licensing/build constraints allow it.
- Replace visible-range-only lists with stable-key item builders, recycling,
  measured extents, overscan, anchoring, and ensure-visible behavior.
- Benchmark text-heavy and long-list scenarios separately from small trees.

Acceptance: shaping and recycling are observable capabilities with tests for
identity, focus, keyboard navigation, editing, and scroll stability.

### 0.8 — Native depth and localized execution

- Add native adapters for text input/IME, menus, dialogs, tables, lists,
  accessibility actions, drag/drop, and platform lifecycle in priority order.
- Add dependency-scoped invalidation and localized component execution so a
  leaf update does not rebuild or repaint unrelated subtrees.
- Extend the capability bus with platform executors, deadlines, cancellation,
  audit metadata, and explicit async result delivery.

Acceptance: mutation traces identify the affected component/view region and
native controls preserve semantics, focus, and input behavior.

### 0.9 — iOS, Android, and Web vertical slices

- Ship one small shared scenario end-to-end on each target: window/surface,
  input, layout, scene, text, accessibility, and teardown.
- Start with the GPU-capable path where available (Metal, then WebGPU) and a
  documented software/canvas fallback.
- Establish device/emulator/browser CI or a reproducible manual harness before
  declaring support.

Acceptance: each target has a real demo, readiness/teardown checks, a backend
  capability report, and a platform-specific performance baseline.

### 1.0 — supported core and plotting foundation

- Stabilize the public API and compatibility policy.
- Ship the plotting library as a supported Moxi package, with portable scene
  output, native/GPU rendering, interaction, accessibility, and docs.
- Publish like-for-like performance results for representative UI and plot
  workloads, plus the known limitations for each backend.

## Plotting library: first product slice

The plotting API should be a library feature, not a demo-specific painter. Its
source of truth is platform-neutral data and declarative configuration:

- `PlotPoint`, typed series/data views, stable series identity, and bounded
  updates suitable for streaming data.
- Linear scales first, with explicit domains, ranges, tick policy, and a
  coordinate transform that can be tested without a renderer.
- Line and scatter series first; bar/area, axes, grid, legend, annotations,
  hit testing, zoom/pan, and tooltip semantics follow as separate slices.
- `Plot.build_scene()` emits portable scene commands. Software rendering,
  Metal/WebGPU, and native accessibility overlays consume that contract.
- The showcase demo uses the shared plotting scenario and exposes both a
  deterministic headless checksum and a visible native/GPU path when available.
- Plot tests cover data updates, degenerate domains, clipping, stable colors,
  coordinate mapping, command output, and interaction hit testing.

The first 30-minute implementation window is intentionally narrow: capture
this plan, name the three future backend targets, add measurable performance
contracts, and implement the smallest useful portable plot scene/demo/test
vertical slice. Actual Metal, UIKit, Android, browser, portable shaping, true
recycling, and deep native widget work remain follow-on slices unless the
available time and existing seams make one safe to land.

## Browser/integration harness

When Web work begins, add a deterministic harness with one known-good server
path, readiness probe, stable test route, explicit teardown, and real browser
interaction tests. The harness must exercise keyboard/pointer/touch, focus,
resize, accessibility exposure, plotting updates, and renderer fallback. Do
not claim Web support from a compile-only target.

## Documentation and release gates

Keep `README.md`, `SPEC.md`, `ARCHITECTURE.md`, API docs, changelog, showcase
instructions, capability reports, and benchmark methodology synchronized.
Each milestone needs:

- a status table distinguishing shipped, experimental, and planned behavior;
- a runnable example consuming the public API;
- unit/property tests for pure contracts and integration tests for visible
  behavior;
- benchmark output with the workload and environment recorded; and
- explicit non-goals and fallback behavior for unsupported targets.

The 0.5 worktree is intentionally preserved as-is while this plan is captured.
Future implementation commits should be narrow, reviewable slices that can be
compared cleanly against the existing 0.5 baseline.
