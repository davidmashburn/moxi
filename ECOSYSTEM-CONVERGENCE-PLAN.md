# Moxi ecosystem convergence plan

Status: proposed follow-on plan  
Planning baseline: September 7, 2026
Implementation branch: `main`  
Planning branch: `project-planning`

## 1. Purpose

This plan defines the work needed to deliver three related outcomes:

1. make Moxi usable as a headless Python plotting and rendering library;
2. integrate `canvas_mojo` as Moxi's primary portable raster and export
   backend without making it the only renderer; and
3. absorb the useful plotting capabilities of `dataviz_mojo` into Moxi Plot
   without replacing Moxi's data, specification, interaction, accessibility,
   or retained-runtime contracts.

These outcomes form one convergence program. They share the same plot model,
scene contract, canonical scenarios, parity references, packaging work, and
release evidence. They must not be implemented as three unrelated adapters.

## 2. Coordination boundary with the active implementation thread

ThreadBridge was used to read T3 thread
`f66d9699-3bd8-4505-8163-15ce7e0038a8`, "Deep-Dive Project Planning",
directly. At the final handoff, that thread had:

- completed the original five Gate 1 slices;
- landed generated API compatibility/deprecation enforcement at `721e50a`;
- landed keyed child dispatch integration into `App` at `06231a5`;
- landed native screenshot capture, tolerance, mask, and evidence at
  `707ff64`;
- landed the host-independent quick benchmark contract at `7137c48`; and
- refreshed the reviewed macOS arm64 full baseline at `43e7cb0` after the
  native renderer correction.

This plan does **not** own or duplicate those files or outcomes. In particular,
it must not modify the implementation thread's native screenshot
implementation, benchmark-host policy, API compatibility snapshot, or keyed
`App` integration as part of the ecosystem convergence work. Those boundaries
are complete for the current handoff and remain the source of truth.

The read-only rebaseline is complete: local `main` is at `0da2c8c`, with the
runtime follow-on at `2987c39`, and the planning branch retains the research
and Gate 1 evidence. The latest implementation slices cover IME/focus, root
scroll, sibling popup, accessibility identity, pointer capture, and deeper
nested-state preservation through local recomposition, then add deterministic
indexed lookup for localized, keyed-topology, and dependency-edge fanout
identities. A genuine visible AppKit capture has also been exercised and
manually reviewed. Ecosystem work may now start from these facts; linked
non-macOS runtimes and additional full-profile host baselines remain explicit
follow-on boundaries.

The E0 feasibility work is now measured rather than assumed. The exact-pinned
`canvas_mojo` v0.21.0 revision
(`27401fe83c76488fe3b3ab2dcd12ad09333bba51`) runs its own Mojo 1.0.0 smoke,
but the same source did not compile in Moxi's Mojo 1.1.0.dev2026082605
environment because of `std.runtime.asyncrt`, `InlineArray`, and decorator
syntax incompatibilities. That compatibility work is now carried by the
short-lived fork branch
`davidmashburn/canvas_mojo@moxi/mojo-nightly` at
`323154f9399f4ecfa6d5d2fb0fc7d87883fe3c1e`. The fork's package build pins
the compiler exactly to Moxi's nightly, and Moxi pins the full Git SHA. Core
canvas tests, package precompilation, and a real `from canvas import ...`
consumer probe pass in Moxi's installed environment. No Python extension was
claimed: the value-boundary architecture is documented, but its clean-wheel
import probe remains open. E2 is now unblocked at the toolchain boundary, but
the renderer vertical slice is still unimplemented; E1/E4 remain gated on
portable packaging and Python ABI decisions.

Existing Gate 2 and Gate 3 commitments in `PROJECT-PLANNING.md` also remain in
force. This plan expands the supported-2D-plotting direction in Gate 4; it does
not silently claim that native macOS quality or a linked non-macOS application
runtime has been completed.

## 3. Product and architecture decisions

The target architecture is:

