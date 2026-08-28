# Changelog

## 0.2.0 — 2026-08-27

- Added `CounterState`, `CounterView`, and retained counter widgets.
- Added primary-pointer click events, rectangle hit-testing, and a bounded
  native event pump.
- Added a native macOS counter button and `examples/counter.mojo`.
- Added state/update contract coverage in `tests/counter.mojo`.

## 0.1.1 — 2026-08-27

- Added Pixi package-build metadata through `pixi-build-mojo`, so Moxi can be
  consumed as a Pixi-built Mojo package.

## 0.1.0 — 2026-08-27

Initial experimental preview.

- Added the `moxi` Mojo package and Pixi-pinned development workflow.
- Added declarative labels, retained runtime state, and paint commands.
- Added backend-neutral renderer and window contracts.
- Added a native macOS AppKit window and canvas renderer.
- Added a visible `Hello from Moxi` example and core smoke test.

Known limitations are documented in [README.md](README.md).
