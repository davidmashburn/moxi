# Moxi current-state audit

Audited September 7, 2026 against `main` at `7e12d3c`. This document is based
on source, tests, build scripts, and local validation. README, changelog, and
older roadmap claims were treated as hypotheses until the implementation
confirmed them.

## Executive assessment

Moxi is no longer a small post-0.5 prototype. It contains a broad UI runtime,
native macOS host, software and Metal scene paths, a capable plotting stack,
accessibility bridges, a capability bus, a demo browser, and extensive contract
tests. The breadth is ahead of its support story.

Gate 1 now has a coherent, measurable implementation boundary: the package
export surface has generated support and compatibility/deprecation inventories
plus focused import lanes, seven canonical scenario descriptors are checked
in, software-renderer PPM goldens and a browser-host lifecycle harness run
through validation, typed localized execution is integrated into the opted-in
`App` parent/child path, shared text and native/software structural parity
contracts are exercised, offscreen Metal screenshot tolerance evidence is
archived, and quick/full benchmark profiles emit structured JSON. One reviewed
macOS arm64 full-profile baseline is policy-checked; the comparator reports
median/p95/MAD dispersion, and a host-independent quick contract validates
portable structural signatures. Collection and plot fixture defaults derive
their size and seed from the canonical registry, and the other five scenario
families expose registry-owned text, labels, modes, defaults, or preset
matrices. The next risk is not missing features; it is making those slices
compose into a smaller supportable contract. The package boundary still
re-exports hundreds of names, non-opted-in components retain a counted
root-wide fallback, compatible full-profile baselines beyond macOS arm64 are
not yet reviewed, and linked Mojo runtimes remain unavailable on non-macOS
targets.

## Validation performed

| Check | Result | What it proves |
| --- | --- | --- |
| repository audit and sequential commits | `main` is audited at `7e12d3c`; `project-planning` retains the Modular/Mojo ecosystem research plus this progress ledger | the code and plan were reconciled against the latest local implementation rather than trusting older prose |
| `pixi run test` | pass, 68 Mojo test programs, including keyed scheduling, composed-child, text corpus, and parity contracts | portable unit and integration contracts compile and execute together |
| `pixi run check` | pass at `7137c48`, including API/demo/scenario/visual, 68 tests, native text/scene replay, native screenshot tolerance, host, build, and release-support checks | the full repository validation path covers the completed ordered slices |
| `pixi run release-check` | pass at `7137c48`; package consumer, 68-test/native/host gate, and clean 30-run full benchmark all completed | the distributable package and release wrapper validate the completed ordered slices |
| clean full-profile baseline | 30 runs across 10 cases, `git_dirty: false`, refreshed at `43e7cb0` from the corrected implementation report | deterministic counters/checksums, dispersion samples, and the measured environment are durable for future same-environment review |
| `MOXI_BENCHMARK_RUNS=3 pixi run benchmark-full` | pass for 10 cases with a clean schema-v2 report after the fixture/parity slices | the complete matrix is repeatable from a clean tree and emits deterministic counters/checksums plus per-run status/timing and environment metadata |
| `pixi run benchmark-compare` | pass for 10 cases against the refreshed reviewed macOS arm64 baseline | compatible environment metadata and deterministic signatures match; median and p95 limits are evaluated while median/p95/MAD dispersion is printed |
| `MOXI_BENCHMARK_RUNS=3 pixi run benchmark-quick` plus `benchmark-contract-check` | pass for 3 cases and 9 samples, including the host-independent portable contract | repeated quick evidence is available for review without promoting wall-clock values to a cross-host baseline |
| `pixi run native-screenshot-check` | pass: 10,240 pixels, 2 tolerated line-edge mismatches, checked-in CoreText mask, report under `dist/native-artifacts/` | offscreen Metal capture is compared against the software oracle with explicit channel/mismatch budgets |
| `pixi run visual-check` / `pixi run browser-check` | pass for 7 PPM images / the host lifecycle JSON contract | software pixels are compared exactly; the Web page and host publish readiness, Canvas, input, ARIA, and teardown evidence |
| source/build inspection | 295 tracked files, 190 tracked Mojo files, 73 Mojo test files | the aggregate test runner covers 68 programs; `golden_render.mojo`, `live_reload.mojo`, `native_scene_parity.mojo`, `native_text_parity.mojo`, and `package_consumer.mojo` are exercised by dedicated scripts |

## Gate 1 implementation ledger

The ordered implementation pass is recorded here so the plan does not imply
that a partial vertical slice is a complete product claim.

