# Moxi project planning

This orphan branch is the planning record for Moxi. Product code lives on
`main`; planning commits must not copy the implementation tree into this
branch.

The current planning baseline is:

- implementation: `main` at `e3be517` (`perf: refresh stable Mojo benchmark
  baseline`), audited October 4, 2026, with upstream `canvas_mojo` v0.42.0,
  released Mojo 1.1.0, the three-package restructure, module splits, and the
  packaging/trait-contract follow-on landed;
- research: [`docs/modular-ecosystem-research.md`](docs/modular-ecosystem-research.md),
  the Modular/Mojo ecosystem review captured September 6 and reconciled
  against the September 7 implementation; and
- validation: the 71-program Mojo test suite passes; release validation covers
  API/scenario/software/native/browser gates, a 30-run full benchmark, the
  reviewed macOS baseline, and the host-independent quick contract.

## Planning record

- [Scoped identity and retained storage](docs/design/scoped-identity-retention.md)
  removes the demonstrated sibling collision and bounds retained records at 32
  after 1,000 remounts. Minimal 1,000-pane update+paint drops from 22.072 to
  7.347 ms; typed and combined checks pass. Application routing/reset ceremony
  remains; session/replacement policy and merge/CI gates are still open.

- [Composition acceptance evaluation](docs/design/composition-acceptance.md)
  completes the smaller-model author, scale/churn, and replacement probes. Keep
  fields/methods; fix hand-managed identity/lifetime and retained-slot growth
  before stabilizing the prototype. One author succeeds ordinarily but fails a
  held-out key-collision test; 1,000 minimal panes take 21.327 ms update+paint.
  Experiment evidence is committed in `c4f259d`; merge/CI gates remain separate.

- [Simple composition](docs/design/simple-composition.md) records production paint
  integration (82 tests plus paint/native parity) and the simpler eight-pane
  reference: 131 to 85 root/composition lines, five practical edit/identity tasks,
  and 500 differential transactions. Keep ordinary fields/methods; explicit
  routes and lifetime policy remain, and human comfort is still unverified.

- [Paint cost isolation](docs/design/paint-cost-isolation.md) compares identical
  retained trees and temporary runtime optimizations. At 100 editors, the
  combined changes reduce a local cached frame from 33.35 to 4.07 ms without
  changing application code; forced declarations take 4.42 ms. Ten checks pass.
  Prioritize runtime scans while retaining the broad-equality and comfort limits.

- [Typed-boundary confidence](docs/design/typed-boundary-confidence.md) tests an
  eight-region workbench and whole-frame costs. Ordinary fields and methods
  survive the larger correctness test, but whole-context comparisons and the
  earlier selective host both have measured performance counterexamples.
  Keep the authoring foundation; the cache and composition API remain research.

- [Selective method updates](docs/design/selective-method-updates.md) preserves
  the preceding 36 scale cases and missing-dependency failure. The follow-up
  above supersedes its provisional recommendation to make conservative
  selectivity the default direction.

- [Marko 6 Tags API reactivity](docs/design/marko-tags-reactivity.md) adds actual
  compiled browser execution: 375 assertions across three source variants.
  Comfortable local bindings and selective updates coexist; callback capture
  and prop granularity still affect work. No production API decision is implied.

- [State access and update work](docs/design/state-access-comparison.md) compares
  compiled Mojo field/keyed adapters with actual Solid contexts and reactive
  stores. It separates ownership, dependency access and update scheduling;
  current-state ownership remains provisional. Nested routing costs, identity
  reuse and retained callbacks remain explicit adoption limits.

- [Direct method bindings](docs/design/direct-method-binding.md) remove all eight
  per-action adapters while preserving current-state ownership. Eight checks
  pass, including nested reuse, copied-host routing and field extension. This is
  the leading authoring candidate; callback allocation and erased-storage safety
  remain implementation work, and reader comfort is unverified.

- [Shared-document comparison](docs/design/shared-document-comparison.md) runs
  matching behavior, extension and lifetime checks for both ownership choices.
  Six programs pass. Handles save two adapters but retain root routing and add
  sharing semantics; keep current-state ownership as the working default. The
  comparison did not test scoped context or reactive observation; those are
  addressed in the state-access follow-up above.

- [Composition gate](docs/design/composition-gate.md) passes real-App checks for
  independent drafts over a shared document, owner policy, undo, reuse, and
  removal/remount. Eight adapters for four actions remain a visible authoring
  cost, so the comfortable-composition adoption gate stays open.

