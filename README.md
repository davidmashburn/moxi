# Moxi project planning

This orphan branch is the planning record for Moxi. Product code lives on
`main`; planning commits must not copy the implementation tree into this
branch.

The current planning baseline is:

- implementation: `main` at `a34963f` (`fix: restore benchmark baseline
  integrity and record the trait contract`), audited September 10, 2026, with
  the three-package restructure, module splits, and the packaging/trait-contract
  follow-on landed;
- research: [`docs/modular-ecosystem-research.md`](docs/modular-ecosystem-research.md),
  the Modular/Mojo ecosystem review captured September 6 and reconciled
  against the September 7 implementation; and
- validation: the 70-program Mojo test suite passes; release validation covers
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

- [APPLICATION-VALIDATION-PLAN.md](APPLICATION-VALIDATION-PLAN.md) expands the
  September 18 assessment into a proposed macOS data-workbench milestone,
  with native interaction, authoring usability, and measured performance gates.

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

The immediate recommendation is to preserve the landed contracts and build
one useful application through them. Follow
[APPLICATION-VALIDATION-PLAN.md](APPLICATION-VALIDATION-PLAN.md), beginning with
a fixture-driven data exploration workflow and real desktop validation (S3).
Let reproduced application friction inform the oversized-struct decision (S2)
and API improvements. Additional host baselines remain a support follow-on;
new widget, plot-family, and platform breadth should wait for application
evidence. This September 18 planning update did not rerun the historical
validation recorded above.
