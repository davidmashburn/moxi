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

## Implementation update — 2026-08-30

The implementation work for this plan is now recorded on `main` as focused,
reviewable commits. The package version remains `0.5.0`; these are experimental
post-0.5 slices, not a 0.6 release claim.

| Area | Current state | Remaining boundary |
| --- | --- | --- |
| GPU rendering | macOS Metal scene renderer, offscreen checksum benchmark, batched rectangle/line geometry, and visible `CAMetalLayer` window with scale/resize handling | Text/image resources, path tessellation, gradient shaders, asynchronous pacing, and GPU timestamps |
| Text | Portable cluster-aware approximate shaped runs with fallback-face classes; CoreText adapter with native glyph ids, clusters, bidi, and advances | Production portable shaping/font fallback and richer multiline/editing integration |
| Virtualization | Stable-key fixed-extent `VirtualRecycler` and typed `VirtualizedList` with overscan, bounded slots, clamping, and ensure-visible behavior | Measured variable heights, scrollbars, richer viewport policy, and typed subtree diffing |
| Native widgets | Broader AppKit catalog presentation and semantic/action bridge | Deeper native controls and multi-window ownership rather than custom canvas affordances |
| iOS / Android / Web | Shared target, surface lifecycle, resize, and scale-factor contracts; SVG is a Web-compatible export path | Native mobile hosts, browser runtime, input/accessibility adapters, and CI smoke tests |
| Localized execution | Scope/dependency graph and invalidation/build accounting, including descendant propagation | Localized typed subtree execution and partial paint submission |
| Plotting | `PlotDataTable`, versioned line/scatter/bar `PlotSpec`, linear scales, axes/grid/legend, pan/zoom, hit testing, selection semantics, line LOD, and software/Metal/SVG output | Temporal/ordinal scales, transforms, composition/facets, richer annotations/tooltips, and supported-package release |
| Performance | Repeatable retained, portable plot, dense plot, and offscreen Metal workloads with deterministic counters/checksums and 60/120 Hz budget guidance | Cross-device baselines, GPU timestamping, and like-for-like Moxi/Xilem measurements |

The current validation entry point is `pixi run release-check`. The release
gate runs the full headless/native/package suite, the repeatable benchmarks,
the wx-style demo build, the visible Metal-window build, and the CoreText
demo build. Native mobile/browser execution is deliberately not reported as
supported until those hosts and interaction harnesses exist.

## MojoGUI-UI mining plan — 2026-08-31

The upstream [MojoGUI-UI](https://github.com/CodeAlexx/MojoGUI-UI) catalog is
useful as a source of interaction patterns, but its integer geometry, C/GLFW
renderer, and standalone widget ownership model do not fit Moxi. The mining
scope is therefore a set of Moxi-native contracts rather than a widget port.

### Core contract decisions

- Moxi state remains the source of truth. Collection data, stable item identity,
  selection, focus, scroll position, popup visibility, and popup dismissal are
  value-oriented state; rendering and native presentation consume snapshots.
- Stable keys, not visible indices or object addresses, identify collection
  rows, columns, tree nodes, tabs, and popup actions. Reconciliation must retain
  focus and selection when rows move or are recycled.
- Mutations are explicit commands/results: select, extend selection, activate,
  expand/collapse, scroll-to-key, open/close popup, dismiss, and invoke action.
  No upstream callback, C handle, or renderer object crosses the Moxi boundary.
- Moxi's normalized events, floating-point geometry, `ViewNode`/scene output,
  `VirtualRecycler`, accessibility semantics, and native action bridge are the
  integration seams. Upstream integer `*Int` types are reference material only.

### First milestone: collection and popup interaction foundation

Implement this as narrow, testable modules on `main`:

1. `src/moxi/collection_state.mojo`: stable-key selection/focus models,
   keyboard navigation, bounded multi-selection, list/tree expansion state,
   column definitions, and reorder results. The model must not own painting or
   platform handles.
2. `src/moxi/scrollbar.mojo`: scrollbar thumb geometry, track/page/step
   commands, clamping, and viewport-to-content mapping. The policy must work
   with fixed and measured variable extents and remain independent of a
   renderer.
3. `src/moxi/popup.mojo`: one popup-layer state model for combo/menu/context
   menu/dialog use cases, with anchor bounds, placement, modal/focus scope,
   keyboard dismissal, and stable action IDs. Existing `ComboBoxState`,
   `MenuState`, and `DialogState` should remain source-compatible while gaining
   a common contract where practical.
4. Export the contracts from `src/moxi/__init__.mojo`, add deterministic unit
   tests, and add one shared scenario consumed by tests and a future demo.

The first milestone deliberately does not promise fully painted list/table/tree
widgets, editable collection cells, native AppKit menu/dialog ownership, or a
complete demo-browser redesign. Those are follow-on integrations once the state
and geometry contracts are proven.

### Shared scenarios and acceptance

Add a collection scenario with stable keys, a reordered row, one expanded tree
branch, mixed fixed/measured extents, overscan, and a 10,000-row case. Add a
popup scenario covering an anchored combo, nested menu dismissal, modal dialog
focus trapping, Escape dismissal, and action invocation. Tests, benchmarks, and
examples must consume these scenarios rather than duplicate literals.

Acceptance for the milestone:

- pure state tests cover selection, keyboard movement, expansion, reorder,
  popup dismissal, focus restoration, and stable-key reconciliation;
- geometry tests cover thumb sizing, clamping, page/step movement, variable
  extents, and degenerate content/viewport sizes;
- the existing full test command and `pixi run release-check` remain green;
- a repeatable benchmark reports recycler/selection/scroll work for the shared
  10,000-row scenario; and
- README/API/status documentation names the experimental boundary and keeps
  native menu/dialog and editable-cell behavior explicitly qualified.

### Mining order after the first milestone

- Port the MojoGUI dock tree and dock-area host-content contract as a retained
  Moxi layout module, after fixing the upstream phase-1 divergences in drop-zone
  geometry, splitter dragging, and tab insertion semantics.
- Generalize its small reorder primitive into Moxi drag threshold/cancellation
  and stable-key collection commands.
- Add financial OHLC/candlestick data and scale primitives only as an adapter to
  Moxi plotting, not as a second chart engine.
- Treat source editor and node graph as separate large features; mine their
  data models and workflows only after text editing, collection virtualization,
  and interaction capture are ready.

The explicit non-goals are the upstream C backend, GLFW windowing, integer
geometry/color API, font wrappers, fixed-coordinate widgets, and a wholesale
copy of the approximately partial chart/dock/DND implementations.
