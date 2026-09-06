# Moxi project planning

This orphan branch is the planning record for Moxi. Product code lives on
`main`; planning commits must not copy the implementation tree into this
branch.

The current planning baseline is:

- implementation: `main` at `bd3722c` (`feat: preserve component themes and
  document walkthrough`), audited September 6, 2026;
- research: `project-planning` at `823b6a9`, including the Modular/Mojo
  ecosystem review captured September 6, 2026; and
- validation: the 65-program Mojo test suite passes, and the quick benchmark
  harness completes all retained, interaction, plotting, fractal, and Metal
  workloads on the audited implementation.

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

The immediate recommendation is to stop adding breadth until the public API,
localized execution path, shared scenarios, and visual/performance regression
signals form a credible support boundary.