```text
Python moxi facade
        |
        v
versioned value/buffer binding boundary
        |
        v
PlotDataTable + PlotSpec + PlotRuntime
        |
        +--------------------+
        v                    v
      Scene          PlotRenderPacket
   /    |    \               |
canvas  SVG  AppKit/Metal   dense Metal

dataviz_mojo -> executable reference and algorithm source during convergence
```

The following decisions hold unless an ADR explicitly replaces one:

1. **Moxi owns the product model.** `PlotDataTable`, versioned `PlotSpec`,
   `PlotRuntime`, stable row keys, interaction state, semantics, accessibility,
   and LOD remain Moxi contracts.
2. **Scene remains backend-neutral.** `canvas_mojo` implements a renderer and
   export path. Moxi does not expose canvas internals as its core scene API.
3. **The software renderer remains the deterministic oracle.** It is retained
   until the canvas path has declared parity coverage and migration evidence.
4. **Existing renderers remain valid.** Canvas does not remove SVG, AppKit, or
   Metal. A later support decision may change defaults only after measurements
   and compatibility review.
5. **Python starts headless.** The first Python product renders plots and
   returns files or buffers. Native windows, callbacks, and event-loop control
   are separate future scope.
6. **Python crosses a value boundary.** Initial bindings accept serialized
   specifications and typed contiguous column buffers. They do not expose
   Mojo object layout, borrowed native handles, or renderer lifetimes.
7. **Dataviz is converged, not source-dumped.** The real upstream library is a
   parity oracle. Layout algorithms may be ported, shared, or upstreamed with
   attribution, but its fluent `Plot` object does not replace Moxi's runtime.
8. **Every new mark is cross-surface.** A mark is not absorbed merely because
   it draws a static picture; its schema, validation, Scene output,
   accessibility, Python exposure, parity evidence, and benchmark status must
   be declared.

## 4. Upstream and dependency policy

The upstream projects are:

- `https://github.com/randyzwitch/canvas_mojo`
- `https://github.com/randyzwitch/dataviz_mojo`

Both must be treated as independently versioned projects. Before dependency
changes, record their license, selected revision, supported Mojo/compiler
range, supported platforms, transitive dependencies, and any local patches.

MojoShelf searches for `canvas`, `canvas_mojo`, `dataviz`, and
`dataviz_mojo` returned no tins at the planning cutoff. Therefore:

- use a Pixi Git source dependency pinned to a full commit SHA when the
  upstream package builds unmodified;
- use a flat Git submodule only if Moxi must carry or co-develop patches that
  cannot yet be upstreamed;
- never depend on a floating branch or an unrecorded local checkout; and
- review canvas/dataviz version compatibility before allowing both into one
  environment, because dataviz may pin an older canvas release.

Moxi currently carries the exact-SHA canvas compatibility fork as a
nightly-only staging dependency so the renderer work can begin, but this does
not mean the backend gate has passed. The fork relies on a private Mojo async
runtime module and must either be upstreamed or replaced before a stable
release. `dataviz_mojo` should initially be a development/reference
dependency, not a runtime dependency of Moxi or the Python wheel.

## 5. Program gates

The gate names use an `E` prefix so they do not collide with the existing
project gates.

### Gate E0: handoff, rebaseline, and feasibility decisions

**Status:** complete as a planning/research gate. The upstream canvas tag is
not compatible with the locked Moxi compiler, but a measured exact-SHA
nightly compatibility fork now supplies a buildable staging dependency. The
Python extension import probe remains open.

**Purpose:** establish a clean, current starting point and answer the risks
that could invalidate the rest of the schedule.

**Implementation targets:**

- read the active thread again with ThreadBridge and record its terminal scope;
- confirm clean/synchronized `main` and `project-planning` worktrees;
- update the current-state audit to the final handoff commit;
- add `docs/architecture/ecosystem-convergence.md` with the contract decisions
  above;
- add ADRs for Scene ownership, Python value boundaries, upstream dependency
  governance, and dataviz convergence strategy;
