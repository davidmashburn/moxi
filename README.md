# Moxi

Moxi is a proposed native, reactive UI framework for Mojo. The architecture and
current design constraints are documented in [SPEC.md](SPEC.md).

The package currently provides the initial public module boundary. Rendering,
windowing, input, text, accessibility, and platform adapters will be added
behind explicit interfaces as they become implementable and testable.

## Development

This repository uses Pixi to pin the Mojo toolchain:

```sh
pixi run mojo --version
pixi run build
```

The generated `.mojoc` is a local build artifact and is not committed.
