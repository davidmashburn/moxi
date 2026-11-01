# Authoring guide examples

Read the [guide](../../docs/authoring/README.md), then run from the repository root:

```sh
python3 examples/authoring/run.py
```

`counter.mojo`, `editors.mojo`, and `shared.mojo` are small headless applications.
`check.mojo` verifies action delivery, keyed reorder, local versus shared state,
and assignment versus reset. The runner compiles and executes all four against
the production `moxi.authoring` package. It does not benchmark rendering.

For an interactive macOS window using the same counter model:

```sh
pixi run --locked authoring-counter-build
./dist/moxi-authoring-counter
```

`window.mojo` connects the model to the existing `App.run` loop. Native reset
support is currently macOS AppKit only; the guide explains other backend limits.