- test an exact-pinned `canvas_mojo` dependency in an isolated branch;
- compile a minimal canvas program on every platform Moxi intends to claim;
- build a minimal Mojo extension importable from one clean CPython virtual
  environment, including an external Mojo package import path; and
- generate `docs/dataviz-capabilities.tsv` from the selected upstream revision.

**Measured E0 outcome:** the convergence architecture and four ADRs landed on
local `main` at `9fcd3b5`; the current exact-SHA canvas staging pin is at
`0da2c8c`, and `docs/dataviz-capabilities.tsv` inventories the selected
dataviz revision. The exact canvas experiment is recorded above and in the
architecture docs. The compatibility fork precompiles with
`1.1.0.dev2026082605`, the installed package imports through Moxi, and the
core buffer/JPEG/blur/golden/export checks pass under the pinned runtime. The
main repository validation and benchmark evidence still pass after the
dependency follow-on. The Python import probe and a Moxi-owned canvas adapter
remain explicit E1/E2 prerequisites, not silent omissions.

**Validation:**

- `pixi run check` and `pixi run release-check` pass before and after the
  isolated dependency experiment;
- the canvas smoke program produces a deterministic image and records its
  selected SHA;
- `python -c 'import _moxi_probe; print(_moxi_probe.version())'` succeeds in a
  clean environment; and
- every dataviz mark discovered at the pinned revision has an inventory row.

**Exit decisions:**

- go/no-go for prebuilt Python extension distribution;
- exact canvas revision and integration mode;
- whether Linux headless support can be added without macOS native sources;
- whether dataviz can expose a reusable geometry/render protocol upstream or
  must remain only a reference implementation; and
- revised estimates based on measured compile/package behavior.

**Estimate:** 1-2 engineering weeks.

### Gate E1: portable headless package boundary

**Status:** not started. The existing Moxi portable contracts remain intact, but
the dedicated headless package lane and linked non-macOS Mojo runtime have not
been established. Start after the E0 toolchain decision; do not advertise Linux
or wheel support from host-artifact builds alone.

**Purpose:** separate portable plotting/rendering code from macOS host code so
canvas and Python are not accidentally tied to AppKit or Metal.

**Implementation targets:**

- split Pixi features/environments into portable-headless and macOS-native
  lanes;
- add `linux-64` only after the portable package compiles and runs there;
- keep native C/Objective-C objects out of the headless dependency graph;
- add focused package lanes for portable plot, canvas backend, and Python
  binding internals without expanding the stable root export surface; and
- extend the API compatibility inventory to classify these new modules as
  provisional until their release gate passes.

**Likely files on `main`:**

- `pixi.toml`
- `src/moxi/plot_api.mojo`
- `src/moxi/canvas_api.mojo`
- `src/moxi/experimental_api.mojo`
- `scripts/package_consumer.sh`
- `.github/workflows/ci.yml`
- `docs/API.md`
- `docs/api-lanes.tsv`

**Acceptance:**

- the portable package builds and its plotting tests run on macOS arm64 and
  Linux x86-64;
- native macOS builds retain their existing validation;
- importing the portable package never requires linking Cocoa, CoreText, or
  Metal; and
- public API checks reject accidental root exports.

**Estimate:** 1-3 engineering weeks. This can partially overlap E0, but must
finish before distributable Python artifacts.

### Gate E2: canvas renderer vertical slice

**Status:** ready to start, not started. The exact-SHA compatibility fork
removes the compiler/package blocker for Moxi's current macOS nightly, while
the adapter and renderer parity work below remain outstanding. This status is
limited to the pinned nightly/compiler pair; it is not a stable upstream
compatibility claim.

**Purpose:** prove that Moxi Scene can drive canvas without weakening either
contract.

**Implementation targets:**

- add `src/moxi/canvas_renderer.mojo` implementing `SceneRenderer`;
- translate colors, geometry, opacity, transforms, rectangles, rounded
  rectangles, lines, linear gradients, and rectangular clips;
- add RGBA-buffer and PNG export entry points;
- map failures into Moxi renderer errors rather than leaking canvas-specific
  exceptions through stable APIs;
