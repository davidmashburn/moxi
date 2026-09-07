# Moxi current-state audit

Audited September 6, 2026 against `main` at `977089a`. This document is based
on source, tests, build scripts, and local validation. README, changelog, and
older roadmap claims were treated as hypotheses until the implementation
confirmed them.

## Executive assessment

Moxi is no longer a small post-0.5 prototype. It contains a broad UI runtime,
native macOS host, software and Metal scene paths, a capable plotting stack,
accessibility bridges, a capability bus, a demo browser, and extensive contract
tests. The breadth is ahead of its support story.

Gate 1 has now landed its first measurable slices: the package export surface
has a generated support inventory, seven canonical scenario descriptors are
checked in, software-renderer PPM goldens and a browser-host lifecycle harness
run through the validation path, typed localized execution exposes work
counters, and quick/full benchmark profiles emit structured JSON. One reviewed
macOS arm64 full-profile baseline and a same-environment comparison command are
now checked in. Collection and plot fixture defaults now derive their size and
seed from the canonical registry, and the other five scenario families expose
registry-owned text, labels, modes, defaults, or preset matrices. The next risk
is not missing features; it is making those slices compose into a smaller
supportable contract. The package
boundary still re-exports hundreds of names, `App` still has a root-wide
fallback, benchmark comparison has no compatible baseline beyond macOS arm64,
and linked Mojo runtimes remain unavailable on non-macOS targets.

## Validation performed

| Check | Result | What it proves |
| --- | --- | --- |
| repository audit and sequential commits | `main` is audited at `332eb07`; `project-planning` retains the modular-ecosystem research plus this progress ledger | the code and plan were reconciled against the latest local implementation rather than trusting older prose |
| `pixi run test` | pass, 66 Mojo test programs | portable unit and integration contracts compile and execute together |
| `pixi run check` | pass, including 873-export API inventory, seven software goldens, strict native compilation, generated API docs, Android APK, iOS simulator app, Web host, browser lifecycle, HarfBuzz, and live reload | the full repository validation path succeeds on the audited macOS host with its installed SDKs |
| `MOXI_BENCHMARK_RUNS=1 pixi run release-check` | pass, including package publication/consumer, release-only native builds, and the complete 10-case benchmark matrix | the distributable package and release wrapper work on the audited host; benchmark output remains diagnostic rather than a reviewed baseline |
| clean full-profile baseline | 30 runs across 10 cases, `git_dirty: false`, checked in at `benchmarks/results/macos-arm64-full.json` | deterministic counters/checksums and the measured environment are durable for future same-environment review |
| `MOXI_BENCHMARK_RUNS=3 pixi run benchmark-full` | pass for 10 cases with a clean schema-v2 report after the fixture refactor | the complete matrix is repeatable from a clean tree and emits deterministic counters/checksums plus per-run status/timing and environment metadata |
| `pixi run benchmark-compare` | pass for 10 cases against the reviewed macOS arm64 baseline after a repeat run | compatible environment metadata and deterministic signatures match; the initial timing-only outlier was cleared by the repeat sample and the final medians stay within the documented diagnostic threshold |
| `pixi run visual-check` / `pixi run browser-check` | pass for 7 PPM images / the host lifecycle JSON contract | software pixels are compared exactly; the Web page and host publish readiness, Canvas, input, ARIA, and teardown evidence |
| source/build inspection | 276 tracked files, 183 tracked Mojo files, 69 Mojo test files | the aggregate test runner intentionally covers 66 programs; `live_reload.mojo`, `package_consumer.mojo`, and the scenario manifest are exercised by dedicated scripts |

## Gate 1 implementation ledger

The ordered implementation pass is recorded here so the plan does not imply
that a partial vertical slice is a complete product claim.

| Workstream | Status at `332eb07` | Evidence | Remaining boundary |
| --- | --- | --- | --- |
| Public API inventory | Implemented | `docs/api-status.md`, `scripts/api_status_check.sh`, 873 classified exports | focused import paths, compatibility policy, and stable/provisional package enforcement |
| Canonical scenarios | Registry, consumer inventory, and fixture helpers/defaults implemented across all seven families | `src/moxi/scenarios.mojo`, `scripts/scenario_check.sh`, `4ef1171`, `5f9c44b`, `332eb07`, demo catalog mapping, registry contract test, golden/benchmark metadata | make full behavior state tables (theme controls, capability steps, and feature-specific fixture records) descriptor-driven rather than helper-driven |
| Software visual regression | Implemented for software oracle | seven lossless PPM images, manifest, exact checker, reviewable actual/expected/diff artifacts | native screenshot parity and threshold/mask policy for platform-dependent output |
| Browser host lifecycle | Implemented as deterministic host gate | `scripts/browser_check.sh`, `tests/web_browser_harness.mjs`, readiness/Canvas/ARIA markers | linked Mojo Web runtime and real-browser/device automation in CI |
| Typed localized execution | Implemented as one typed subtree slice | `TypedSubtreeExecutor`, `ExecutionWorkCounters`, `tests/execution.mojo`, localized benchmark | parent/child scheduling, keyed view diff, insertion/removal/reorder, and explicit root fallback counters |
| Structured benchmarks | Protocol, localized matrix, one reviewed macOS baseline, and same-environment comparison implemented | `scripts/benchmark.sh`, `scripts/benchmark_compare.py`, `benchmarks/result-schema.json`, `benchmarks/results/macos-arm64-full.json`, `docs/benchmarking.md`, localized 1/10/100 matrix | dispersion reporting, CI wiring, and compatible-environment coverage beyond macOS arm64 |
| Documentation vocabulary | Reconciled on `main` | README/API/visual/performance/demo/comparison docs and generated API status | keep status snapshots synchronized as the public surface changes |

