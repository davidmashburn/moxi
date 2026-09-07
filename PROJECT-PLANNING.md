# Moxi execution plan

This plan converts the implementation audited in [CURRENT-STATE.md](CURRENT-STATE.md)
into a supportable product boundary. It deliberately prioritizes contracts and
evidence over more feature breadth.

## Product decision

Position Moxi as a **Mojo-native, inspectable UI and visualization core with
optional agent-safe capabilities**. Do not position it as feature parity with
Xilem, a native-widget wrapper, or a complete cross-platform application
framework.

The differentiator is the combination of:

- value-owned Mojo components and explicit mutation;
- a backend-neutral, inspectable rendering seam;
- deterministic headless behavior and performance accounting;
- native macOS presentation plus honest platform capability reporting;
- typed plotting built on the same scene/runtime contracts; and
- an optional authorization boundary for UI and agent actions.

## Contract decisions to hold

1. **State source of truth:** application/component values own durable UI
   state. Retained widgets own only interaction/render state needed between
   builds. Native handles, renderer caches, and task executors stay outside
   declarative values.
2. **Mutation path:** typed actions and normalized events are the only
   first-class mutations. Callbacks and live objects do not cross component,
   capability, serialization, or host ABI boundaries implicitly.
3. **Identity:** stable typed keys identify components, views, data rows, and
   resources. Integer offsets may remain an internal compatibility mechanism,
   but must not be the long-term composition API.
4. **Rendering oracle:** `Scene` plus declared resources is the portable
   correctness contract. Software rendering supplies deterministic evidence;
   native/GPU paths declare coverage and fallback explicitly.
5. **Serialization:** only versioned value specifications are serializable.
   `PlotSpec` is the model to follow. Components, platform handles, closures,
   caches, and leases are runtime-only.
6. **Support lanes:** every public feature is labeled `stable`, `provisional`,
   `experimental`, or `host-artifact`. Platform support separately records a
   portable contract, a buildable host, and a linked runtime.
7. **Examples are tests:** a capability is not demonstrated by a hand-built
   mirror. One scenario definition feeds its demo, contract test, visual
   reference, and benchmark where applicable.

## Reference and parity strategy

- Use `SoftwareSceneRenderer` as the deterministic renderer oracle and replay
  the same scene/resource corpus through SVG and supported native/GPU paths.
- Use real platform behavior for platform claims: CoreText/AppKit for macOS
  text and accessibility, browser Canvas/ARIA in a browser, and the actual
  UIKit/Android accessibility APIs when those targets advance. Static SVGs or
  hand-drawn widget imitations are documentation, not behavioral references.
- Compare structure, bounds, semantics, command order, and stable checksums
  exactly where possible. Use documented tolerances only for raster output
  that legitimately differs by platform, font, color space, or GPU.
- Record unsupported commands and fallback use as parity results. A visually
  plausible fallback must not silently count as native coverage.

## Gate 1: contract hardening

This was the next milestone. All six workstreams have now been exercised in
the ordered pass; new widget or plot-family work remains out of scope until
the follow-on boundaries below are deliberately accepted.

### Gate 1 progress at local `main` `9fcd3b5` (September 7, 2026; implementation follow-on `2987c39`)

The ordered implementation pass has delivered the Gate 1 slices. The status
below records what is proven in source and validation and leaves the remaining
support boundaries visible for the next pass.