- [Ownership decision](docs/design/ownership-decision.md) recommends current-state
  ownership as the foundation, with controlled widget boundaries, revising the
  earlier provisional preference for shared cells. All three transports pass a
  common validation/history contract; the remaining adoption gate is comfortable
  composition. Compiler probes also establish constructor inference and the
  limits of read-only receivers around shared mutable handles. This is a
  recommendation with bounded evidence, not an adopted API or performance result.

- [Three complete form ownership designs](docs/design/form-ownership-comparison.md)
  compares current-state projection, shared observed properties and controlled
  values against the same form and edit/lifetime exercises, with an
  [interactive source comparison](docs/design/form-ownership-comparison.html).
  Shared cells make the smallest sharing edit, but comfort remains unproven.
  Small Mojo probes verify shared storage and concrete mutable field projection;
  the UI APIs, observation and lifecycle integration remain proposals.

- [UI pattern inventory](docs/design/ui-pattern-inventory.md) compares sixteen
  framework entries, including Xilem, across ownership, update mechanisms,
  shared editing, identity and effects, with primary sources and an
  [interactive table](docs/design/ui-pattern-inventory.html). The composition
  draft has not established authoring comfort. Reopen the shared editing
  contract before investing in its mounted-child runtime; compare current-state
  projection, observed models and controlled values using complete applications.

- [Composition authoring draft](docs/design/composition-authoring-draft.md) is
  the preceding source-first follow-up: complete independent and shared greeting
  forms, assessed against adding a field, adding an instance and sharing one
  value. Parent routing disappears from the proposed surface, but mounted child
  ownership and the shared input/output interface remain unproven costs. These
  are uncompiled API proposals; runtime implementation is deferred pending the
  authoring-comfort decision.

- [Child routing experiment](docs/design/child-routing-experiment.md) is the
  preceding executable follow-up. Existing ComponentSlot routing removes per-field
  forwarding for independent forms. A shared-value test exposes eager-refresh
  cursor loss; settling before rendering fixes it with one render per affected
  child. Parent routing and settlement remain visible costs, so comfort is still
  unproven and neither experimental API is ready for adoption.

- [Ordinary Mojo handler experiment](docs/design/handler-api-experiment.md) is the
  preceding authoring follow-up. Stored methods separate event dispatch from one
  read-only render; App checks and bounded native interactions passed. Scoped
  identity works for keyed rows, but forwarding methods, explicit item context,
  and conditional scopes remain composition costs. Keep the architectural
  separation; neither experimental API is ready for adoption.

- [Ordinary Mojo render experiment](docs/design/render-api-experiment.md) records
  executable `render(mut self, mut ui: UI)` examples that
  use ordinary fields and borrowed values, with no parser or binding objects.
  App checks and native interaction passed within the documented scope. Stable
  keys and repeatable render bodies remain authoring rules; accessibility focus
  remains unresolved and comfort has not been established by a usability study.

- [Scoped reactivity experiment](docs/design/scoped-reactivity-experiment.md)
  records the binding and tracked-read results, a practical Mojo example, and
  their limits as evidence for authoring comfort. The follow-up
  [authoring comparison](docs/design/authoring-comfort-experiment.md) writes a
  complete form in Marko and two proposed Moxi surfaces, including reusable
  fields, controlled state, validation, and conditional lifetime. Its executable
  follow-up now compiles a small real Marko subset to native Moxi: behavior and
  source-change checks passed, with an unresolved native accessibility-focus
  observation and authoring comfort still unmeasured. These are experiments,
  not changes to implementation priority or public API.

- Independent OSS application ports: [force-directed graphs](docs/design/fdg-port.md),
  [SeedWaterSegmenter](docs/design/sws-port.md), and [SWS4D](docs/design/sws4d-port.md).
  FDG's first slice is implemented in `examples/fdg/` on `main` at `875f714`;
  the segmentation plans remain proposals with their own validation gates.

- [Mojo and Moxi in Jupyter](docs/design/jupyter-integration.md) records the
  implemented Python launch/SVG bridge and proposes notebook verification, an
  inline interactive FDG spike, and evidence gates for a reusable adapter. The
  [browser execution investigation](docs/design/browser-execution.md) and
  [server-backed views](docs/design/server-backed-views.md) now advance as
  complementary tracks: a full web target with local interaction can consume
  reduced views of server-owned data. Each has independent acceptance gates.

