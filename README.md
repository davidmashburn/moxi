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
