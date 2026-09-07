# ADR-004: Absorb dataviz capabilities through Moxi contracts

Status: accepted for the convergence program.

## Decision

`dataviz_mojo` is an executable reference and algorithm source during
convergence. Moxi absorbs useful capabilities into `PlotSpec`, `PlotDataTable`,
`PlotRuntime`, `Scene`, accessibility, and the Python facade. It does not copy
the repository wholesale or promise source compatibility with the fluent
`Plot().mark_...().encode(...)` API.

## Definition of done for a mark

A mark moves from reference-only to Moxi-supported only when its inventory row
has schema validation, deterministic Scene output, software/SVG parity,
interaction and accessibility behavior, Python exposure, a real reference
scenario, and benchmark evidence. Differences in data semantics, scales,
layout, text, geometry, color, rasterization, or unsupported behavior are
classified instead of hidden by broad pixel tolerance.