| Workstream | Status at `7e12d3c` | Evidence | Remaining boundary |
| --- | --- | --- | --- |
| Public API inventory | Implemented with focused import lanes and compatibility/deprecation enforcement | `docs/api-status.md`, `docs/api-lanes.tsv`, `docs/api-compatibility.tsv`, `scripts/api_status_check.sh`, `tests/api_lanes.mojo`, 887 classified exports, `721e50a` | review future moves and decide which provisional lanes become package promises |
| Canonical scenarios | Registry, consumer inventory, and descriptor-driven fixture records implemented across all seven families | `src/moxi/scenarios.mojo`, `scripts/scenario_check.sh`, `4ef1171`, `5f9c44b`, `a50900b`, `332eb07`, demo catalog mapping, registry contract test, golden/benchmark metadata | make expected semantic/counter/checksum metadata descriptor-driven and enforce every behavior fixture in the catalog check |
| Software visual regression | Implemented for software oracle; native structural replay and offscreen screenshot tolerance are exercised | seven lossless PPM images, manifest, exact checker, shared text corpus, CoreText replay, Metal scene replay, `707ff64` native PPM/policy/report, reviewable actual/expected/diff artifacts | extend native evidence to visible AppKit states and retain explicit font/scale masks |
| Browser host lifecycle | Implemented as deterministic host gate | `scripts/browser_check.sh`, `tests/web_browser_harness.mjs`, readiness/Canvas/ARIA markers | linked Mojo Web runtime and real-browser/device automation in CI |
| Typed localized execution | Implemented as a keyed parent/child scheduling slice integrated into the opted-in `App` path; non-opted-in components remain root-wide | `TypedSubtreeExecutor`, `KeyedSubtreeDescriptor`, `KeyedSubtreeSchedule`, `KeyedSubtreeExecutor`, `src/moxi/app_runtime.mojo`, `tests/execution.mojo`, `tests/composed.mojo`, localized benchmark, `06231a5` | bounded topology indexes and state-preserving local updates through IME/scroll/popup paths |
| Structured benchmarks | Protocol, localized matrix, one reviewed macOS baseline, same-environment comparison, dispersion policy, CI evidence, and a host-independent quick contract implemented | `scripts/benchmark.sh`, `scripts/benchmark_compare.py`, `scripts/benchmark_contract_check.py`, `scripts/benchmark_policy_check.py`, schemas/policy, `benchmarks/results/macos-arm64-full.json`, `portable-quick-contract.json`, `docs/benchmarking.md`, localized 1/10/100 matrix, `7137c48`, `43e7cb0` | collect and review compatible full-profile baselines beyond macOS arm64 |
| Documentation vocabulary | Reconciled on `main` through `7e12d3c` | README/API/text/benchmark/performance/visual/demo/comparison docs, changelog, generated API status, and this status ledger | keep status snapshots synchronized as the public surface changes |

The quick benchmark run is a smoke check, not a baseline. It includes compiler
or process startup for several workloads; its repeated structured report is
intentionally written to ignored local output and uploaded by CI only as review
evidence. The policy-registered full baseline remains host/compiler specific.

## Capability matrix

