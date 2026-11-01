# Authoring guide examples

Read the [guide](../../docs/authoring/README.md), then run from the repository root:

```sh
python3 experiments/authoring-guide/run.py
```

`counter.mojo`, `editors.mojo`, and `shared.mojo` are small headless applications.
`check.mojo` verifies action delivery, keyed reorder, local versus shared state,
and assignment versus reset. The runner compiles and executes all four against
the lifetime-contract prototype. It does not open a native window or benchmark
rendering.