- add `tests/canvas_renderer.mojo` and
  `tests/canvas_scene_parity.mojo`; and
- add `examples/canvas_scene.mojo` using an existing canonical scene rather
  than a new demo-only fixture.

**Shared scenarios:**

- compact mixed-primitives scene;
- nested transform and clip scene;
- theme control states;
- plot line/point/bar overlap scenario; and
- invalid/unsupported command behavior.

**Acceptance:**

- the same scenario descriptor drives software, canvas, and SVG output;
- command ordering and declared bounds agree exactly;
- deterministic canvas outputs have reviewed checksums;
- unsupported commands fail or report fallback explicitly;
- no renderer-specific object enters `SceneCommand`; and
- compile time, peak memory, file size, and render time are recorded.

**Estimate:** 1-2 engineering weeks after E0/E1.

### Gate E3: complete canvas semantics and export quality

**Purpose:** make canvas a production-quality portable renderer/export path.

**Contract work:**

- replace or supplement string-only paths with a typed `ScenePath` that can be
  consumed by software, SVG, canvas, and Metal;
- define `SceneTextStyle` with family, size, weight, style, alignment,
  baseline, direction, and fallback policy;
- define a renderer-neutral image/resource resolver;
- specify nested clip, layer opacity, offscreen composition, and fill-rule
  behavior; and
- version new serialized Scene/PlotSpec representations where applicable.

**Likely files on `main`:**

- `src/moxi/scene.mojo`
- `src/moxi/scene_path.mojo`
- `src/moxi/scene_resources.mojo`
- `src/moxi/canvas_renderer.mojo`
- `src/moxi/software.mojo`
- `src/moxi/svg.mojo`
- `src/moxi/metal.mojo`
- `tests/scene.mojo`
- `tests/canvas_scene_parity.mojo`
- `tests/goldens/manifest.json`
- `docs/visual.md`
- `docs/text-policy.md`

**Acceptance:**

- paths, text, images, clips, layers, opacity, transforms, and gradients have a
  declared support row per renderer;
- PNG, SVG, PDF, and raw RGBA exports use one Scene and one resource resolver;
- software exact goldens remain unchanged unless an explicit reviewed contract
  migration says otherwise;
- platform-dependent text comparisons use the native tolerance/mask mechanism
  delivered by the earlier thread;
- canvas passes leak/repeat-render stress tests; and
- canvas becomes the default **portable export** renderer only after all
  declared commands have either parity or an explicit fallback policy.

**Estimate:** 3-5 additional engineering weeks.

### Gate E4: Python binding proof and package skeleton

**Status:** blocked behind E1-E3 and the compiler-dependent import probe. The
value-boundary contract is approved in ADR-002, but no wheel or developer
extension is claimed yet.

**Purpose:** establish a durable Python boundary before designing a broad
Pythonic plotting API.

**Initial ABI/API contract:**

```text
render(spec_json, named_columns, width, height, format) -> bytes or RGBA buffer
```

`named_columns` initially contains contiguous typed buffers plus validity and
category metadata. The Mojo side validates and copies or borrows them only
according to an explicit lifetime contract. No Mojo-owned object may outlive a
Python call in the first slice.

**Implementation targets:**

- add root `pyproject.toml`;
- add the Python facade under `python/moxi/`;
- add `bindings/moxi_python.mojo` and a reproducible extension build command;
- expose version/capability inspection and one stateless render call;
- map Mojo failures to stable Python exception classes;
- support NumPy numeric arrays first, then nullable, categorical, string, and
  timestamp columns;
- define copy/zero-copy behavior explicitly; and
- keep binding internals outside the stable Mojo package root.

**Acceptance:**

- a clean virtual environment installs an artifact and runs `import moxi`;
- the installed package renders one canonical PlotSpec from NumPy data to PNG
  and RGBA without invoking the Mojo compiler at runtime;