The quick benchmark run is a smoke check, not a baseline. It includes compiler
or process startup for several workloads; its structured report is intentionally
written to ignored local output until a reviewed environment-specific baseline
policy exists.

## Capability matrix

| Area | Implementation truth | Confidence | Evidence in `main` | Planning consequence |
| --- | --- | --- | --- | --- |
| Package and public API | The package is versioned `0.5.1`, `src/moxi/__init__.mojo` is about 900 lines and imports from 74 module groups, and all 873 current exports now have generated support-lane rows. Stable 0.5 names and post-0.5 experiments still share one flat boundary. | High | `pixi.toml`, `shelf.toml`, `src/moxi/__init__.mojo`, `docs/api-status.md`, package-consumer check | Turn the inventory into focused import paths and compatibility/deprecation enforcement before adding more public names. |
| Component ownership | `Component.build(bounds)` returns a value tree and `update(event, view)` owns mutation. `ComponentSlot` provides typed child ownership with integer id namespacing. | High | `src/moxi/component.mojo`, component/composed tests | Preserve value ownership, but replace manual id arithmetic with a first-class keyed subtree boundary. |
| Execution and reconciliation | `(id, kind)` reconciliation reuses retained nodes and reports changes. `TypedSubtreeExecutor` now owns one typed component/view/runtime and performs scoped invalidation, rebuild, paint, accessibility, and work accounting. `App.rebuild()` still calls the root component builder, reconciles the complete tree, and invalidates all bounds. | High | `src/moxi/runtime.mojo`, `src/moxi/execution.mojo`, `src/moxi/app_runtime.mojo`, `tests/execution.mojo` | Strengthen the slice into parent/child scheduling and a keyed view-sequence diff; retain root rebuild as an observable fallback. |
| Layout and interaction | Column/row, stack, grid, split, portal, constraints, clipping, automatic overflow, draggable/pageable scrollbars, stable-key variable-height recycling, focus, pointer, keyboard, IME, clipboard, popup, reorder, and accessibility actions are implemented and tested. | High | `src/moxi/view.mojo`, `layout_primitives.mojo`, `scrollbar.mojo`, `popup.mojo`, `reorder.mojo`, interaction tests | Treat this as an existing contract to protect, not a roadmap item. Do not broaden layout until regression scenarios are shared. |
| Themes and recipes | Semantic tokens, dark/light/zinc/emerald presets, recipes, an interactive theme showcase, and contract tests exist. Theme inheritance was fixed in the audited commit, and theme states are represented in the software golden corpus. | High | `tokens.mojo`, `recipes.mojo`, `theme_showcase.mojo`, theme tests, `tests/goldens/` | The old token/recipe proposal is complete. Remaining work is native/platform visual parity and continued API support classification. |
| Rendering | Paint commands feed an inspectable scene IR. Software rendering is deterministic and now has seven exact PPM goldens; AppKit is the main native UI renderer; Metal supports a substantial geometry/text/image/path slice and dense plot packets. Unsupported work is counted or falls back. | High for contracts; medium for parity | `paint.mojo`, `scene.mojo`, `software.mojo`, `macos.mojo`, `metal.mojo`, `tests/goldens/`, native sources and renderer tests | Keep software as the oracle. Extend GPU breadth only after replaying the corpus and documenting platform-dependent tolerances. |
| Native capacity | AppKit storage is process-global and statically capped at 128 entries per draw/accessibility kind; custom draw and Metal resources have other explicit ceilings. Overflow is generally observable. | High | `native/macos_window.m`, `native/macos_metal.m` | Multi-window/native scaling cannot be called supported until ownership and capacity become instance-scoped or explicitly bounded by contract. |
| Text | Portable shaping is deterministic and deliberately approximate. CoreText supplies real macOS shaping/fallback; optional HarfBuzz uses one host-selected font but does not provide a production fallback collection or full paragraph bidi policy. | High | `text_boundary.mojo`, `text_shaping.mojo`, `coretext.mojo`, `harfbuzz.mojo`, text tests | Build a conformance corpus and host policy before promising portable text fidelity. |
| Accessibility | Portable semantics, validation, native macOS AX, Web ARIA, and iOS/Android virtual-node sources exist. Device/screen-reader automation and live Mojo publication on non-macOS targets do not. | High | `accessibility.mojo`, `native_widgets.mojo`, native host sources, accessibility tests | Keep “semantic bridge” separate from “verified platform support.” |
| Platforms | macOS Apple Silicon is the only package target. iOS simulator, Android APK, and browser host artifacts are buildable when SDKs are present, but they do not host a linked Mojo application runtime. The Web host now has an ephemeral-server lifecycle harness with readiness, Canvas, input, ARIA, and teardown assertions. CI is macOS-only and some host checks skip when SDKs are absent. | High | `pixi.toml`, `.github/workflows/ci.yml`, `scripts/host_check.sh`, `scripts/browser_check.sh`, `tests/web_browser_harness.mjs`, `native/` | The next platform gate is one linked Mojo runtime on a real target with the same scenario and accessibility evidence—not more adapter types. |
| Plotting | Typed columnar data, stable keys, versioned JSON spec parsing, transforms, statistical recipes, facets, interaction, selection/linking, LOD, accessibility/CSV, software/SVG, and a Metal packet path are implemented. Several advanced mark families and exports remain absent. | High | `plot_*.mojo`, `plotting.mojo`, plot tests/benchmarks | Harden the implemented 2D subset as a provisional package; do not chase polar, geographic, 3D, or new marks yet. |
| Capability bus | In-process descriptors, schemas, policy, approvals, replay, typed handlers, leases, queue bounds, and walkthrough automation exist. Transport, persistence, deadlines/cancellation, and external execution remain outside the core. | High | `capability.mojo`, `conversation.mojo`, capability tests/walkthrough | Keep it optional and transport-neutral. Stabilize the authorization contract before adding an agent runtime. |
| Scenarios and demos | Real demos mount in one browser and source panels show component code. `scenarios.mojo` centralizes seven stable descriptors; the demo browser/golden registry tests consume the inventory, collection/plot factories derive default size/seed from it, and text/theme/capability/fractal consumers use registry-owned helpers. Full behavior tables remain module-local. | High | demo browser, `scenarios.mojo`, `tests/scenarios.mojo`, `tests/golden_render.mojo`, form/theme/capability/fractal modules, `4ef1171`, `5f9c44b` | Make each descriptor the single fixture source for its behavior test, golden, and benchmark, then enforce that mapping in the catalog check. |
| Tests and visual QA | Contract coverage is broad, the software renderer exposes deterministic checksums, and seven lossless PPM goldens run through `scripts/visual_check.sh` with reviewable mismatch artifacts. SVG illustrations remain documentation references, and native screenshot parity is not automated. | High | `scripts/test.sh`, `scripts/visual_check.sh`, `tests/goldens/`, renderer tests, `docs/*.svg` | Add native threshold/mask policy and real screenshot capture only after platform ownership and font policy are explicit. |
| Benchmarks | Quick/full profiles preserve the existing workloads and emit structured JSON with commands, status, wall time, deterministic metric lines, and environment metadata. A reviewed macOS arm64 full-profile baseline is committed, and compatible candidates can be checked with the comparator; local/CI samples remain ignored. | High | `scripts/benchmark.sh`, `scripts/benchmark_compare.py`, `benchmarks/result-schema.json`, `benchmarks/results/`, `docs/benchmarking.md`, `docs/performance.md` | Add dispersion reporting, CI wiring, and compatible baselines beyond macOS arm64 before making cross-environment comparative performance claims. |