| Ordered slice | Status | Evidence | Still open |
| --- | --- | --- | --- |
| 1. Public API audit | Inventory, focused import lanes, and compatibility/deprecation enforcement complete | `e418b29`, `7295e2e`, `721e50a`, generated `docs/api-status.md`, 887 export classifications, `docs/api-lanes.tsv`, `docs/api-compatibility.tsv`, `api-status-check`, `tests/api_lanes.mojo` | review each future move against the manifest and decide which provisional lanes become package promises |
| 2. Canonical scenario registry | Registry, consumer inventory, and descriptor-driven fixture records complete across all seven families; feature interaction state remains module-local | `0991f29`, `90f2aef`, `4ef1171`, `5f9c44b`, `332eb07`, and `a50900b`, seven descriptors, demo mapping, scenario checker, registry test, golden/benchmark metadata, and theme/capability/fractal records | make expected semantic/counter/checksum metadata descriptor-owned and enforce every behavior fixture through the catalog check |
| 3. Software goldens and browser lifecycle | Software/host gates complete; native text/scene replay, an offscreen screenshot tolerance lane, and a manually reviewed visible AppKit capture are exercised | `62a9caa`, `9c25379`, `b74d4eb`, and `707ff64`, seven exact PPM goldens, shared text corpus, CoreText replay, Metal scene replay, browser lifecycle evidence, native PPM capture, checked-in tolerance/mask report, and `/tmp/moxi-visible-appkit-current.mov` | retain visible-state review artifacts; real device/browser automation and a linked Mojo Web runtime remain open |
| 4. Typed localized execution | Keyed parent/child scheduling is integrated into the opted-in `App` path; deterministic indexes cover scope, dirty-component, keyed topology, and dependency-edge fanout; an out-of-order registration contract covers middle insertion/removal; a two-child preservation harness covers IME/focus, root scroll, sibling popup, accessibility identity, pointer capture, and deeper nested state; non-opted-in components retain an explicit root fallback | `676cbd4`, `b813e53`, `83030c3`, `06231a5`, `9606b24`, `15648d9`, `7b9d8bd`, and `2987c39`, `DependencyFanoutIndex`, `IntIndex`, `KeyedSubtreeDescriptor`, `KeyedSubtreeSchedule`, `KeyedSubtreeExecutor`, retained parent composition, keyed insertion/removal/reorder counters, `App.execution_work_counters()`, and execution/composed integration tests | reduce counted root-wide fallback as more components opt into localized hooks |
| 5. Structured benchmark profiles | Protocol, localized matrix, reviewed macOS baseline, same-environment comparison, dispersion policy, CI evidence, and a portable deterministic contract are complete | `4df99c8`, `850f610`, `75fea05`, `5a0e2ec`, `2a1a112`, `26aa56`, `64f27a2`, `363cae2`, `7137c48`, and `43e7cb0`; schema v2, `benchmark-quick`/`benchmark-full`, 1/10/100-child counters, policy-checked 30-run baseline, median/p95/MAD comparator, and cross-host quick contract | compatible reviewed full-profile baselines beyond macOS arm64 |
| 6. Documentation reconciliation | Main docs and planning ledger are current through the ordered implementation and release pass | `87e79bf`, `d6c008c`, `e428303`, `8100623`, `332eb07`, `b74d4eb`, `7295e2e`, `64f27a2`, `363cae2`, `721e50a`, `06231a5`, `707ff64`, `7137c48`, `43e7cb0`, `7e12d3c`, `9606b24`, `15648d9`, `7b9d8bd`, and this update; README/API/text/performance/benchmark/demo/comparison docs plus generated API status and status ledger | keep both branches synchronized as follow-on slices land |

The current-head repository gate passed at `2eeb802`: 70 Mojo tests,
API/demo/scenario/visual checks, native text and scene replay, native
screenshot tolerance evidence, host checks, package-consumer checks, and build
validation; the canvas vertical slice also passes its focused pixel/parity
tests, shared primitive/theme/plot fixtures, stable input-error checks,
canonical export, checksum manifest, benchmark task, and indexed-channel
package consumer. The release/package gate remains evidenced at
`7137c48`; the follow-on changes dependency fanout lookup and adds
interaction/state preservation assertions without changing the public API or
intended scheduling semantics. The clean full profile produced 30 samples
across 10 cases; the reviewed macOS baseline was refreshed after the native
geometry fix, and the comparator reports dispersion while enforcing the
registered host matrix. The portable quick contract also passes on the
candidate report. A visible AppKit
capture was manually reviewed, but this remains evidence for a host review
lane, not a claim that linked non-macOS runtimes or additional full-profile host
baselines are complete.

### 1. Classify and narrow the public API

The first pass landed the inventory, lane file, focused imports, and API check
at `7295e2e`; `721e50a` now makes compatibility/deprecation decisions
mechanical for future releases. The generated status, support-lane allowlist,
focused import paths, and compatibility manifest are all checked by the
release gate. Future API work must retain the one-minor-release shim policy
for documented moves and record deprecations in `CHANGELOG.md`.

