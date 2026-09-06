# Moxi current-state audit

Audited September 6, 2026 against `main` at `bd3722c`. This document is based
on source, tests, build scripts, and local validation. README, changelog, and
older roadmap claims were treated as hypotheses until the implementation
confirmed them.

## Executive assessment

Moxi is no longer a small post-0.5 prototype. It contains a broad UI runtime,
native macOS host, software and Metal scene paths, a capable plotting stack,
accessibility bridges, a capability bus, a demo browser, and extensive contract
tests. The breadth is ahead of its support story.

The next risk is therefore not missing features. It is that a roughly
900-line package boundary re-exports hundreds of names while important
behaviors remain explicitly experimental, root rebuilds remain global, and
visual/performance evidence is not stored in a form CI can compare. The next
milestone should turn the existing breadth into a smaller, measurable contract.

## Validation performed

| Check | Result | What it proves |
| --- | --- | --- |
| `git fetch origin main project-planning --prune` | local branches were already current with their remotes; local planning contains one additional research commit | the audit used the latest repository state available on both branches |
| `pixi run test` | pass, 65 Mojo test programs | portable unit and integration contracts compile and execute together |
| `pixi run check` | pass, including strict native compilation, generated API docs, Android APK, iOS simulator app, Web host, HarfBuzz, and live reload | the full repository validation path succeeds on the audited macOS host with its installed SDKs |
| `MOXI_BENCHMARK_RUNS=1 pixi run benchmark` | pass across the aggregate retained UI, interaction, plot, fractal, and Metal workloads | every workload included by the aggregate harness is runnable on the audited host and emits stable counters/checksums |
| source/build inspection | 253 tracked files, 179 tracked Mojo files, 67 Mojo test files | the aggregate test runner intentionally covers 65 programs; `live_reload.mojo` and `package_consumer.mojo` are exercised by their dedicated scripts |

The quick benchmark run is a smoke check, not a baseline. It includes compiler
or process startup for several workloads and does not write structured results.

## Capability matrix

| Area | Implementation truth | Confidence | Evidence in `main` | Planning consequence |
| --- | --- | --- | --- | --- |
| Package and public API | The package is versioned `0.5.1`, but `src/moxi/__init__.mojo` is about 900 lines and imports from 74 module groups. Stable 0.5 names and post-0.5 experiments share one flat boundary. | High | `pixi.toml`, `shelf.toml`, `src/moxi/__init__.mojo`, package-consumer check | Define stable, provisional, and internal lanes before adding more public names. |
| Component ownership | `Component.build(bounds)` returns a value tree and `update(event, view)` owns mutation. `ComponentSlot` provides typed child ownership with integer id namespacing. | High | `src/moxi/component.mojo`, component/composed tests | Preserve value ownership, but replace manual id arithmetic with a first-class keyed subtree boundary. |
| Execution and reconciliation | `(id, kind)` reconciliation reuses retained nodes and reports changes. `LocalizedExecution` records scope dependencies, but `App.rebuild()` still calls the root component builder, reconciles the complete tree, and invalidates all bounds. | High | `src/moxi/runtime.mojo`, `src/moxi/execution.mojo`, `src/moxi/app_runtime.mojo` | True localized typed subtree execution is the primary runtime milestone. |
| Layout and interaction | Column/row, stack, grid, split, portal, constraints, clipping, automatic overflow, draggable/pageable scrollbars, stable-key variable-height recycling, focus, pointer, keyboard, IME, clipboard, popup, reorder, and accessibility actions are implemented and tested. | High | `src/moxi/view.mojo`, `layout_primitives.mojo`, `scrollbar.mojo`, `popup.mojo`, `reorder.mojo`, interaction tests | Treat this as an existing contract to protect, not a roadmap item. Do not broaden layout until regression scenarios are shared. |
| Themes and recipes | Semantic tokens, dark/light/zinc/emerald presets, recipes, an interactive theme showcase, and contract tests exist. Theme inheritance was fixed in the audited commit. | High | `tokens.mojo`, `recipes.mojo`, `theme_showcase.mojo`, theme tests | The old token/recipe proposal is complete. The remaining work is visual baselines and API support classification. |
| Rendering | Paint commands feed an inspectable scene IR. Software rendering is deterministic; AppKit is the main native UI renderer; Metal supports a substantial geometry/text/image/path slice and dense plot packets. Unsupported work is counted or falls back. | High for contracts; medium for parity | `paint.mojo`, `scene.mojo`, `software.mojo`, `macos.mojo`, `metal.mojo`, native sources and renderer tests | Keep software as the oracle. Add corpus-driven parity and golden checks before extending GPU breadth. |
| Native capacity | AppKit storage is process-global and statically capped at 128 entries per draw/accessibility kind; custom draw and Metal resources have other explicit ceilings. Overflow is generally observable. | High | `native/macos_window.m`, `native/macos_metal.m` | Multi-window/native scaling cannot be called supported until ownership and capacity become instance-scoped or explicitly bounded by contract. |
| Text | Portable shaping is deterministic and deliberately approximate. CoreText supplies real macOS shaping/fallback; optional HarfBuzz uses one host-selected font but does not provide a production fallback collection or full paragraph bidi policy. | High | `text_boundary.mojo`, `text_shaping.mojo`, `coretext.mojo`, `harfbuzz.mojo`, text tests | Build a conformance corpus and host policy before promising portable text fidelity. |
| Accessibility | Portable semantics, validation, native macOS AX, Web ARIA, and iOS/Android virtual-node sources exist. Device/screen-reader automation and live Mojo publication on non-macOS targets do not. | High | `accessibility.mojo`, `native_widgets.mojo`, native host sources, accessibility tests | Keep “semantic bridge” separate from “verified platform support.” |
| Platforms | macOS Apple Silicon is the only package target. iOS simulator, Android APK, and browser host artifacts are buildable when SDKs are present, but they do not host a linked Mojo application runtime. CI is macOS-only and some host checks skip when SDKs are absent. | High | `pixi.toml`, `.github/workflows/ci.yml`, `scripts/host_check.sh`, `native/` | The next platform gate is one real shared scenario with readiness, teardown, and accessibility—not more adapter types. |
| Plotting | Typed columnar data, stable keys, versioned JSON spec parsing, transforms, statistical recipes, facets, interaction, selection/linking, LOD, accessibility/CSV, software/SVG, and a Metal packet path are implemented. Several advanced mark families and exports remain absent. | High | `plot_*.mojo`, `plotting.mojo`, plot tests/benchmarks | Harden the implemented 2D subset as a provisional package; do not chase polar, geographic, 3D, or new marks yet. |
| Capability bus | In-process descriptors, schemas, policy, approvals, replay, typed handlers, leases, queue bounds, and walkthrough automation exist. Transport, persistence, deadlines/cancellation, and external execution remain outside the core. | High | `capability.mojo`, `conversation.mojo`, capability tests/walkthrough | Keep it optional and transport-neutral. Stabilize the authorization contract before adding an agent runtime. |
| Scenarios and demos | Real demos mount in one browser and source panels show component code. Shared scenarios exist, but they are split among feature modules; `scenarios.mojo` currently centralizes only interaction and plot fixtures. | High | demo browser, `scenarios.mojo`, form/wx/showcase modules | Introduce a scenario registry consumed by demos, tests, goldens, and benchmarks. |
| Tests and visual QA | Contract coverage is broad and the software renderer exposes deterministic checksums. There is no checked-in golden raster corpus, thresholded diff tool, or CI artifact review flow. SVG illustrations are documentation references, not full visual regression tests. | High | `scripts/test.sh`, renderer tests, `docs/*.svg` | Visual regression is still open even though the old Storybook-style showcase proposal is largely complete. |
| Benchmarks | The harness repeats useful workloads and emits deterministic counters plus host timings. Results are console text; there is no committed machine-readable baseline, environment manifest, variance report, or automated regression threshold. | High | `scripts/benchmark.sh`, `benchmarks/`, `docs/performance.md` | Add structured quick/full outputs before making comparative performance claims. |