- repeated render, exception, teardown, and allocation-stress tests pass;
- unsupported dtype and malformed-spec failures are deterministic;
- wheel contents and dynamic dependencies are inspected and recorded; and
- the result is labeled experimental if the upstream Mojo binding/runtime
  constraints prevent a normal self-contained wheel.

**Stop condition:** if users must install a matching compiler or manually set
Mojo import paths after wheel installation, do not call the result a production
Python package. Publish an experimental developer build and keep the production
gate open.

**Estimate:** 1-2 engineering weeks for the proof after E3; packaging findings
may change all later Python estimates.

### Gate E5: headless Python MVP

**Purpose:** deliver a useful Python library around the stable Moxi value model.

**Public Python surface:**

- `moxi.plot(data, spec)`
- `Figure.to_png()`
- `Figure.to_svg()`
- `Figure.to_pdf()`
- `Figure.to_numpy()`
- `Figure.save(path)`
- version and backend capability inspection

The Python facade may provide ergonomic builders, but serialized PlotSpec
remains the cross-language source of truth. A Python-only option must either
compile to PlotSpec or remain outside the supported contract.

**Data inputs:**

- mappings of NumPy arrays;
- pandas DataFrames and Series through an optional adapter;
- numeric, boolean, categorical/string, nullable, and timestamp columns; and
- stable row-key selection.

**Likely files on `main`:**

- `pyproject.toml`
- `python/moxi/__init__.py`
- `python/moxi/figure.py`
- `python/moxi/plot.py`
- `python/moxi/data.py`
- `python/moxi/errors.py`
- `python/moxi/py.typed`
- `bindings/moxi_python.mojo`
- `tests/python/`
- `examples/python/`
- `docs/python.md`

**Acceptance:**

- clean-wheel tests pass for each declared CPython/platform combination;
- NumPy and pandas render the same canonical scenarios and checksums as Mojo;
- Python-visible exceptions and type annotations are tested;
- a process can render repeatedly and exit without leaks or crashes;
- install and render instructions require no repository checkout; and
- all Python examples are also contract tests.

**Estimate:** 2-4 additional engineering weeks for MVP; another 3-5 weeks for
broader wheel coverage, hardening, and release operations.

### Gate E6: dataviz overlap and migration protocol

**Status:** inventory preparation complete; protocol and overlap marks not yet
started. The selected upstream revision is recorded in
`docs/dataviz-capabilities.tsv`, while real reference-runner and per-mark
parity evidence remain gated on the shared portable/canvas boundary.

**Purpose:** establish a repeatable way to absorb capabilities before pursuing
mark breadth.

**Implementation targets:**

- pin dataviz as a development/reference dependency;
- add `docs/dataviz-capabilities.tsv` columns for upstream mark, Moxi
  equivalent, schema status, interaction status, accessibility status, Python
  status, parity fixture, and benchmark;
- create a reference runner that renders the real selected dataviz revision;
- define normalization rules for canvas size, fonts, colors, padding, random
  seeds, and output format;
- implement a Moxi compatibility facade only where it clarifies migration;
- port or share reusable layout algorithms with source/provenance notices; and
- complete the overlap set: point, line, bar, area, box, and heatmap.

**Acceptance per overlap mark:**

- a versioned PlotSpec representation exists;
- validation failures are specified;
- Scene and canvas output exist;
- Moxi interaction and hit-testing behavior is preserved;
- accessibility semantics and tabular fallback exist;
- Python exposure exists;
- a checked-in scenario runs through real dataviz and Moxi; and
- visual/structural differences are classified, not hidden by broad tolerance.

**Estimate:** 2-3 engineering weeks.

### Gate E7: dataviz capability waves

Capability breadth follows measured user value and dependency order. The
inventory, rather than this prose list, is authoritative after E6.

#### Wave A: business and categorical

Candidate marks: lollipop, waterfall, candlestick, bullet, grouped/stacked
bar, Gantt/span, and population pyramid.

Estimate: 3-5 engineering weeks.

#### Wave B: polar and statistical distribution