Acceptance:

- every exported name has an owner module and support lane;
- package-consumer tests cover the stable lane plus explicit focused provisional
  opt-ins;
- adding an unclassified export fails validation; and
- README/API docs no longer call an experimental backend part of the 0.5
  compatibility promise.

### 2. Make scenarios first-class infrastructure

`src/moxi/scenarios.mojo` is now the registry rather than another showcase
module. It registers, without duplicating feature state:

| Scenario | Required consumers | Contract it proves |
| --- | --- | --- |
| form + component slot | demo, behavior test, golden | focus, editing, IME, clipboard, child identity |
| theme control states | demo, behavior test, golden | tokens, recipes, hover/pressed/focused/disabled/error states |
| 10k collection | demo, interaction test, benchmark | stable keys, reorder, popup, scrolling, bounded recycling |
| mixed text | headless/native test, golden | wrapping, grapheme edits, bidi/fallback reporting, accessibility |
| plot gallery | demo, spec round-trip test, golden, benchmark | typed data, transforms, interactions, software/SVG/Metal parity |
| capability walkthrough | demo, replay test | manifest, policy, approval, handler execution, audit sequence |
| fractal canvas | demo, renderer test, benchmark | Mojo compute feeding portable and Metal rendering paths |

Implementation targets are `src/moxi/scenarios.mojo`, the existing feature
modules, `tests/`, `examples/`, and `benchmarks/`. The registry should expose
stable ids, default bounds, deterministic seed/data, expected semantic nodes,
and expected counter/checksum metadata. It must not own windows or renderers.

Acceptance: changing a canonical fixture in one place updates every consumer;
the demo catalog check also verifies that registered scenarios have tests and
documented commands. The current implementation makes collection/plot
defaults, text probes, theme mode records, capability walkthrough steps, and
the fractal preset/depth records flow through registry-owned fixture tables.
Expected semantic, counter, and checksum metadata remains a follow-on
refinement.

### 3. Deliver one true localized-execution vertical slice

Extend the current accounting types into a typed subtree contract. Start with
the composed counter/form scenario rather than redesigning the entire view
model.

The keyed scheduler and counter contract landed at `83030c3`, and `06231a5`
integrates the typed keyed child path into `App` for components that opt in.
The normal `build()`/`update()` path intentionally remains an observable root
fallback for components that cannot yet provide localized hooks.

The stable keyed descriptor, typed child builder, parent composition, explicit
root fallback, and deterministic work counters are landed in the composed
`App` slice. `9606b24` adds a two-child preservation contract covering
marked-text/focus, root scroll offset, and a sibling modal popup across local
recomposition. `15648d9` adds a deterministic sorted integer index for scope,
dirty-component, descriptor, order, dirty-child, and child lookup while
retaining dense lists as the source of truth; `7b9d8bd` adds the out-of-order
registration/removal contract. `2987c39` adds a derived dependency-edge
fanout index, and the composed tests now cover accessibility identity, popup
pointer capture, and deeper nested local state. The remaining execution
boundary is adoption: non-opted-in components still use the counted root-wide
fallback.

Acceptance checks:

- updating one child runs one child builder and does not run an unrelated
  sibling builder (landed in `tests/execution.mojo`);
- focus, IME composition, root scroll offsets, sibling popup state,
  accessibility identity, popup pointer capture, and deeper nested state
  survive the composed local update (landed in `tests/composed.mojo`, with the
  fanout implementation in `2987c39`);
- stable topology identities use deterministic indexed lookup for the localized
  scope/dirty, keyed child, and dependency-edge fanout paths (landed in
  `src/moxi/execution.mojo` at `15648d9`, `7b9d8bd`, and `2987c39`); dense
  dependency storage remains the source of truth and root-wide fallback remains
  counted;
- insertion/removal/reorder has an explicit tested localized path, while
  root-wide fallback is counted (landed in `tests/execution.mojo`);
- a 1/10/100-child benchmark demonstrates bounded work using counters, with
  no wall-clock claim required; and
- all existing 68 test programs continue to pass.