## What the prior planning got wrong or outgrew

- The September 1 theme and recipe plan described work that now exists on
  `main`; keeping it as an active plan obscured the real gap.
- The all-states/Storybook direction partially landed as the theme showcase and
  richer demo browser, but screenshot diffing did not. Those must be recorded
  as separate outcomes.
- The old post-0.5 roadmap mixed completed Metal, virtualization, plotting,
  scrolling, and host-artifact slices with future work. Status prose had grown
  longer than the remaining decisions.
- “Cross-platform” was sometimes used for portable contracts, buildable native
  shells, and live Mojo targets. These are materially different support levels.
- Localized execution was described as present, but the code currently exposes
  dependency accounting around a root-wide rebuild.

The obsolete proposal files have been removed from this branch. Their
implemented outcomes and remaining visual-testing gap are represented here and
in the active plan.

## Risk ranking

### P0: support-boundary risks

1. **Public-surface ambiguity.** Hundreds of re-exported names make accidental
   compatibility promises likely.
2. **Root-wide work.** Component invalidation does not yet bound builder,
   reconciliation, layout, or paint work to a typed subtree.
3. **No comparable visual signal.** Renderer and theme changes can pass broad
   behavioral tests without a reviewable image diff.
4. **No durable performance baseline.** Useful counters exist, but results
   cannot be compared automatically across commits.
5. **Documentation classification drift.** Stable, experimental, host-only, and
   planned behavior must use one vocabulary.

### P1: quality and platform risks

- portable text shaping/fallback and paragraph behavior;
- instance-scoped native ownership, capacities, and true multi-window support;
- live Mojo runtimes plus device/browser accessibility validation;
- deeper native collection editing and modal/menu ownership; and
- capability transport/executor lifecycle outside the in-process policy core.

### Defer until P0/P1 contracts exist

- additional widget breadth;
- polar, geographic, 3D, contour, candlestick, and other plot families;
- a second GPU backend selected only for ecosystem signaling;
- an in-browser IDE; and
- a bundled LLM client or opinionated network transport.