## What the prior planning got wrong or outgrew

- The September 1 theme and recipe plan described work that now exists on
  `main`; keeping it as an active plan obscured the real gap.
- The all-states/Storybook direction partially landed as the theme showcase and
  richer demo browser. Software screenshot diffing now exists as a checked-in
  PPM corpus; native screenshot capture and platform-dependent diffing remain a
  separate outcome.
- The old post-0.5 roadmap mixed completed Metal, virtualization, plotting,
  scrolling, and host-artifact slices with future work. Status prose had grown
  longer than the remaining decisions.
- “Cross-platform” was sometimes used for portable contracts, buildable native
  shells, and live Mojo targets. These are materially different support levels.
- Localized execution was described as present before there was a typed owner;
  the code now proves one typed subtree slice, while ordinary `App` invalidation
  still exposes dependency accounting around a root-wide rebuild.

The obsolete proposal files have been removed from this branch. Their
implemented outcomes and remaining visual-testing gap are represented here and
in the active plan.

## Risk ranking

### P0: support-boundary risks

1. **Public-surface ambiguity.** Hundreds of re-exported names make accidental
   compatibility promises likely even with the generated inventory.
2. **Root-wide work.** The typed executor bounds one subtree, but normal
   `App` invalidation still rebuilds the root and lacks a keyed view-sequence
   diff.
3. **Native visual parity.** The software oracle now has exact goldens, but
   platform fonts, GPU output, and native screenshots still have no automated
   parity lane.
4. **Limited performance baseline.** One reviewed macOS arm64 baseline,
   structured counters, and an automated same-environment comparator exist, but
   no dispersion report, CI gate, or compatible baseline for another host exists.
5. **Documentation classification drift.** Stable, experimental, host-only, and
   planned behavior must use one vocabulary as exports and host claims change.

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
