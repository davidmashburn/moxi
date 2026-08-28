# Moxi 0.3.0 architecture

This document describes the implementation in the 0.3.0 preview. It is the
current source of truth for the public architecture; the larger
[SPEC.md](SPEC.md) is long-term design material and includes proposals that are
not implemented.

## Core contract

Moxi components are Mojo values. A component owns application state, builds a
lightweight declarative view, and handles events:

```mojo
trait Component(ImplicitlyCopyable):
    def build(self, bounds: Rect) -> ColumnView:
        ...

    def update(mut self, event: ClickEvent, view: ColumnView) -> Bool:
        return False
```

`build(bounds)` returns the current view description for the supplied root
rectangle. `update()` returns `True` when the component changed and its view
should be rebuilt. Components do not own native window or renderer handles.

`CounterState` is the reference implementation of this contract. The counter
example uses the same lifecycle as a user component:

```mojo
var app = App[CounterState](
    CounterState(),
    Rect(0.0, 0.0, 384.0, 184.0),
)

if app.update(event):
    app.render(renderer)

if app.resize(bounds):
    app.render(renderer)
```

This is a static, value-based component contract. Moxi does not yet have
dynamic component registries, component-local action enums, or nested
component slots. `App` is the small lifecycle convenience layer; callers can
still use `ColumnRuntime` directly when they need manual control.

## Frame and event lifecycle

The current pipeline is:

```text
Component state
      │ build(root bounds)
      ▼
ColumnView + ViewNode children
      │ layout()
      ▼
App ── reconcile ──> ColumnRuntime ──> retained Widgets
      │ paint()
      ▼
PaintCommands ── draw ──> Renderer ──> native AppKit canvas
      ▲                                      │
      └──── rebuild after update/resize ◄── ClickEvent or Size
```

`App` owns component state, root bounds, and the current view. `ColumnRuntime`
owns the backend-neutral retained widget data. The renderer owns platform
handles. The core package never stores an AppKit object.

## Views and layout

`ViewNode` is the lightweight leaf descriptor. Its `kind` is currently either
`LABEL_KIND` or `BUTTON_KIND`; it carries a stable id, text, preferred height,
and the bounds assigned by layout.

`ColumnView` stores an ordered `List[ViewNode]`. Its `ColumnLayout` applies one
uniform padding value on all sides and one spacing value between children. The
column gives every child the same content width and uses the caller-provided
preferred height. `layout()` must be called after adding children; the older
`layout_children()` spelling remains as a compatibility wrapper.

`ColumnView` can carry one optional `Panel` and a root surface `Style`. Leaf
styles are selected by the default label/button constructors or supplied with
`add_label_styled()` and `add_button_styled()`. The native preview currently
uses fill, text color, corner radius, and font size.

`ColumnView.hit_test()` checks laid-out button bounds and returns the matching
button id, or `-1` when there is no target. The counter component uses this
route rather than duplicating button geometry.

The current layout intentionally does not measure text or support rows, grids,
constraints, nested containers, clipping, or intrinsic resize policies. A
caller can rebuild the root with new bounds; `App.resize()` supplies that
relayout path for the native demo.

## Retained runtime

`ColumnRuntime.reconcile()` converts the current `ViewNode` list into retained
`Widget` values. `paint()` emits an ordered `PaintCommands` stream. Each
`PaintCommand` contains a kind, stable id, backend slot, text, final bounds,
and a backend-neutral `Style`. A frame begins with a surface command, may
contain a panel command, and then emits label/button leaf commands.

The runtime is retained in shape, but 0.3.0 still replaces the widget list on
each reconciliation. It does not yet perform identity-based minimal diffs or
invoke localized `rebuild()` methods. Those are future improvements, not
current guarantees.

The original `Runtime`, `CounterRuntime`, `Label`, and `Button` entry points
remain available as compatibility helpers. New composed code should use
`Component`, `App`, `ColumnView`, and `ColumnRuntime`.

## Rendering and windowing

`Renderer` has these relevant operations:

- `begin_frame()` clears the backend's previous command slots.
- `draw()` dispatches surface, panel, label, and button commands.
- The draw methods translate backend-neutral geometry and style.

`MacOSRenderer` sends commands across the narrow Objective-C C ABI. The AppKit
shim currently supports up to 32 label slots and 32 button slots per frame and
draws them on one native canvas. `MacOSWindow` owns the resizable window
lifecycle, reports its current content size, and translates primary-pointer
clicks into `ClickEvent` values.

The native target is macOS on Apple Silicon only. There is no GPU or
cross-platform backend in this preview.

## Validation surface

The shared counter scenario is exercised by:

- `tests/component.mojo` — component trait, rebuild, resize, and command flow
- `tests/layout.mojo` — exact layout, command order, and hit-testing
- `tests/counter.mojo` — state updates through the component API
- `examples/counter.mojo` — native event loop and visible rendering
- `examples/hello_component.mojo` — minimal public component API

Run the checks with:

```sh
pixi run test
pixi run counter-demo
```

The distributable package contains the core Mojo module. The native AppKit
example remains a repository-level demo and is not bundled into the package.
