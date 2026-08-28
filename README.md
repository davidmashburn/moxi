# Moxi

Moxi (pronounced “moxie”) is an experimental native UI library for Mojo. The
name combines “moxy” with Mojo and keeps a small nod to the `xi` lineage behind
Xilem.

The `0.1.0` release is a deliberately small preview of the architecture: a
declarative `Label` becomes retained runtime state, then a backend-neutral paint
command, and finally native AppKit drawing in a macOS window.

## What works

- Mojo package precompilation through Pixi.
- A retained runtime for one declarative `Label`.
- Backend-neutral `PaintCommand` and `Renderer` contracts.
- Separate `WindowBackend` and `WindowConfig` contracts.
- A native macOS AppKit window and canvas renderer.
- A visible demo that renders label text and bounds from the Moxi paint command.

## Current scope

This is an experimental `0.1.0` preview, not a complete UI framework yet.

- Supported demo target: macOS on Apple Silicon (`osx-arm64`).
- The current runtime supports one label and does not provide layout, input,
  accessibility, focus, animation, or multi-widget composition.
- The native adapter is a small Objective-C AppKit shim. There is not yet a
  cross-platform or GPU renderer.
- Public APIs may change before `1.0`.

The architecture notes in [SPEC.md](SPEC.md) describe the intended direction;
they include roadmap material that is not implemented in this preview.

## Quick start

Install [Pixi](https://pixi.sh), then run:

```sh
pixi run mojo --version
pixi run build
pixi run test
pixi run demo
```

`pixi run demo` opens the native window. Close the window to end the event loop.
The generated `dist/` files and native object file are local build artifacts.

## Example

The complete first vertical slice is in
[examples/hello_window.mojo](examples/hello_window.mojo):

```mojo
var runtime = Runtime()
var view = Label(1, "Hello from Moxi", Rect(32.0, 28.0, 320.0, 56.0))
runtime.reconcile(view)
var command = runtime.paint()

var window = MacOSWindow()
var renderer = MacOSRenderer()
window.open(WindowConfig("Moxi", 384.0, 144.0))
renderer.draw_label(command)
window.run()
```

## Architecture

The current data flow is intentionally small:

```text
Label -> Runtime.reconcile -> PaintCommand
                                  |
                     MacOSRenderer.draw_label
                                  |
                    AppKit canvas + window event loop
```

The Mojo core does not own AppKit handles. The platform adapter owns the native
window and translates paint commands across a narrow C ABI boundary.

## Roadmap

The next useful slices are multi-view composition and layout, followed by
native input events and an explicit update/event loop. Additional platform and
GPU backends should arrive behind the existing contracts only when they have
working demos and tests.

## License

Moxi is available under the [MIT License](LICENSE).
