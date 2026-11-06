# Deferred implementation master list

Status: proposed for user confirmation; implementation has not started.

Prepared November 6, 2026 against implementation `feat/playground-authoring`
at `6c92242` and planning `project-planning` at `c2a0755`. The user requested
all deferred proposals, separate Astra High workers, incremental commits,
appropriate branches, and screenshot slideshows for every proposed demo.
This document defines the scope to confirm before starting that work.

## What approval would mean

Approve the concrete deliveries and experiments listed below, in dependency
order. Detailed feature plans retain their stated acceptance criteria. Broad
product visions receive bounded executable experiments, not a claim that their
entire product horizon has been delivered. The 21 earlier concepts remain
traceable through the coverage map rather than becoming duplicate applications.

Decision experiments are real work: compile and exercise competing approaches,
record evidence, then choose a supported implementation. A failed feasibility
gate is not permission to substitute a mock implementation or claim target
support. Hardware, external data, compiler support, independent human trials,
and production/publication actions remain explicit dependencies.

No implementation branch, runtime change, dependency installation, or screenshot
capture is part of this confirmation pass. Existing active-plan acceptance
gaps remain open; this list does not silently close them.

## Execution and branch strategy

- Create an integration branch from the reviewed implementation baseline,
  provisionally `feat/deferred-proposals`. Never merge the orphan planning
  branch into implementation.
- Assign each plan its own Astra High worker and focused acceptance contract.
  Use isolated worktrees for code changes; serialize plans that share runtime
  interfaces. A named plan may have several dependent implementation slices.
- Use the branch names listed below beneath `feat/`, with `experiment/` for
  feasibility work. Stack dependent branches on the relevant committed parent;
  integrate independent branches only after review and focused validation.
- Reuse the existing browser/server probe commits `ea99901` and `d642bff` from
  `experiment/browser-execution-and-reduced-views` after review. Their planning
  descriptions calling them uncommitted are stale. Do not rebuild them from
  scratch or merge unrelated history.
- The orchestrator owns integration, content checks, Conventional Commits,
  and final verification. Commit coherent slices as they pass their checks.
  No push, PR, package publication, upstream contribution, or production write
  is included in approval of this local implementation program.
- Keep shipped contracts, runnable examples, tests, and captured evidence beside
  code. Reconcile this planning branch with actual implementation commits.

## Screenshot slideshow contract

Every named demo below gets its own slideshow. Galleries also get one sequence
per named plot family; shared infrastructure does not need a decorative demo
when an actual consumer already demonstrates it.

Each sequence contains actual screenshots of the built demo: initial state,
the important interaction, its resulting state, and a relevant cancel, undo,
rejection, loading, stale-result, or recovery state. Add narrow/wide layouts,
keyboard focus, linked views, and export comparisons where the proposal needs
them. Capture intermediate interaction states as well as polished end states.

Deliver a self-contained HTML slideshow with previous/next and keyboard
navigation, captions, a thumbnail/contact-sheet view, original PNGs, and a
master gallery index. Each capture records demo/scenario ID, source revision,
host/backend, dimensions/scale, fixture or seed, reproduction command, action,
and expected observation. Keep captures reproducible from the same fixtures as
tests and examples. Redact unrelated desktop content before retaining images.

Browser captures use the collaborative preview; native captures use the running
application when available. Offscreen renders are explicitly labeled and do
not replace native evidence. Mockups are not implementation screenshots. Missing
platform access is recorded as a missing sequence, not filled with fabricated
results. Screen-reader behavior, physical IME, latency, scientific accuracy,
and human usability require their own checks; a screenshot cannot prove them.

Proposed artifact layout is `artifacts/demo-slideshows/<demo-id>/` with an index,
images, captions/manifest, and reproduction notes. Large captures can remain
local review artifacts; commit compact manifests and deterministic capture
recipes rather than automatically adding every binary to repository history.

## Native foundations carried forward

