# Changelog

## 0.3.0 — Unreleased

- Added composable `ViewNode` leaves and `ColumnView` composition.
- Added deterministic vertical layout with padding and spacing.
- Added retained `ColumnRuntime` reconciliation and ordered `PaintCommands`.
- Added computed-bound hit-testing and layout/paint contract coverage.
- Added the value-based `Component` contract and component lifecycle coverage.
- Added `App` for component mount, update, resize, rebuild, and render flow.
- Added backend-neutral `Color`, `Style`, `Panel`, surface, and leaf styling.
- Added resize-aware root bounds and a resizable native macOS window.
- Updated the native macOS renderer to draw multiple labels and buttons per
  frame.
- Reworked the counter demo to use the composed view and command stream.
- Added a minimal component example and expanded the architecture guide.
- Added current architecture documentation and labeled the long-term spec as
  design notes.

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