- [CURRENT-STATE.md](CURRENT-STATE.md) is the evidence-led implementation
  audit. It distinguishes shipped behavior, experimental slices, and genuine
  gaps.
- [PROJECT-PLANNING.md](PROJECT-PLANNING.md) is the active execution plan. Its
  first gate is deliberately narrow enough to implement without another
  architecture pass.
- [docs/modular-ecosystem-research.md](docs/modular-ecosystem-research.md)
  preserves the source research and records how its recommendations map to the
  current code.
- [CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md](CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md)
  records the proposed Moxi framework/runtime, host, renderer, and Linux
  support boundaries for independent implementation review.

- [APPLICATION-VALIDATION-PLAN.md](APPLICATION-VALIDATION-PLAN.md) expands the
  September 18 assessment into a proposed macOS data-workbench milestone,
  with native interaction, authoring usability, and measured performance gates.
- [WORKBENCH-HARDENING-PLAN.md](WORKBENCH-HARDENING-PLAN.md) follows the workbench
  implementation at `c267311` with fresh-launch checks, native interaction fixes,
  performance attribution, and an independent authoring exercise.
- [Native math editing](docs/design/math-editing.md) proposes WYSIWYG typesetting
  and structured editing with a lossless, human-editable text counterpart. Its
  [backend experiment](docs/design/math-backend-experiment.md) compares SymEngine
  and SymPy before selecting an initial adapter.
- [Native mind mapping](docs/design/mind-mapping.md) scopes a keyboard-first,
  tactile mind-map application and bounded Freeplane import. Its shared
  [canvas interaction framework](docs/design/canvas-interaction.md) provides
  reusable native navigation, direct manipulation, and graph editing, with a
  second consumer to validate the public API.
- [3D interfaces and spatial interaction](docs/design/3d-interaction.md) scopes
  native viewports, manipulators, scientific probes, linked views, and spatial
  components. It separates an initial desktop path from world-space UI and XR
  experiments, with an open renderer decision and explicit validation gates.
- [Idea collection](ideas/README.md) explores 15 broad product visions across
  programming, art, learning, mathematics, physical design, and collective
  decisions, with all 21 earlier concepts retained as references. Its
  [rankings](ideas/RANKINGS.md) separate expressive potential from prototype
  cost; [framework questions](ideas/FRAMEWORK.md) capture supporting contracts.
  These are speculative opportunities, not scheduled execution priorities.
- [docs/not-implemented-pattern.md](docs/not-implemented-pattern.md) scopes the
  reusable "Not implemented yet" UI pattern as a candidate follow-up.
- [docs/post-0.5-roadmap.md](docs/post-0.5-roadmap.md) preserves historical
  proposals moved out of the implementation branch. The
  [execution-plan reconciliation](PROJECT-PLANNING.md#relocated-implementation-branch-proposals)
  assigns their topics to existing gates and identifies superseded backlog
  claims; this archive does not change implementation priority.

Future proposals and execution priorities belong on this branch. Implemented
contracts, usage guides, and validation evidence stay beside product code.
The relocation above is a documentation reconciliation against
`feat/data-workbench` at `c8c7cbb`; it does not refresh the historical baseline
or validation results recorded elsewhere on this branch.

## Rules of record

1. Code is the source of truth for implementation status. A plan item is not
   complete because another document says it is.
2. Every planned slice names an owner boundary, concrete files, validation
   command, acceptance signal, and non-goals.
3. Examples, tests, benchmarks, documentation, and visual references should
   consume the same scenarios instead of maintaining look-alike fixtures.
4. Platform availability is reported in three separate lanes: portable
   contract, buildable host artifact, and linked Mojo runtime.
5. Performance claims require a repeatable workload and a committed result
   artifact. One local timing is diagnostic evidence, not a product claim.
6. Completed proposals are removed or folded into the current-state record so
   the branch remains a decision tool rather than a history of stale TODOs.

The immediate recommendation is to harden the workbench implemented on
`feat/data-workbench` at `c267311`. Follow
[WORKBENCH-HARDENING-PLAN.md](WORKBENCH-HARDENING-PLAN.md), starting with fresh
packaged launch verification and native accessibility activation. Measure native
interaction costs before choosing a rendering optimization. The historical main
baseline above remains separate from this feature-branch evidence; this planning
update did not rerun implementation tests. New widget, plot-family, and platform
breadth should wait for these application findings to be resolved.
