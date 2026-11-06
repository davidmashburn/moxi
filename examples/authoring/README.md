# Authoring guide examples

Read the [guide](../../docs/authoring/README.md), then run from the repository root:

```sh
python3 examples/authoring/run.py
```

`counter.mojo`, `editors.mojo`, and `shared.mojo` introduce individual patterns.
Their models live in [moxi_demo/authoring_examples](../../src/moxi_demo/authoring_examples/)
and are shared by the runners, native windows, and Playground pages. Open
`pixi run demo` and choose Counter → Form → Editors → Shared document → Workspace.
The Demo tab shows the running model alongside an excerpt; Source names the
complete model file. Counter and Form also retain `pixi run counter-demo` and
`pixi run form-demo`. The other standalone lessons run with `pixi run authoring-editors`,
`pixi run authoring-shared`, and `pixi run authoring-workspace`.

These lessons teach application authoring. Nested Containers, Composed, Rows,
Alignment, Wrapped Text, and Wx Style teach component composition and layout;
use them when you need those lower-level contracts. Plotting, scene, Metal,
fractal, and Live Script pages retain their specialized rendering/host paths.
`workspace.mojo` combines them: a shared document, keyed groups, and keyed drafts
inside each group. Add, close, reverse, and reset operate through ordinary methods;
the workspace needs one handwritten route to supply the shared document.

To try extending it without a supplied solution, use the
[group-action authoring trial](human-trial.md). It includes a behavior checklist
and prompts for recording confusion; human comfort has not yet been evaluated.

`check.mojo` verifies the introductory examples. `workspace_check.mojo` checks
nested reorder, current-value action dispatch, retirement of whole groups and
individual drafts, surviving sibling actions, root reset, and pointer editing
after scrolling. `draft_revert_check.mojo` checks dirty status after a sibling
save, draft and group Revert through nested reordering, preserved keys and order
for added and empty drafts, and rejection after group removal and replacement.
The runner compiles and executes all four applications and all three checks
against production `moxi.authoring`.
The checks also run in the standard test and portable headless CI lanes.

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
   saved title stays unchanged until you click Apply. Status becomes Dirty when
   local text differs from the saved title. Apply can make another draft dirty
   without changing that draft's text; Revert copies the current saved title into
   just the selected draft.
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
worked. A subsequent native probe isolated a missing accessibility-focus input
path: focus setters now queue an addressed `FocusEvent`, while fields continue
to reject button-style AXPress. Regression checks cover focus/blur, same-batch
typing, retired/disabled targets, and publication without input feedback. The
exact operation behind the automation tool's original click remains unknown;
this is not an accessibility conformance claim. Physical IME, window resizing,
performance, and unassisted human authoring were not evaluated in this smoke check.

## Embedded page lifetime

Playground remains a `Component` application. It mounts each authoring model
through `ComponentSlot[HandlerHost[...]]`, forwards clipboard and request
reconciliation, and preserves models while switching pages. Reset replaces only
the selected model. The native loop finishes its current input batch before
publishing replacements, so already-queued input cannot act on a new model and
unrelated navigation, resize, or request work is retained. Addressed callbacks
from retired controls are rejected by monotonic, disjoint control IDs.

Request reconciliation retires stale owned work; live asynchronous completion
delivery requires a separate owner-based route that Playground does not provide.
These lessons schedule no requests. See the
[embedding contract](../../docs/authoring/application-guide.md#mounting-a-model-inside-a-component-application)
before adding asynchronous work to an embedded lesson.

Form keeps its name/hint, Unicode editing, selection, clipboard, composition,
and submission behavior. Its presentation now uses the authoring column's
16-pixel padding and standard control heights instead of the old panel frame.
Workspace uses the existing content portal to scroll its complete nested form.
`tests/demo_authoring.mojo` covers embedded editing, identity, and scrolling;
`tests/native_demo_authoring.mojo` covers native queue order, reset, and late
accessibility callbacks. These probes do not establish physical IME or VoiceOver
conformance.

## Workbench boundary

The Data Workbench toolbar/filter/import region remains a lower-level component.
Its threshold editor feeds numeric parsing, data filtering, table scroll reset,
and plot refresh; its import editor shares clipboard and layout handling with
that region. Moving only these controls into authoring would add a state/output
adapter while losing the existing compact row layout. The current authoring
column does not simplify this boundary. Revisit after a standalone panel has a
clear ownership and commit contract; this migration adds no Workbench wrapper.
