# Authoring guide examples

Read the [guide](../../docs/authoring/README.md), then run from the repository root:

```sh
python3 examples/authoring/run.py
```

`counter.mojo`, `editors.mojo`, and `shared.mojo` introduce individual patterns.
`workspace.mojo` combines them: a shared document, keyed groups, and keyed drafts
inside each group. Add, close, reverse, and reset operate through ordinary methods;
the workspace needs one handwritten route to supply the shared document.

`check.mojo` verifies the introductory examples. `workspace_check.mojo` checks
nested reorder, current-value action dispatch, retirement of whole groups and
individual drafts, surviving sibling actions, and root reset. The runner compiles
and executes all four applications and both checks against production
`moxi.authoring`. Both checks also run in the standard test and portable headless
CI lanes.

The workspace check locates controls by internal structural paths and declaration
positions. That is test scaffolding, not code application authors need to write;
changing the example's control order can require updating those selectors. The
applications are headless: these checks do not establish native visual fit, human
usability, or rendering performance.

For an interactive macOS window using the same counter model:

```sh
pixi run --locked authoring-counter-build
./dist/moxi-authoring-counter
```

`window.mojo` connects the model to the existing `App.run` loop. Native reset
support is currently macOS AppKit only; the guide explains other backend limits.
