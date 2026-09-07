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

This is the next milestone. All six workstreams are required; new widget or
plot-family work is out of scope.

### Gate 1 progress at `main` `2a1a112`

The ordered implementation pass has delivered the first vertical slices. The
status below is deliberately narrower than “Gate 1 complete”: it records what
is proven in source and validation, and leaves the unfinished acceptance work
visible for the next pass.

| Ordered slice | Status | Evidence | Still open |
| --- | --- | --- | --- |
| 1. Public API audit | Complete | `e418b29`, generated `docs/api-status.md`, 855 export classifications, `api-status-check` | focused import paths, compatibility/deprecation policy, and package-lane enforcement |
| 2. Canonical scenario registry | Registry and consumer inventory complete; fixture wiring partial | `0991f29` and `90f2aef`, seven descriptors, demo mapping, scenario checker, registry test, golden/benchmark metadata | make each descriptor the fixture/data source for its behavior test, golden, and benchmark |
| 3. Software goldens and browser lifecycle | Software/host gates complete | `62a9caa` and `9c25379`, seven exact PPM goldens, manifest/checker, ephemeral server/host harness with Canvas/ARIA/input/teardown evidence | native screenshot parity, real-browser/device automation, and linked Mojo Web runtime |
| 4. Typed localized execution | One-subtree slice complete | `676cbd4` and `b813e53`, `TypedSubtreeExecutor`, `ExecutionWorkCounters`, localized test and benchmark; explicit paint return type passes precompile | parent scheduling, keyed view diff, insertion/removal/reorder, and root-fallback accounting |
| 5. Structured benchmark profiles | Protocol, localized matrix, and one reviewed macOS baseline complete | `4df99c8`, `850f610`, `75fea05`, `5a0e2ec`, and `2a1a112`; schema v2, `benchmark-quick`/`benchmark-full`, 1/10/100-child counters, and 30-run `benchmarks/results/macos-arm64-full.json` | automated same-environment comparison/variance policy and compatible baselines beyond macOS arm64 |
| 6. Documentation reconciliation | Main docs and planning ledger current | `87e79bf`, `d6c008c`, README/API/visual/performance/demo/comparison docs plus generated API status and status ledger | keep both branches synchronized as follow-on slices land |

`pixi run check` and `MOXI_BENCHMARK_RUNS=1 pixi run release-check` pass at this
revision, including all 66 Mojo test programs, native/Android/iOS host builds,
package publication/consumer, the software corpus, Web lifecycle harness,
HarfBuzz, live reload, and the complete 10-case benchmark matrix. This is
evidence for the completed slices, not a claim that the remaining Gate 1 exit
criteria are satisfied.

### 1. Classify and narrow the public API

Implementation targets:

- add `docs/api-status.md` on `main` with one generated row per name exported
  by `src/moxi/__init__.mojo`;
- group exports into stable core, provisional plotting, experimental renderer,
  host adapter, demo/support, and internal lanes;
- add a source-controlled allowlist checked by `scripts/check.sh` so a new
  re-export requires an explicit support classification;
- introduce focused import paths for plotting, experimental Metal, demo
  browser, and host adapters; and
- retain compatibility shims for one minor release when moving a documented
  name, with deprecations recorded in `CHANGELOG.md`.

Acceptance:

- every exported name has an owner module and support lane;
- package-consumer tests cover only the stable lane plus explicit provisional
  opt-ins;
- adding an unclassified export fails validation; and
- README/API docs no longer call an experimental backend part of the 0.5
  compatibility promise.

### 2. Make scenarios first-class infrastructure

Turn `src/moxi/scenarios.mojo` into the registry rather than another showcase
module. Register, without duplicating feature state:

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
documented commands.

### 3. Deliver one true localized-execution vertical slice

Extend the current accounting types into a typed subtree contract. Start with
the composed counter/form scenario rather than redesigning the entire view
model.

Implementation targets:

- add a stable keyed subtree/slot descriptor in `component.mojo` that owns a
  typed child builder and local state without public id-offset arithmetic;
- let `App` rebuild a dirty child description, splice it into the parent view,
  reconcile that region, and accumulate its bounds in `Invalidation`;