These are the still-relevant follow-ons from
[execution-plan Gate 2](PROJECT-PLANNING.md#gate-2-text-and-native-macos-quality),
not a replay of completed host or authoring work.

| ID | Delivery to confirm | Demo and screenshot sequence | Branch |
| --- | --- | --- | --- |
| F01 | Portable font collections/fallback policy and richer paragraph corpus, preserving the existing CoreText/HarfBuzz ownership split. Verify mixed scripts, composed clusters, wrapping, selection, and invalidation; do not assume identical glyph IDs across engines. | Text laboratory: mixed-script paragraph → resize/wrap → fallback-font change → selection/caret and invalidation result. | `feat/text-fallback-policy` |
| F02 | Native ownership and lifecycle: instance-owned window state or an explicitly enforced bounded profile, then prove two windows cannot cross-route events/resources. Cover deep collection editing, native menu/dialog lifecycle, drag/drop, and automated AX assertions incrementally. Existing portable menu/dialog models are reused. | Native lifecycle workbench: two independent windows → edit/selection in each → menu/dialog and drag/drop → close/reopen one while the other retains state. | `feat/native-window-ownership` |

F02 begins with an ownership probe: `native/macos_window.m` still contains
process-global fixed draw/event storage at the inspected revision. A bounded
single-window declaration alone cannot satisfy a later claim of multi-window
support. Manual IME/screen-reader work remains separate, including the user's
existing pause on VoiceOver testing.

## Browser, notebooks, scientific applications, and hosts

| ID | Delivery to confirm and source | Demo/slideshow coverage | Branch or dependency |
| --- | --- | --- | --- |
| P01 | [Browser execution](docs/design/browser-execution.md): preserve the FDG probe, establish safe handles/capacity/runtime/toolchain boundaries, then connect actual Moxi events, scene output, rendering, semantics, and lifecycle. Define a supported subset before calling it a web target. | Browser FDG: selected/dragged graph, pan/zoom/resize, pause/restart, two isolated instances, disposal/recreate, unsupported-runtime failure. | `feat/browser-moxi-runtime`; independent first track. |
| P02 | [Server-backed views](docs/design/server-backed-views.md): real delayed local transport, immediate client feedback, bounded queries/cancellation, stale-result rejection, capped exact-record details, disconnect/retry, and measured full-data comparison. | Million-point density explorer: initial grid → pan while pending with retained data → fresh result → aggregate vs exact selection → disconnect/recovery and two views. | `feat/server-backed-views`; independent initially, integrate P01 later. |
| P03 | [Jupyter entry points](docs/design/jupyter-integration.md): fresh-kernel notebook using one graph for static SVG and nonblocking native launch, with repeated execution, errors, close/restart and explicit remote-kernel behavior. | Entry-point notebook: graph cell/SVG → native viewer → actionable error → reopen/restart. | `feat/fdg-notebook-entrypoints`; uses existing Python helpers. |
| P04 | [Interactive Jupyter](docs/design/jupyter-integration.md): example-local FDG widget/comm spike with bounded versioned messages, isolated outputs, disposal/rerun/restart, static saved fallback, and actual remote-kernel verification. | Inline FDG: drag/pan/pause → two outputs → resize → failed backend/recovery → reopened static fallback → remote-kernel session. | `feat/fdg-interactive-notebook`; informed by P01/P02. |
| P05 | Reusable notebook adapter gate from the same [Jupyter plan](docs/design/jupyter-integration.md): add a genuinely distinct linked-selection plot consumer before generalizing; verify installation, keyboard/semantics and recovery. | Linked-selection notebook plot and details, isolated from the FDG output; same lifecycle failure sequences. | `feat/notebook-adapter`; follows P04, generalization contingent on evidence. |
| P06 | [FDG follow-ups](docs/design/fdg-port.md): proposed finite choices are PNG/PDF export, clean local package installation, and a Linux native lane. Keep existing solver/app; measure larger graphs before any capacity/solver redesign. | FDG export comparison, clean-consumer launch, and Linux graph each get a sequence: selected neighborhood/search → interaction → exported/reopened result. | `feat/fdg-export`, `feat/fdg-distribution`, `feat/fdg-linux`; notebook/browser work belongs above. |
| P07 | [SeedWaterSegmenter](docs/design/sws-port.md): reproducible reference fixtures, native stack/label viewer, generation-safe watershed, seed/polygon editing, undo/redo, persistence, cancellation and recovery. Preserve scientific algorithms first. | SWS: asymmetric image/labels → frame/contrast/zoom → seed or polygon edit/watershed → undo/redo → save/reopen → failed/stale computation. | `feat/sws-native-port` in proposed local application checkout `moxi-sws`; narrow Moxi fixes separately. |
| P08 | [SWS4D](docs/design/sws4d-port.md): reference fixtures, linked XY/XZ/YZ/time viewer, explicit axes/spacing/connectivity, edits in each plane, watershed, stable IDs, bounded caches, persistence and recovery. | SWS4D: known voxel in three planes → crosshair/time navigation → seed/mask edits → undo/save/reopen → delayed/failed computation. | `feat/sws4d-linked-slices` in proposed local application checkout `moxi-sws4d`; independent of P07. |
| P09 | [Linux GPU H4](CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md): choose an adapter through a scene/packet probe, retain GTK host and software oracle, then implement the declared text/image/clip/resource subset with parity and hardware measurements. | Linux canonical workbench: software/GPU comparison → chart/collection interaction → popup/Unicode/clip ordering → resize/scale → supported recovery/fallback. | `experiment/linux-gpu-choice` then `feat/linux-gpu-renderer`; coordinate with E05 below. |
| P10 | [Additional host H5](CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md): separate iOS and Android compiler/runtime feasibility gates; promote each existing shell only when real shared Mojo application state executes. | Separate iOS and Android canonical form/collection/plot slideshows: text/IME, touch capture, scroll/reorder, rotation, popup/clipboard, lifecycle. | `experiment/ios-runtime`, `experiment/android-runtime`, then target-specific feature branches if feasible. |
| P11 | [Host follow-through](CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md): Wayland validation of the existing Linux host. Windows receives a bounded feasibility/design gate because only a portable descriptor exists; a full Windows host is not yet specified. | Wayland canonical workbench; Windows gets a real scenario sequence only if the runtime/host probe succeeds. | `verify/wayland-host`, `experiment/windows-host`; browser host work stays P01. |

P06's formats and Linux target, P07/P08's local application destinations, and
P10/P11's finite target list are proposed choices for this confirmation, not
facts already fixed by the older plans. No new remote repository is proposed.
Scientific fixtures and current compiler/SDK/device availability must be checked
before implementation commitments depend on them. A viewer alone does not
complete either segmentation port. GPU timing in a software VM is not hardware
performance evidence.

## Math, canvas, mind maps, and spatial interaction

| ID | Delivery to confirm and source | Demo/slideshow coverage | Branch and dependency |
| --- | --- | --- | --- |
| D01 | [Symbolic backend comparison](docs/design/math-backend-experiment.md): executable SymEngine wrapper and persistent SymPy worker against one exact-expression corpus; ownership, bounded work, revision/cancellation, editable result conversion, packaging and measured decision. | Backend comparison: exact arithmetic → expand/differentiate/substitute → assumptions/unsupported result → slow operation superseded → editable result and measured decision. | `experiment/math-backends`; parallel with backend-free editor. |
| D02 | [Math editor M0–M4](docs/design/math-editing.md): lossless notation/text including holes/malformed edits; shared display/editor geometry, fractions/scripts/radicals/delimiters/matrices/functions/sums/integrals, navigation/selection, clipboard/history/persistence, one selected async backend, and second public-API consumer. | Native math workbench and reusable consumer: templates/nested edits → caret/selection/matrix/limits → exact text round-trip → clipboard/undo → pending/stale/result apply → reopen/narrow layout. | `feat/native-math-editor`; D01 gates computation, not editing. |
| D03 | [Canvas C0–C4](docs/design/canvas-interaction.md): transformed ordinary components, shared geometry/input/semantics, pan/zoom/select/move/resize/history, ports/edges/reconnect, groups/minimap/culling and public consumers. | Rich-node probe and freeform graph editor each get a slideshow: text/button/slider ownership → resized ports → zoom/clip → move/cancel/undo → invalid/reconnected edge → groups/minimap. | `feat/canvas-interaction`; C0/C1 unlock D04. |
| D04 | [Mind map N0–N4](docs/design/mind-mapping.md): keyboard-first ordered tree/layout, branch movement/reparenting, folds/search/outline, crosslinks/notes/style metadata, local save/recovery, bounded Freeplane import and visible loss report. | Mind-map app: mixed-script topic → fold/search → keyboard and pointer reparent/cancel/undo → root-side/spacing → crosslink/outline → save/recovery → import/loss report/large fixture. | `feat/native-mindmap`; uses D03, not a second canvas runtime. |
| D05 | [Spatial S0](docs/design/3d-interaction.md): compare existing bridge with one credible renderer; establish depth, perspective/orthographic, compositing, frame/resource/coordinate contracts and measured choice. | Spatial hosting probe: two cameras → ordinary surrounding controls → scrolling/clip/overlay → focus/resize/recreate → candidate comparison/decision. | `experiment/spatial-renderer`; no renderer is preselected. |
| D06 | [Spatial S1/S2](docs/design/3d-interaction.md): reactive geometry explorer, picking/selection/inspector, projected annotation, stale-work rejection, constrained transforms/snapping/numeric entry and shared undo. | Geometry explorer: parameter change → camera/pick → annotation → slow update → axis/plane/rotation/scale preview → snap/cancel/undo and keyboard route. | `feat/spatial-explorer`; follows D05. |
| D07 | [Spatial S3](docs/design/3d-interaction.md): second application with hierarchy, linked perspective/orthographic views, shared selection, measurement/clipping and resource/work reuse evidence. | Assembly inspector: linked views → hierarchy selection/transform → measurement → clipping plane → undo and reuse evidence. | `feat/spatial-assembly`; follows D06. |
| D08 | [Spatial S4](docs/design/3d-interaction.md): planar world-space ordinary controls, ray/local mapping, occlusion/clip/capture/focus/IME/semantics; compare screen-space editing before promoting the API. | World panel: oblique text/button/slider → ray drag/capture → text/focus → occlusion → equivalent projected screen editor → supported/failed cases. | `experiment/spatial-world-panels`; separate gate, does not block S1–S3. |

The math/canvas/mind-map plans cover their full stated initial delivery gates,
not just their first attractive screenshots. The 3D plan covers S0–S3 plus
the separately evaluated S4 experiment. A rendered formula, rectangle-only
canvas, or rotating mesh alone does not complete those plans.

## Plotting, bindings, renderer experiments, and authoring pattern

Existing static/D0 plot names and Python PNG/SVG/PDF exports are already
implemented. These rows target specialized layout parity or distinct adapters.

| ID | Delivery to confirm and source | Demo/slideshow coverage | Branch |
| --- | --- | --- | --- |
| E01 | [Specialized Wave A](ECOSYSTEM-CONVERGENCE-PLAN.md#specialized-geometry-promotion-backlog--remaining-wave-a): upstream-shaped layouts/fixtures for lollipop, waterfall, candlestick, bullet, grouped/stacked bar, Gantt/span, population pyramid. | One sequence per named family and distinct grouped/stacked/Gantt/span fixture: source → real reference → Moxi/difference → selection/table → export/update. | `feat/plot-specialized-wave-a` |
| E02 | [Specialized Wave B](ECOSYSTEM-CONVERGENCE-PLAN.md#specialized-geometry-promotion-backlog--remaining-wave-b): pie/donut, radar, gauge, polar/radial bar, beeswarm, violin, ridgeline, Nightingale, streamgraph, contour; richer distributions/grids as needed. | Same per-family proof sequence; retain separate pie/donut, polar variants and contour/filled-contour cases from the authoritative inventory. | `feat/plot-specialized-wave-b` |
| E03 | [Specialized Wave C](ECOSYSTEM-CONVERGENCE-PLAN.md#specialized-geometry-promotion-backlog--remaining-wave-c): treemap, sunburst, tree, Sankey, chord, graph, calendar, corrplot, punchcard, Marimekko, barbs, tricontour. | Same per-family sequence with true hierarchy/flow/triangulated fixtures; semantic object selection and explicit interaction limits. | `feat/plot-specialized-wave-c` |
| E04 | [Native Mojo/CPython extension](ECOSYSTEM-CONVERGENCE-PLAN.md#gate-e4-python-binding-proof-and-package-skeleton): clean-environment native import/render probe, typed-buffer lifetime/copy policy, stable failures, wheel/dependency inspection and deployment decision. Preserve existing compiler-independent facade. | Terminal/result slideshow: clean import/version → canonical render → existing-facade comparison → malformed input/repeated lifetime checks → packaging decision. | `experiment/python-native-extension` |
| E05 | [Cairo scene/export evaluation](PROJECT-PLANNING.md#gate-4-supported-2d-plotting-package): canonical scene corpus adapter and maintenance/coverage/cost comparison; adopt only if evidence warrants it. Portable wgpu evaluation is owned by P09, not a duplicate worker. | Scene comparison: paths/clip/transform/text/image → vector/PDF zoom detail → fallback cells → measured decision. | `experiment/cairo-scene-adapter` |
| E06 | Full-catalog reconciliation gate: current capability inventory additionally names parallel, funnel, bump, effect_scatter and arc_diagram outside A–C prose. Audit reference layouts and define remaining parity deltas before implementing any missing ones. | Separate per-family source/reference/Moxi/difference/selection/table/export sequence if promotion is warranted; record already-complete cases. | `experiment/plot-catalog-remainder`, then focused feature slices. |
| N01 | [NotImplemented component](docs/not-implemented-pattern.md): pure inert component, feature name/explanation, ordinary semantics, independent namespacing, public import, runnable example and Playground entry. | Pattern demo: default/explanatory variants → narrow wrapping → two instances with working surrounding controls → replacement by implemented content. | `feat/not-implemented-pattern` |

E01–E03 share schema/reference seams before family workers diverge. Each family
must satisfy the ecosystem E6 definition of done across the declared schema,
Scene/export, interaction/accessibility, Python, reference and benchmark lanes.
Missing runnable upstream evidence must remain explicit. E06 is a proposed
extension of the prose wave list to reconcile the actual capability inventory;
it does not assume five unimplemented algorithms without inspection.

## Product-vision experiments

Include all 15 [portfolio visions](ideas/README.md), each with its own worker,
branch `experiment/<id>-<short-name>`, runnable scenario, tests, and screenshot
slideshow. Shared dependencies can be reused; each vision retains its distinct
question. The concrete fixtures below are proposed experiment choices derived
from the briefs, not complete specifications of commercial products.

| ID | Experiment to confirm | Screenshot storyboard | Dependencies or nonvisual evidence |
| --- | --- | --- | --- |
| [V01](ideas/v01-draw-executable-behavior.md) | Draw executable behavior: two-state motion model, parameter versus desired-curve editing, bounded candidate proposals. | Model → target edit → candidate comparison → failed fit/cancel/undo. | Canvas/math, explicit inverse-solving limits. |
| [V02](ideas/v02-compose-worlds.md) | Compose worlds: seeded two-population 2D world with editable response rules and compared predictions. | Initial world → rule edit → branched outcomes → reset/replay. | Deterministic simulation and parameter history. |
| [V03](ideas/v03-invent-notations.md) | Invent notation: three phrase types with sequence/group/timing semantics and editable structural rules. | Notation definition → composed phrase → schema revision → invalid/retained document. | Math/structured editing; a second author is needed for the authoring claim. |
| [V04](ideas/v04-design-across-scales.md) | Design across scales: planar spring linkage, force curve and two dimensions, compare sweep with hand tuning. | Linkage → target curve/dimensions → candidates → infeasible target and undo. | Bounded solver/model; no fabrication accuracy claim. |
| [V05](ideas/v05-executable-arguments.md) | Executable argument: two assumptions, one quantitative model, explicit limitation and reversal condition. | Argument → altered premise → affected conclusion → restored/static comparison. | Provenance, participant evidence for comprehension. |
| [V06](ideas/v06-compose-across-media.md) | Cross-media composition: motion path and sound envelope sharing editable timing. | Path/envelope → shared timing edit → playback/commit → revision/recovery. | Audio adapter, timing/drift evidence beyond screenshots. |
| [V07](ideas/v07-learn-by-changing-systems.md) | Learn by changing a system: oscillator prediction, manipulation, comparison, unfamiliar case. | Prediction → manipulation → comparison/formal notation → keyboard route. | Math/plot integration; actual learners for learning claims. |
| [V08](ideas/v08-instruments-for-invisible-phenomena.md) | Perceptual instrument: finite probability distribution with normalized redistribution and optional fixed mean. | Distribution → direct/numeric edit → constrained result → infeasible rejection. | Conservation/constraint tests, explicit inferred vs observed state. |
| [V09](ideas/v09-compose-lived-spaces.md) | Spatial experience: small scene, two routes, line-of-sight test and light envelope. | Routes → spatial edit → timing/light change → linked-view undo. | Desktop spatial view and timed media. |
| [V10](ideas/v10-negotiate-possible-futures.md) | Negotiate futures: fictional allocation, three separately owned preferences, finite alternatives and retained disagreement. | Preferences → candidate comparison → compromise → retained minority view/static table. | Local multi-person scenario; human trial for negotiation benefit. |
| [V11](ideas/v11-patterns-become-structures.md) | Pattern to structure: known foldable motif with linked flat/folded parameters. | Flat pattern → folded view → edit → invalid configuration and comparison. | Spatial geometry; physical paper sample for construction claims. |
| [V12](ideas/v12-personal-instruments.md) | Personal instrument: fixed creative operations, two input routes, editable response curve/mode graph, saved configuration. | Mapping → alternate control route → curve/mode edit → reopen/recover. | Domain operations; human repeat-use evidence for personal utility. |
| [V13](ideas/v13-visual-instrumentation.md) | Executable instrument: recorded source, bounded processing nodes, explicit stateful node, plot and recorder. | Pipeline → live preview → rate mismatch/failed node/invalid wire → cancel/recover. | Canvas, bounded executor, recording and typed node contracts. |
| [V14](ideas/v14-robot-nose.md) | Chemical prediction investigation: replay one outcome/horizon with sensor traces, baseline comparison and held-out session evaluation. | Route/traces → aligned interval → predictions/uncertainty → drift/failure replay. | Real timestamped recordings, selected outcome/sensor and held-out data are missing. Synthetic data can deliver only a clearly labeled UI prototype. No autonomous robot control. |
| [V15](ideas/v15-hand-pose-control.md) | Continuous hand control: one creative task, a small feature subset, direct versus pose-interpolated mappings, clutch and loss recovery. | Calibration → engaged control → confidence/tracking loss → no-jump reacquisition/replay. | Tracker/model/license choice and camera; measured repeatability, latency and comfort. Recorded synthetic input does not close live-camera acceptance. |

## Earlier concepts: complete coverage without duplicate products

All 21 retained briefs are included as named acceptance scenarios. A shared
application can satisfy several, but the master slideshow index must retain
an entry and scenario sequence for every ID. This mapping comes from the
[portfolio](ideas/README.md); supplementary lanes below are proposed ownership
choices where the portfolio provides no single product home.

| ID | Included scenario and slideshow | Home |
| --- | --- | --- |
| [I01](ideas/i01-progressively-executable-sketch.md) | Informal sketch/note → formalized moving arm/joint → undo preserving note/location. | V01, V03, V11 |
| [I02](ideas/i02-tangible-mathematics.md) | Matrix and basis vectors → numeric/keyboard edit/shared selection → singular or constrained case. | V07, V08 |
| [I03](ideas/i03-inverse-design.md) | Trajectory target/pinned constraint → solver alternatives → infeasible, cancelled or stale solve. | V01, V04 |
| [I04](ideas/i04-possible-worlds.md) | Three parameter branches → shared input/local override → promotion and undo. | V02, V10 |
| [I05](ideas/i05-attachable-instruments.md) | Measurement attached to a plot → same instrument in geometry preserving units/state. | V08 |
| [I06](ideas/i06-semantic-zoom.md) | Plot → formula → definition → restored caret/selection and keyboard focus. | V02, V07, V09 |
| [I07](ideas/i07-performed-explanations.md) | Five-action explanation → checkpoint after action three → explore → restore checkpoint. | V05, V06, V07, V09 |
| [I08](ideas/i08-reasoning-debugger.md) | Source/fit/derived-plot provenance → premise invalidation → saved alternative. | V05, V10 |
| [I09](ideas/i09-curated-instrument-panels.md) | Extract supported controls into panel → save → reopen controlling intended values. | V12, plus I10 consumer |
| [I10](ideas/i10-investigations-become-tools.md) | Named cohort → explicit fit/residuals → alternatives → saved fixed panel. | Independent `experiment/investigation-tools` |
| [I11](ideas/i11-visible-agent-work.md) | Deterministic fake-worker proposal for two allowed values → inspect/reject/apply → stale rejection. | Independent `experiment/visible-proposals`; no live LLM dependency |
| [I12](ideas/i12-live-tool-authoring.md) | Versioned calculation → replacement retaining focus/data → failed-build last-good state. | V03/V12; explicit replacement scenario, not an arbitrary plugin system |
| [I13](ideas/i13-visual-execution-debugger.md) | Action/subtree counters/frame preview → replay comparison → dropped-record indication. | `experiment/execution-debugger`, with I15 |
| [I14](ideas/i14-mathematics-and-motion-studio.md) | 2D motion/recorded parameter curve → stopped edit → deterministic replay. | V06, V08 |
| [I15](ideas/i15-experiment-flight-recorder.md) | Synthetic stream and async result capture → reopen episode → missing-result limitation. | `experiment/flight-recorder`; I13 consumes it |
| [I16](ideas/i16-executable-essay.md) | Narrative/formula/plot → exploration copy → explicit result/provenance insertion → static export. | V05, V07 |
| [I17](ideas/i17-one-instrument-many-bodies.md) | Graphical panel → keyboard/accessible structure → equivalent operation/state. | V06, V12 |
| [I18](ideas/i18-coordinated-representations.md) | Same observation in table/plot/canvas → filtered/deleted/aggregate mapping → second domain. | `experiment/coordinated-representations`; reusable after two consumers |
| [I19](ideas/i19-inspectable-interactions.md) | Numeric/drag preview → Escape revert → commit/one undo → changed-layout replay/stale rejection. | `experiment/inspectable-interactions`; canvas/spatial consumers |
| [I20](ideas/i20-reusable-application-operations.md) | Button/keyboard/script produce same cohort operation → caller-policy rejection. | `experiment/application-operations`; I10/V13 consumers |
| [I21](ideas/i21-living-linkage-sketch.md) | One-degree-of-freedom linkage/length/trace → pointer/keyboard change → exact text/layout/cancel/undo. | V04, V11 |

The seven independent or architectural briefs I10, I11, I13, I15, I18, I19 and
I20 each receive a separate Astra High worker/plan. They may share the example
shell and capture infrastructure while preserving their own tested contracts.

## Scope boundaries to confirm

The following are mentioned as possible extensions, discovery catalogs or
explicit non-goals, rather than standalone implementable proposals. They remain
visible here so "all" is not misleading. The proposed approval covers the
concrete rows above; these broader ambitions are not automatically additional
product builds. Promote any of these explicitly if that is the intended scope.

| Reference | Named breadth not silently included |
| --- | --- |
| Math follow-ons | Mixed prose/pagination, automatic line breaking, handwriting/touch-first editing, automatic algebra, a general CAS/programming language, arbitrary document/markup import/export, image/vector export, plotting computed results, notebook execution/evaluation, general math-font fallback beyond F01, full bidirectional math, advanced IDE completion, general symbolic-library extraction and additional backends. Reuse/extraction needs a demonstrated second requirement; ordinary supported notation and one chosen backend are D01/D02. |
| Canvas and mind-map follow-ons | Rotation/multitouch/freehand, arbitrary nested canvases, orthogonal obstacle routing/waypoint editing, general graph solvers/plugins/executable subflows, graphical shortcut editor/chord-heavy profiles, collaboration/cloud sync, scripting/add-ons/clones/conditional styles, scheduling, embedded files/HTML, presentation mode, complete Freeplane round-trip, all export formats and math topics. The freeform graph second consumer is included in D03; these broader apps are not implied by it. |
| Spatial discovery catalog | Further molecular/robotics/product/modeling applications, volumes/isosurfaces/dense scientific fields, full asset/material/shader/animation pipelines, general CAD/physics/ECS, curved UI surfaces, spatial layout/control catalogs, 2.5D transitions, XR and new six-DOF/gamepad/haptic adapters. D05–D08 supply the explicitly gated desktop proposals; V09/V11 add their bounded consumers. |
| Historical plotting catalog | Geographic plotting, additional scales/transforms/encodings, strip/Q-Q/LOESS, horizon/range/streamline/field families, scatterplot matrices, function/parametric/polar/region samplers and discontinuity tooling beyond an included consumer's needs. Scoped A–C and catalog reconciliation are E01–E03/E06; the old roadmap is not a second current checklist. |
| General runtime and product infrastructure | Arbitrary runtime reflection, browser IDE, bundled LLM, general capability-bus networking/persistence/deadline/executor framework, arbitrary multi-device synchronization and unbounded platform parity. P02/V13/I11 implement their bounded consumers without promising these platforms. |
| Extraction and scale | Standalone FDG solver extraction without a second consumer, million-node/GPU solver claims, generic scientific framework, GPU watershed, unbounded out-of-core data, and wholesale structural/package reorganization. Existing code is reused; measured bottlenecks can justify focused changes. |
| External release actions | Public packages, repository creation on a hosting service, PRs, upstream contributions, remote deployment, production data changes, or automatic physical-device control. Local implementation approval does not approve those actions. |

This also excludes reimplementing superseded authoring designs, native reset,
localized execution, scenario registries, basic plot serialization and existing
Python exports. Their old proposals are historical evidence; their current
implementations are starting points. The five previously active plans' manual,
human and performance gates retain their prior status.

## Dependency order and acceptance

1. **Preserve and establish boundaries.** Review/import browser/server probes;
   run math, spatial, GPU/Cairo, native-extension and host feasibility gates;
   establish plotting references; implement N01 and necessary F01/F02 slices.
2. **Build reusable initial consumers.** Backend-free math editor, rich-node
   canvas, browser FDG, delayed density explorer, notebook entry points,
   scientific reference/viewer slices, and the first complete plot-family
   parity slice. Shared interfaces settle before dependent workers edit them.
3. **Complete the scoped applications.** Math M2–M4, canvas C2–C4, mind map
   N0–N4, spatial explorer/assembly, segmentation editing/history/persistence,
   interactive notebooks, FDG follow-ups, and remaining plot families.
4. **Exercise reuse and new experiences.** V01–V15 and the seven separate
   supporting concepts use proven boundaries. They can proceed earlier where
   independent. World panels and reusable notebook generalization retain their
   own acceptance decisions; empirical studies wait for real resources.
5. **Integrate and demonstrate.** Review diffs and content, run focused checks
   and the applicable full suite, capture each scenario slideshow, reconcile
   support claims and update the master gallery/plan with commit evidence.

Completion requires runnable code, appropriate positive and failure-path tests,
reviewed integration, actual captured demo evidence, and accurate remaining
limits. Native/device tests, scientific reference equivalence, external
accessibility/IME, package clean installs and benchmarks are required where
the corresponding source plan claims them. Offscreen snapshots and agent
exercises do not silently substitute for unavailable human or platform checks.

## Confirmation and evidence limits

Confirm the 28 F/P/D/E/N workstreams, the 15 V experiments, all 21 I coverage
scenarios (seven with separate implementation lanes), the branch/application
choices, screenshot contract, and exclusions above. Changes can be stated by
ID. In particular, the proposed scope includes finite experimental versions of
all 15 visions; it does not commit to completing their unlimited product
horizons or the unscheduled extension catalog.

Confidence is **high** in the named proposal inventory and identification of
already committed browser/server probes, **moderate** in the dependency and
branch grouping, and **low until tested** in hardware/runtime and empirical
feasibility. New implementation evidence, compiler/device results, reference
fixtures or the user's scope corrections could change those conclusions.

This confirmation pass inspected repository plans, selected implementation
sources/inventories, branch history and the experiment checkout, with three
separate Astra High inventory workers. It did not build or test runtime code,
install dependencies, run GUI sessions, capture screenshots, fetch external
references, perform benchmarks, conduct human studies or check remote CI.
