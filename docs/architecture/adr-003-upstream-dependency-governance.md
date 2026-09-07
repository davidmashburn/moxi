# ADR-003: Pin and prove upstream dependencies

Status: accepted for the convergence program.

## Decision

Every upstream integration records a full Git revision, license, package
compiler range, supported platforms, and compatibility result. Moxi may use a
Pixi Git source only after an isolated build succeeds. A flat submodule is
reserved for a necessary compatibility patch that is intended for upstream;
floating branches and unrecorded local checkouts are not dependencies.

## Consequences

- `canvas_mojo` and `dataviz_mojo` stay independently versioned;
- `dataviz_mojo` begins as a development/reference dependency, not a Moxi or
  Python runtime dependency;
- a failed source-package build blocks promotion and is recorded as such;
- lockfile changes are reviewed together with the compiler/toolchain matrix;
  and
- upstream fixes can be removed cleanly when a compatible release lands.