| Area | Implementation truth | Confidence | Evidence in `main` | Planning consequence |
| --- | --- | --- | --- | --- |
| Package and public API | The package is versioned `0.5.1`, `src/moxi/__init__.mojo` is about 900 lines and imports from 74 module groups, and all 887 current exports have generated support-lane rows plus a compatibility/deprecation manifest. Focused plotting, host, and experimental import paths are available, while stable 0.5 names and post-0.5 experiments still share the root boundary. | High | `pixi.toml`, `shelf.toml`, `src/moxi/__init__.mojo`, `docs/api-status.md`, `docs/api-lanes.tsv`, `docs/api-compatibility.tsv`, `tests/api_lanes.mojo`, package-consumer check | Review each future move against the manifest and decide which provisional lanes become package promises. |
| Component ownership | `Component.build(bounds)` returns a value tree and `update(event, view)` owns mutation. `ComponentSlot` and `KeyedSubtreeDescriptor` provide typed child ownership with stable keys and private id namespaces. | High | `src/moxi/component.mojo`, `src/moxi/composed.mojo`, component/composed tests | Integrate the keyed descriptor with parent event dispatch without leaking id arithmetic. |
| Execution and reconciliation | `(id, kind)` reconciliation reuses retained nodes and reports changes. `TypedSubtreeExecutor` owns one typed component/view/runtime; `KeyedSubtreeExecutor` retains several typed children by key, composes cached views, and counts structural work. Opted-in `App` components dispatch to a keyed child, recompose the parent, and preserve focus; components without localized hooks still record an explicit root fallback. | High | `src/moxi/runtime.mojo`, `src/moxi/execution.mojo`, `src/moxi/app_runtime.mojo`, `src/moxi/composed.mojo`, `tests/execution.mojo`, `tests/composed.mojo`, `06231a5` | Replace repeated topology scans with bounded indexes and extend local state-preservation coverage through IME, scroll, and popup paths. |
| Layout and interaction | Column/row, stack, grid, split, portal, constraints, clipping, automatic overflow, draggable/pageable scrollbars, stable-key variable-height recycling, focus, pointer, keyboard, IME, clipboard, popup, reorder, and accessibility actions are implemented and tested. | High | `src/moxi/view.mojo`, `layout_primitives.mojo`, `scrollbar.mojo`, `popup.mojo`, `reorder.mojo`, interaction tests | Treat this as an existing contract to protect, not a roadmap item. Do not broaden layout until regression scenarios are shared. |
| Themes and recipes | Semantic tokens, dark/light/zinc/emerald presets, recipes, an interactive theme showcase, and contract tests exist. Theme inheritance was fixed in the audited commit, and theme states are represented in the software golden corpus. | High | `tokens.mojo`, `recipes.mojo`, `theme_showcase.mojo`, theme tests, `tests/goldens/` | The old token/recipe proposal is complete. Remaining work is native/platform visual parity and continued API support classification. |
| Rendering | Paint commands feed an inspectable scene IR. Software rendering is deterministic and now has seven exact PPM goldens; AppKit is the main native UI renderer; Metal supports a substantial geometry/text/image/path slice and dense plot packets. Native scene replay and an offscreen screenshot tolerance check now compare the same compact scene; pixels remain platform-dependent. | High for contracts; medium for parity | `paint.mojo`, `scene.mojo`, `software.mojo`, `macos.mojo`, `metal.mojo`, `tests/goldens/`, `tests/native_scene_parity.mojo`, `tests/native_screenshot_policy.json`, native sources and renderer tests | Extend evidence to visible AppKit states and keep font/scale masks explicit; do not imply pixel-identical native output. |
| Native capacity | AppKit storage is process-global and statically capped at 128 entries per draw/accessibility kind; custom draw and Metal resources have other explicit ceilings. Overflow is generally observable. | High | `native/macos_window.m`, `native/macos_metal.m` | Multi-window/native scaling cannot be called supported until ownership and capacity become instance-scoped or explicitly bounded by contract. |
| Text | Portable shaping is deterministic and deliberately approximate. A shared corpus covers combining/bidi/fallback/wrapping/editing/IME; CoreText supplies real macOS shaping/fallback and native replay checks structural invariants. Optional HarfBuzz still uses one host-selected font and does not provide a production fallback collection or full paragraph bidi policy. | High | `text_boundary.mojo`, `text_shaping.mojo`, `coretext.mojo`, `harfbuzz.mojo`, `scenarios.mojo`, `tests/text_conformance.mojo`, `tests/native_text_parity.mojo` | Extend font-collection/paragraph policy and align native screenshot masks with the declared font/scale boundaries. |
| Accessibility | Portable semantics, validation, native macOS AX, Web ARIA, and iOS/Android virtual-node sources exist. Device/screen-reader automation and live Mojo publication on non-macOS targets do not. | High | `accessibility.mojo`, `native_widgets.mojo`, native host sources, accessibility tests | Keep “semantic bridge” separate from “verified platform support.” |
| Platforms | macOS Apple Silicon is the only package target. iOS simulator, Android APK, and browser host artifacts are buildable when SDKs are present, but they do not host a linked Mojo application runtime. The Web host now has an ephemeral-server lifecycle harness with readiness, Canvas, input, ARIA, and teardown assertions. CI is macOS-only and some host checks skip when SDKs are absent. | High | `pixi.toml`, `.github/workflows/ci.yml`, `scripts/host_check.sh`, `scripts/browser_check.sh`, `tests/web_browser_harness.mjs`, `native/` | The next platform gate is one linked Mojo runtime on a real target with the same scenario and accessibility evidence—not more adapter types. |
| Plotting | Typed columnar data, stable keys, versioned JSON spec parsing, transforms, statistical recipes, facets, interaction, selection/linking, LOD, accessibility/CSV, software/SVG, and a Metal packet path are implemented. Several advanced mark families and exports remain absent. | High | `plot_*.mojo`, `plotting.mojo`, plot tests/benchmarks | Harden the implemented 2D subset as a provisional package; do not chase polar, geographic, 3D, or new marks yet. |
| Capability bus | In-process descriptors, schemas, policy, approvals, replay, typed handlers, leases, queue bounds, and walkthrough automation exist. Transport, persistence, deadlines/cancellation, and external execution remain outside the core. | High | `capability.mojo`, `conversation.mojo`, capability tests/walkthrough | Keep it optional and transport-neutral. Stabilize the authorization contract before adding an agent runtime. |
| Scenarios and demos | Real demos mount in one browser and source panels show component code. `scenarios.mojo` centralizes seven stable descriptors; collection/plot factories and text/theme/capability/fractal consumers use registry-owned fixture records, including the shared text corpus consumed by portable/native parity tests. | High | demo browser, `scenarios.mojo`, `tests/scenarios.mojo`, `tests/golden_render.mojo`, form/theme/capability/fractal/text modules, `4ef1171`, `5f9c44b`, `a50900b` | Make each descriptor own expected semantic/counter/checksum metadata and enforce that mapping in the catalog check. |
| Tests and visual QA | Contract coverage is broad, the software renderer exposes deterministic checksums, and seven lossless PPM goldens run through `scripts/visual_check.sh` with reviewable mismatch artifacts. Native text and scene structural parity plus the offscreen screenshot tolerance policy run on macOS; visible AppKit screenshot parity remains a host review lane. | High | `scripts/test.sh`, `scripts/visual_check.sh`, `scripts/native_screenshot_check.sh`, `tests/goldens/`, `tests/native_text_parity.mojo`, `tests/native_scene_parity.mojo`, `tests/native-screenshot-policy.json`, renderer tests, `docs/*.svg` | Extend native captures to visible states and add real device/browser automation before claiming linked non-macOS support. |
| Benchmarks | Quick/full profiles preserve the existing workloads and emit structured JSON with commands, status, wall time, deterministic metric lines, and environment metadata. A policy-checked reviewed macOS arm64 full-profile baseline is committed; the comparator reports median/p95/MAD and rejects incompatible hosts, while the portable quick contract checks structural signatures on any host and CI uploads repeated evidence. | High | `scripts/benchmark.sh`, `scripts/benchmark_compare.py`, `scripts/benchmark_contract_check.py`, `scripts/benchmark_policy_check.py`, `benchmarks/result-schema.json`, `benchmarks/contract-schema.json`, `benchmarks/benchmark-policy.json`, `benchmarks/results/`, `docs/benchmarking.md`, `docs/performance.md`, `.github/workflows/ci.yml` | Collect and review compatible full-profile baselines beyond macOS arm64 before making cross-environment timing claims. |