Candidate marks: pie/donut, radar, gauge, polar/radial bar, beeswarm, violin,
ridgeline, Nightingale, streamgraph, and contour.

Estimate: 4-7 engineering weeks.

#### Wave C: hierarchy, network, and specialty

Candidate marks: treemap, sunburst, tree, Sankey, chord, graph, calendar,
corrplot, punchcard, Marimekko, barbs, and tricontour.

Estimate: 4-7 engineering weeks.

Every wave must use the E6 definition of done. Static rendering may be marked
supported before interaction only if the capability inventory and public API
make that limitation explicit.

### Gate E8: release stabilization

**Purpose:** turn provisional integrations into supportable releases.

**Implementation targets:**

- decide whether canvas is the default portable renderer based on evidence;
- publish a Python platform/CPython support matrix;
- publish dependency and attribution notices;
- add migration notes for PlotSpec schema changes and dataviz users;
- classify all new Mojo and Python APIs through compatibility policy;
- collect reviewed benchmarks for supported host/compiler combinations; and
- run package-consumer tests from released artifacts, not only source trees.

**Acceptance:**

- `pixi run release-check` includes canvas parity and portable package checks;
- a planned `pixi run python-check` installs and tests built wheel artifacts;
- a planned `pixi run dataviz-parity` executes the selected real reference;
- all benchmark claims identify compiler, host, sample count, and dispersion;
- README/API/current-state docs agree on support labels; and
- no runtime dependency floats to an unpinned revision.

**Estimate:** 2-4 engineering weeks after the chosen breadth milestone.

## 6. Shared scenario strategy

Extend `src/moxi/scenarios.mojo`; do not create separate Python, canvas, and
dataviz scenario registries. Each relevant descriptor should own or reference:

- stable scenario ID and schema version;
- deterministic data seed and row count;
- PlotSpec and Scene fixture identity;
- viewport dimensions and scale factor;
- renderer/export expectations;
- semantic/accessibility expectations;
- interaction replay where meaningful;
- software checksum and canvas checksum/tolerance class;
- upstream dataviz reference revision and artifact; and
- benchmark profile membership.

Consumers include Mojo tests, Python pytest, software/canvas/SVG renderers,
dataviz reference generation, demos, documentation images, and benchmarks.
Catalog validation must fail when a supported capability has no real consumer
or when a fixture silently duplicates registry-owned values.

## 7. Reference and parity strategy

Three references serve different purposes:

1. **Moxi software renderer:** deterministic Scene-level oracle.
2. **Real pinned dataviz_mojo:** expected chart geometry/layout behavior during
   capability convergence.
3. **Supported native renderers:** platform behavior and integration evidence,
   using the screenshot policy delivered by the active thread.

Do not hand-build look-alike dataviz images and call them parity. The reference
runner must execute the selected upstream code. Store small normalized artifacts
and metadata; regenerate large or platform-specific artifacts through a
documented command.

Parity failures must classify whether the difference comes from data
semantics, scale/domain calculation, layout, text metrics, primitive geometry,
color, rasterization, or unsupported behavior. Pixel tolerance is appropriate
only after semantic and structural equality is checked.

## 8. Integration and Python test harness

The program adds four layers to the existing repository checks:

1. Mojo unit/contract tests for Scene mapping and plot algorithms.
2. Cross-renderer scenario tests for software, canvas, SVG, and supported
   native paths.
3. Python clean-environment tests that build/install artifacts before pytest.
4. Real dataviz reference tests isolated from Moxi runtime dependencies.

The Python matrix must test supported CPython versions on macOS arm64 and Linux
x86-64 before either is advertised. Each job creates a new environment,
installs only declared artifacts and dependencies, renders canonical scenarios,
checks errors and process teardown, and uploads diff artifacts on failure.

Browser testing is not required for the first headless Python milestone. If a
later notebook/browser frontend is proposed, it must extend the existing
deterministic browser lifecycle harness with readiness, interaction replay,
accessibility state, screenshot capture, and guaranteed teardown.

## 9. Benchmark and documentation plan

