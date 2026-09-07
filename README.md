# Moxi project planning

This orphan branch is the planning record for Moxi. Product code lives on
`main`; planning commits must not copy the implementation tree into this
branch.

The current planning baseline is:

- implementation: `main` at `7b9d8bd` (`test: cover out-of-order topology
  indexes`), audited September 7, 2026;
- research: [`docs/modular-ecosystem-research.md`](docs/modular-ecosystem-research.md),
  the Modular/Mojo ecosystem review captured September 6 and reconciled
  against the September 7 implementation; and
- validation: the 68-program Mojo test suite passes; release validation covers
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

The immediate recommendation is to preserve the landed Gate 1 boundary while
sequencing the remaining support work: dependency-edge fanout indexing,
accessibility/pointer-capture and deeper localized state preservation, visible
native screenshot review, and additional full-profile host baselines.
New widget or plot-family breadth should wait for those contracts.
