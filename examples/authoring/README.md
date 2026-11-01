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
individual drafts, surviving sibling actions, root reset, and pointer editing
after scrolling. The runner compiles and executes all four applications and both checks against production
`moxi.authoring`. Both checks also run in the standard test and portable headless
CI lanes.

The workspace check locates controls by internal structural paths and declaration
positions. That is test scaffolding, not code application authors need to write;
changing the example's control order can require updating those selectors. The
automated checks are headless: they exercise hit testing and scroll preservation,
but do not establish native visual fit, human usability, or rendering performance.

For an interactive macOS window using the same counter model:

```sh
pixi run --locked authoring-counter-build
./dist/moxi-authoring-counter
```

`window.mojo` connects the model to the existing `App.run` loop. Native reset
support is currently macOS AppKit only; the guide explains other backend limits.

For the nested workspace on macOS:

```sh
pixi run --locked authoring-workspace-build
./dist/moxi-authoring-workspace
```

`workspace_window.mojo` uses the same `Workspace` model in a 640 by 720 window.
The ordinary column scrolls automatically; there is no example-specific scroll
state. Try this sequence:

1. Click inside Alpha's first draft, select its text, and type a new title. The
   saved title stays unchanged until you click Apply.
2. Reverse drafts, then reverse groups. Scroll to Alpha and find the edited text
   still attached to its original draft.
3. Add a draft, close the first draft, and reset drafts. Reset creates a fresh
   draft; it does not change the shared saved title.
4. Add and close groups. Scroll to reach lower controls; shrinking the content
   clamps the scroll offset.

The November 1 native smoke check verified pointer editing, Apply, nested
reorder, scrolling, and draft reset. The layout is deliberately a long form,
not a finished workspace design: repeated actions and labels use considerable
vertical space. An accessibility-driven click on a text field did not focus it
in this check; a coordinate pointer click did. Button accessibility activation
worked. The cause of that focus difference is not yet isolated, and this is not
an accessibility conformance claim. Physical IME, window resizing, performance,
and unassisted human authoring were not evaluated in this smoke check.