## What the prior planning got wrong or outgrew

- The September 1 theme and recipe plan described work that now exists on
  `main`; keeping it as an active plan obscured the real gap.
- The all-states/Storybook direction partially landed as the theme showcase and
  richer demo browser. Software screenshot diffing now exists as a checked-in
  PPM corpus; offscreen native screenshot capture has an explicit
  tolerance/mask report, while visible AppKit capture and platform-dependent
  review remain separate work.
- The old post-0.5 roadmap mixed completed Metal, virtualization, plotting,
  scrolling, and host-artifact slices with future work. Status prose had grown
  longer than the remaining decisions.
- “Cross-platform” was sometimes used for portable contracts, buildable native
  shells, and live Mojo targets. These are materially different support levels.
- Localized execution was described as present before there was a typed owner;
  the code now proves a typed subtree slice integrated into opted-in `App`
  dispatch, while ordinary components still expose dependency accounting
  around a root-wide rebuild.

The obsolete proposal files have been removed from this branch. Their
implemented outcomes and remaining visual-testing gap are represented here and
in the active plan.

## Risk ranking

### P0: support-boundary risks

1. **Public-surface ambiguity.** Hundreds of re-exported names still make
   accidental compatibility promises likely; the generated inventory and
   compatibility manifest now make changes reviewable rather than implicit.
2. **Root-wide work.** The typed executor and opted-in `App` lane bound one
   subtree, but ordinary components still rebuild the root and the topology
   lookup lacks bounded key/index structures.
3. **Native visual parity.** The software oracle has exact goldens and the
   offscreen Metal path has a tolerance/mask report, but visible AppKit output,
   platform fonts, and device/browser automation remain host review lanes.
4. **Limited performance baseline.** One reviewed macOS arm64 baseline,
   structured counters, dispersion reporting, a portable quick contract, and
   an automated same-environment comparator exist; compatible full-profile
   baselines for other hosts are still planned.
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