### 4. Add deterministic visual regression

Use the software renderer first. Native screenshots remain a separate parity
lane; `707ff64` now captures the offscreen Metal scene and applies an explicit
threshold/mask policy without claiming pixel-identical native output.

The software corpus and browser lifecycle landed at `62a9caa`/`9c25379`; the
shared text corpus plus CoreText/Metal structural replay landed at `b74d4eb`;
and the software manifest/export/checker plus offscreen native screenshot
capture, comparison, and CI artifact upload landed at `707ff64`. The remaining
targets are:

- extend the native capture corpus beyond the compact scene to representative
  visible AppKit states and document the font/scale-specific masks;
- keep exact output for the software oracle and use the checked-in thresholded
  and masked policy only for explicitly native reference captures;
- add real device/browser automation and a linked Mojo Web runtime before
  calling those targets supported; and
- retain actual/expected/diff images and native reports as reviewable CI
  artifacts whenever a visual contract changes.

Acceptance: a one-pixel intentional software change produces a locally
inspectable diff; native captures report masked pixels and channel budgets;
baseline updates require an explicit command and change review; no demo-only
render path exists for a golden; and the browser host check has deterministic
readiness and teardown rather than depending on a developer-owned session.

### 5. Make performance results comparable

Preserve the current workloads and counters, then keep the result protocol
reviewable. The schema, quick/full commands, reviewed macOS baseline,
same-host comparator, dispersion policy, and portable quick contract are
landed. The remaining target is a clean full-profile baseline for each
additional host/compiler combination before enabling its wall-clock lane.

Acceptance: CI detects checksum/work inflation separately from noisy time,
validates the portable quick contract on any host, and uploads repeated
quick-profile evidence; release notes can link to a machine-readable baseline;
and the documentation does not promote a single workstation timing to a
universal claim. Additional full-profile hosts remain planned until their
compiler/runtime baselines are collected and reviewed.

### 6. Establish one documentation vocabulary

The vocabulary pass updated `README.md`, `ARCHITECTURE.md`, `docs/API.md`,
`docs/performance.md`, `docs/accessibility.md`, `docs/demo-browser.md`, and
`docs/xilem-comparison.md` on `main` from the generated support matrix and
scenario manifest. Future edits must preserve the same generated-status
workflow.

Required conventions:

- “implemented” means source plus a passing contract check;
- “supported” additionally requires a documented public lane and release gate;
- “host artifact” never implies a linked Mojo target;
- “deterministic reference” never implies native visual parity; and
- status snapshots identify the commit/release they describe.

Archive superseded long-form specifications instead of maintaining several
competing current roadmaps. The root README should explain how to evaluate the
project; architecture docs should explain ownership and boundaries; API docs
should list support status; the changelog should describe shipped deltas.

## Gate 1 exit criteria

- The stable/provisional public surfaces are mechanically classified.
- Six or more canonical scenarios are registered, with real demo and contract
  consumers; every fixture must still be made the single source for its golden
  and benchmark where relevant.
- At least one typed component subtree updates without a root rebuild, with a
  safe and observable root fallback.
- Deterministic software goldens run in CI and produce reviewable diffs.
- Benchmarks emit structured records, at least one environment-stamped reviewed
  baseline, a same-environment regression comparison with dispersion reporting,
  and repeated CI evidence; compatible baselines beyond macOS arm64 remain
  follow-on work.
- `pixi run release-check` passes and the support vocabulary is consistent
  across current docs.

## Follow-on gates

### Gate 2: text and native-macOS quality

- Extend the shared text corpus with richer fallback/font collections and
  paragraph cases.
- Define host-selected font collections and fallback policy around the
  HarfBuzz adapter; the current CoreText comparison is structural rather than
  glyph-id/pixel exact.
- Move AppKit queues/draw/accessibility storage from process-global fixed arrays
  toward instance-owned storage, or document and test a hard bounded profile.
- Prove native multi-window ownership, deep collection editing, menu/dialog
  lifecycle, drag/drop, and automated AX assertions incrementally.

Exit: the supported text subset and native ownership limits are testable rather
than prose, and two native windows cannot corrupt shared state.

