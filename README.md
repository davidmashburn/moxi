# Moxi

Moxi (pronounced “moxie”) is an experimental native UI library for Mojo. The
name combines “moxy” with Mojo and keeps a small nod to the `xi` lineage behind
Xilem.

The `0.3.0` preview extends that architecture with a small composed view tree:
declarative children are laid out into retained bounds, reconciled into an
ordered backend-neutral command stream, and drawn by native AppKit. A small
`App` helper now owns the component/update/rebuild loop, while `Style` and
`Panel` keep simple visual choices out of the native backend.

## What works

- Mojo package precompilation through Pixi.
- Retained runtime state for declarative labels and buttons.
- Composable `ColumnView` containers with ordered `ViewNode` children.
- Deterministic vertical layout with uniform padding and spacing.
- Backend-neutral `PaintCommand` and `Renderer` contracts.
- Ordered `PaintCommands` streams for a complete frame.
- Backend-neutral RGBA `Color`, `Style`, and rounded `Panel` primitives.
- Separate `WindowBackend` and `WindowConfig` contracts.
- A native macOS AppKit window and canvas renderer.
- Resize-aware root layout and repainting in the native counter example.
- A visible demo that renders multiple labels and buttons from Moxi commands.
- An interactive counter demo with primary-pointer events and state updates.
- A value-based `Component` contract used by the counter example.
- A high-level `App` lifecycle helper and a component example.

## Current scope

This is an experimental `0.3.0` preview, not a complete UI framework yet.

- Supported demo target: macOS on Apple Silicon (`osx-arm64`).
- The current layout supports a vertical `ColumnView` of leaf labels and
  buttons with caller-provided heights. It does not yet provide intrinsic text
  measurement, row/grid layout, keyboard input, accessibility, focus,
  animation, clipping, or arbitrary nested containers.
- The macOS adapter translates primary-pointer clicks into Moxi events and the
  counter demo updates its state and paint commands in response.
- The native adapter is a small Objective-C AppKit shim. There is not yet a
  cross-platform or GPU renderer.
- Public APIs may change before `1.0`.

For the implemented architecture, see [ARCHITECTURE.md](ARCHITECTURE.md).
[SPEC.md](SPEC.md) is long-term design material and includes ideas that are not
implemented in this preview.

## Quick start

Install [Pixi](https://pixi.sh), then run:

```sh
pixi run mojo --version
pixi run build
pixi run test
pixi run demo
pixi run counter-demo
pixi run component-demo
```

`pixi run demo` opens the native window. Close the window to end the event loop.
The generated `dist/` files and native object file are local build artifacts.

To build the distributable Pixi package:

```sh
pixi build --output-dir output/moxi
```

The resulting conda package contains the compiled `moxi` Mojo package. The
native AppKit demo remains a repository-level example and is not bundled into
the library artifact.

`pixi run counter-demo` opens the interactive counter. Click `Increment` to
regenerate the composed view and repaint the updated count; resize the window
to see the root column relayout.

## Components

Components own state and produce lightweight views. `CounterState` is the
reference component. `App` owns the current view and retained runtime:

```mojo
from moxi import App, ClickEvent, CounterState, Rect

var app = App[CounterState](
    CounterState(),
    Rect(0.0, 0.0, 384.0, 184.0),
)

# After the window backend produces a ClickEvent:
if app.update(event):
    app.render(renderer)

# The same root can be rebuilt after a window resize:
if app.resize(Rect(0.0, 0.0, width, height)):
    app.render(renderer)
```

`Component.build(bounds)` receives the current root rectangle. `update()` and
`resize()` return whether `App` rebuilt its view and retained runtime. Components
are static Mojo value types in this preview; nested component slots and generic
action routing are not implemented yet.

For a component that only needs a view, see
[examples/hello_component.mojo](examples/hello_component.mojo). For explicit
styling, use `add_label_styled()`, `add_button_styled()`, `set_surface_style()`,
and `set_panel()` on `ColumnView`.

## Examples

The static first vertical slice is in
[examples/hello_window.mojo](examples/hello_window.mojo):

```mojo
var runtime = Runtime()
var view = Label(1, "Hello from Moxi", Rect(32.0, 28.0, 320.0, 56.0))
runtime.reconcile(view)
var command = runtime.paint()

var window = MacOSWindow()
var renderer = MacOSRenderer()
window.open(WindowConfig("Moxi", 384.0, 144.0))
renderer.begin_frame()
renderer.draw_label(command)
window.run()
```

The event-driven composition slice is in
[examples/counter.mojo](examples/counter.mojo). It lays out a title, count
label, and button, then regenerates the view and command stream after each
click on `Increment` or root-size change. The smaller lifecycle example is in
[examples/hello_component.mojo](examples/hello_component.mojo).

## Architecture

The implemented contracts and lifecycle are documented in
[ARCHITECTURE.md](ARCHITECTURE.md).

The current data flow is intentionally small:

```text
Component + root bounds -> App -> ColumnView -> ColumnRuntime -> PaintCommands
       ^                         |                 |                 |
       |                         |                 |           MacOSRenderer
       |                         |                 |                 |
  ClickEvent <- WindowBackend <-+                 +-> AppKit canvas
                         resize -----------------+
```

The Mojo core does not own AppKit handles. The platform adapter owns the native
window and translates paint commands across a narrow C ABI boundary.

## Roadmap

The next useful slices are keyboard input, focus, and richer event routing.
Intrinsic measurement and additional layout primitives can follow. Additional
platform and GPU backends should arrive behind the existing contracts only when
they have working demos and tests.

## License

Moxi is available under the [MIT License](LICENSE).
