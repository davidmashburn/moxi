# Moxi

Moxi is a proposed native, reactive UI framework for Mojo. The architecture and
current design constraints are documented in [SPEC.md](SPEC.md).

The package currently provides a minimal retained label model and a visible
demo. Rendering, windowing, input, text, accessibility, and platform adapters
will grow behind explicit interfaces as they become implementable and testable.

## Development

This repository uses Pixi to pin the Mojo toolchain:

```sh
pixi run mojo --version
pixi run build
pixi run test
pixi run demo
```

The generated `.mojoc` is a local build artifact and is not committed.

The core is split into geometry, declarative views, retained runtime state, and
backend-neutral paint commands under `src/moxi/`. The demo currently uses
Tkinter only as a small visible window adapter; it is not part of the core API.