### Gate 3: one real non-macOS runtime at a time

Select the first target using runtime/toolchain feasibility, not novelty. Run
the same compact form + plot scenario end to end through a linked Mojo runtime,
with readiness, input replay, accessibility publication, screenshot/checksum,
teardown, and a baseline. Only then repeat for another target.

The current UIKit, Android, and browser shells remain valuable host artifacts.
They are not three simultaneous implementation commitments.

Exit per target: a clean machine can build and run the scenario; CI or a
documented device harness proves startup, interaction, accessibility, and
teardown; capability reporting matches observed behavior.

### Gate 4: supported 2D plotting package

- Stabilize the implemented `PlotDataTable`/`PlotSpec`/`PlotRuntime` subset and
  document version migration.
- Add streaming invalidation, export quality, text/legend layout, interaction
  replay, and accessible data-table navigation using canonical fixtures.
- Require parity evidence across software, SVG, and each supported native/GPU
  backend.
- Evaluate Cairo for vector/PDF export and wgpu for a portable GPU backend only
  with a prototype against the scene corpus; integration is contingent on
  reduced maintenance or new target coverage.

Exit: the declared 2D subset is inspectable without a renderer, deterministic
under update/replay, accessible, exportable, and performance-baselined.

## Research reconciliation

The Modular ecosystem research changes emphasis but does not justify a broad
rewrite:

| Research signal | Decision |
| --- | --- |
| Human-owned architecture with agent-generated repetitive coverage | Keep API/ownership decisions explicit; use agents for test matrices, fixtures, adapters, and doc synchronization. |
| `mozz` mutation/property testing | Expand deterministic properties now; pilot fuzzing only when failures can be replayed and shrunk into checked-in cases. |
| Terminal and HTML UI projects favor small, teachable layers | Keep progressive, copyable demos; do not hide behavior behind showcase-only helpers. |
| Toolkit bindings expose linker/platform-path cost | Preserve scalar host ABIs and honest capability gates rather than moving core state into an external toolkit. |
| Cairo and wgpu offer adjacent rendering paths | Evaluate them as scene adapters after the corpus exists; do not adopt both speculatively. |
| Mojo’s GPU direction is differentiating | Keep fractal and dense-plot scenarios as first-class compute-to-visualization proofs. |
| Mojo 1.x raises stability expectations | Classify the public surface and add compatibility policy before the next breadth wave. |

## Explicit non-goals for the next gate

- new public widget types or plot mark families;
- polar, geographic, 3D, contour, or candlestick plotting;
- production iOS, Android, Web, Windows, or Linux claims;
- a second GPU backend;
- arbitrary runtime reflection or a browser IDE;
- a network transport, persistence layer, or bundled LLM client for the
  capability bus; and
- performance marketing based on the current local benchmark numbers.

## Recommended implementation sequence

1. Public export inventory, focused lanes, compatibility enforcement, and
   documentation vocabulary (landed).
2. Scenario registry and descriptor-owned fixtures (landed; expected metadata
   ownership remains a follow-on refinement).
3. Software golden export/checker plus native screenshot evidence (landed).
4. Localized composed-child execution with work counters and an opt-in `App`
   parent/child path (landed; IME/focus, root scroll, sibling popup,
   accessibility identity, pointer capture, and deeper nested state are covered
   by the composed harness; deterministic topology indexes are covered at
   `15648d9`, `7b9d8bd`, and `2987c39`; non-opted-in components retain the
   counted root-wide fallback).
5. Structured quick/full benchmark output, reviewed macOS baseline, and the
   portable deterministic contract (landed; other full hosts remain planned).
6. Final Gate 1 documentation reconciliation and release decision (landed in
   the current handoff); ecosystem convergence E0 is documented on local
   `main` at `9fcd3b5`, with the exact canvas compatibility result and dataviz
   inventory recorded; E2's local nightly/package gate is complete at
   `2eeb802` from the resolved toolchain pair, while E1/E4 remain gated on
   portable packaging and Python ABI decisions. Uploading the two package
   artifacts to a chosen public channel remains an external release action.

This order makes each later slice consume infrastructure already reviewed by
the previous one and keeps the first milestone independently shippable.