- preserve root-wide rebuild as an explicit fallback for structure or bounds
  dependencies that cannot yet be localized;
- make `LocalizedExecution` topology lookup bounded by key/index structures
  rather than repeated linear scans before applying it to large trees; and
- add deterministic counters for builders run, nodes reconciled, nodes laid
  out, commands repainted, and fallback-to-root events.

Acceptance checks:

- updating one child runs one child builder and does not run an unrelated
  sibling builder;
- focus, IME composition, scroll offsets, popup capture, accessibility ids,
  and stable retained state survive the local update;
- insertion/removal/reorder has an explicit tested fallback or localized path;
- a 1/10/100-child benchmark demonstrates bounded work using counters, with
  no wall-clock claim required; and
- all existing 66 test programs continue to pass.

### 4. Add deterministic visual regression

Use the software renderer first. Native screenshots are a separate parity
lane, not the initial oracle.

Implementation targets:

- add `tests/goldens/manifest.json` mapping scenario/state, dimensions,
  renderer version, expected checksum, and image path;
- add a deterministic image export to `SoftwareSceneRenderer` (a simple
  lossless format is sufficient) and `scripts/visual_check.sh`;
- check exact output for the software oracle; use thresholded and masked diffs
  only for explicitly native reference captures;
- cover every theme control state, the mixed-text fallback corpus, nested
  clipping/scrolling, accessibility focus, and the core plot gallery; and
- upload actual/expected/diff images as CI artifacts on failure; and
- extend the existing Web host check with one deterministic browser harness:
  start a local server on an allocated port, wait for a scenario-ready marker,
  replay input against `native/web/host_demo.html`, capture Canvas and ARIA
  state, and always tear down the browser and server.

Acceptance: a one-pixel intentional change produces a locally inspectable diff;
baseline updates require an explicit command and change review; no demo-only
render path exists for a golden; the browser host check has deterministic
readiness and teardown rather than depending on a developer-owned session.

### 5. Make performance results comparable

Preserve the current workloads and counters, then add a result protocol.

Implementation targets:

- add `benchmarks/result-schema.json` and make each benchmark optionally emit
  one JSON record containing git revision, dirty flag, Mojo/compiler version,
  OS/architecture, workload parameters, warmup/run counts, deterministic
  counters/checksum, and timing samples;
- provide `pixi run benchmark-quick` for correctness/counter regressions and
  `pixi run benchmark-full` for repeated local/release measurements;
- commit reviewed release baselines under `benchmarks/results/`, not every CI
  sample;
- compare medians and dispersion only within compatible environments; and
- add a 10k-node retained scenario and the localized 1/10/100-child workload
  missing from the current small retained benchmark.

Acceptance: CI detects checksum/work inflation separately from noisy time;
release notes can link to a machine-readable baseline; the documentation does
not promote a single workstation timing to a universal claim.

### 6. Establish one documentation vocabulary

Update `README.md`, `ARCHITECTURE.md`, `docs/API.md`, `docs/performance.md`,
`docs/accessibility.md`, `docs/demo-browser.md`, and `docs/xilem-comparison.md`
on `main` from the generated support matrix and scenario manifest.

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
- Benchmarks emit structured records and at least one environment-stamped
  reviewed baseline; automated same-environment regression comparison remains
  required for exit.
- `pixi run release-check` passes and the support vocabulary is consistent
  across current docs.

## Follow-on gates

### Gate 2: text and native-macOS quality

- Build a shared text corpus covering grapheme boundaries, mixed bidi,
  fallback fonts, wrapping, selection, replacement ranges, and IME.
- Define host-selected font collections and fallback policy around the
  HarfBuzz adapter; compare shaped runs to CoreText for the supported corpus.
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

1. Public export inventory and documentation vocabulary.
2. Scenario registry and manifest, starting with theme states and composed
   components.
3. Software golden export/checker, consuming those scenarios.
4. Localized composed-child execution with work counters and root fallback.
5. Structured quick/full benchmark output, including localized workloads.
6. Final Gate 1 documentation reconciliation and release decision.

This order makes each later slice consume infrastructure already reviewed by
the previous one and keeps the first milestone independently shippable.