Add benchmark cases without weakening the host/dispersion policy owned by the
active thread:

- canvas cold compile and package build;
- Scene-to-canvas render for compact, 10k-row, and 1M-row plot scenarios;
- PNG/SVG/PDF encoding time and output size;
- Python import and first-render latency;
- Python repeated-render throughput and peak memory;
- NumPy/pandas conversion cost, separating copy from render time; and
- each dataviz wave's representative layout/render workload.

Deterministic counters, output checksums, and work inflation are correctness
signals. Timing is compared only within compatible environments using repeated
runs and the existing policy.

Documentation deliverables are:

- architecture and ADRs at E0;
- renderer support matrix and visual policy at E2/E3;
- experimental Python install/API guide at E4;
- Python user guide and support matrix at E5;
- generated dataviz capability/migration matrix at E6/E7; and
- release/current-state reconciliation at E8.

Status docs must distinguish "implemented", "provisional", and "supported" in
the vocabulary already defined by the project plan.

## 10. Sequencing and parallel ownership

The critical path is:

```text
active-thread handoff
  -> E0 feasibility
  -> E1 portable boundary
  -> E2 canvas vertical slice
  -> E3 canvas semantics/export
  -> E4 Python proof
  -> E5 Python MVP
  -> E6 overlap protocol
  -> selected E7 waves
  -> E8 release stabilization
```

After E0 fixes the contracts, limited parallelism is safe:

- portable packaging and canvas adapter implementation may proceed with
  separate owners and disjoint files;
- Python facade design may proceed while extension packaging is tested, but it
  may not freeze unsupported ABI assumptions;
- dataviz inventory/reference tooling may proceed while canvas matures; and
- mark waves may be split by family only after shared scale/layout primitives
  and the E6 definition of done are in place.

Avoid parallel edits to `scene.mojo`, `plot_spec.mojo`, `pixi.toml`, API
inventories, and scenario registry without an explicit integration owner.

## 11. Estimates and milestone choices

Assuming one experienced engineer and stable upstream APIs:

- integrated demonstrator: E0-E2, Python proof, and six overlap marks in about
  6-10 weeks;
- production-quality headless Python, canvas as a supported portable export
  backend, and core dataviz breadth in about 4-6 months; and
- broad all-mark convergence plus a later live Python UI in 6-9+ months.

With two or three owners, the calendar can compress after E0, but E3 contract
changes and E6 convergence rules remain integration bottlenecks.

The recommended first funded milestone is E0-E5 plus E6 overlap parity. It
produces a coherent product: Python users can render Moxi plots through canvas,
and the capability migration process is proven on representative marks.

## 12. Explicit non-goals for the first milestone

- removing software, SVG, AppKit, or Metal renderers;
- making canvas APIs the Moxi scene contract;
- exposing Mojo structs or native renderer handles directly to Python;
- Python-driven native windows, callbacks, or event-loop ownership;
- notebook widgets or a browser plotting frontend;
- exact source compatibility with the dataviz fluent API;
- copying the dataviz repository wholesale into Moxi;
- absorbing every dataviz mark before overlap parity is proven;
- geographic or 3D plotting unless separately prioritized;
- exact font pixels across operating systems; and
- performance claims based on one workstation or one timing sample.

## 13. Program-level definition of done

The convergence program is complete only when:

- Moxi's portable package builds on every advertised platform;
- canvas is pinned, reproducible, and has declared parity/fallback behavior for
  every supported Scene command;
- a released Python artifact installs in a clean environment and renders from
  NumPy/pandas without a compiler setup step;
- Python and Mojo consume the same PlotSpec and canonical scenarios;
- selected dataviz capabilities meet schema, rendering, interaction,
  accessibility, Python, parity, and benchmark requirements;
- real upstream dataviz output remains reproducible from its recorded revision;
- public APIs and schema migrations are governed by compatibility policy;
- benchmarks and docs match the released artifacts; and
- `CURRENT-STATE.md` reports observed support rather than planned breadth.
