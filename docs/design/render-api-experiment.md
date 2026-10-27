# Ordinary Mojo render API experiment

Status: executable experiment completed October 27, 2026. No public API adoption.

Implementation baseline: `feat/data-workbench` at
[`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
The experiment is uncommitted implementation work in `experiments/render-api/`;
it is not present in that commit. Existing production source was not changed.

## Question and scope

After the [Marko authoring experiment](authoring-comfort-experiment.md), the author
asked for comparable simplicity without another language or abstraction layer.
The earlier state/binding proposals were rejected as confusing. A new sketch
using ordinary fields and controls that report interaction received tentative
positive feedback. The author specifically preferred the method name `render`
over giving both the method and its argument the name `ui`, and authorized this
experiment. That preference is not evidence of general usability.

The experiment implements `render(mut self, mut ui: UI)` in normal Mojo. Its
counter is an ordinary function taking `mut count: Int`; two calls sharing the
same field share state. The form uses ordinary String and Bool fields, normal
conditional statements, text inputs borrowing fields during the call, and button
actions written as `if ui.button(...):`. The runtime retains no field references.
The actual examples compile directly with the repository's locked Mojo compiler.
There is no parser, generated application code, JavaScript, or new dependency.

The application sources live in `examples.mojo`; `runtime.mojo` supplies the
experimental UI and `RenderHost` bridge. `demo.mojo` opens both counter pairs and
the form in a native window. The bridge is necessary to run against today's
`Component.build/update` contract without changing production code. It is an
implementation adapter, not proof that the core contract has already changed or
that abstraction has disappeared.

## What ran

`bash experiments/render-api/check.sh` exited 0. It runs real Moxi `App` behavior
checks and verifies that duplicate keys exit with a specific diagnostic:

- Independent and shared counters, fresh roots, and keyboard activation.
- A late action updates labels and conditionals declared before it. Both shared
  buttons display the new count even when the later button initiated the event.
- One activation increments state once. Rebuild, resize, and paint do not replay
  that action.
- Form trimming, validation, Save, disabled Save, and Restore defaults. Late reset
  updates earlier text inputs, checkbox, preview, and conditional visibility.
- Fields retain their values while hidden; hidden controls reject stale events.
- Focus and cursor continuity across rebuilding/resizing; Unicode deletion,
  synthetic composition/commit events, App clipboard commands, and Tab routing.
- Two editors share a String while keeping separate cursors. Reordering keyed
  fields preserves IDs. A conditional counter's ordinary owner field survives
  hiding and showing it.

`bash experiments/render-api/native.sh --build-only` exited 0, with 14 existing
native-window `as_c_string_slice` deprecation warnings. The packaged native demo
was opened and interaction confirmed independent/shared counters, keyboard focus,
typing/live preview, Save, blank nickname disabling Save, conditional nickname
editing, and Restore defaults. The demo was left open with the form restored.

Accessibility-targeted activation did not transfer focus to the requested text
field. Button activation also retained the prior focus. Keyboard navigation
worked. This repeats the previous experiment's focus observation; the cause was
not isolated between native accessibility behavior and automation. No complete
native accessibility claim is supported.

The exact terminal results and source SHA-256 hashes are recorded beside the
code in `results.txt`; reproduction and implementation limits are in `README.md`.
Native UI observations are manual automation observations, not replayable checks
in `check.sh`.

## Execution and authoring costs

An event enters one render pass. A single enabled control consumes it and may
change application state. A second, event-free render pass constructs the final
view; button calls return false during that pass. This refreshes content above a
late action without rerunning the action. The adapter caches that final declaration
for today's App rebuild/resize path.

There are two explicit rules an author must learn:

1. Use stable, nonempty control keys, unique across the root. Reusing a key for a
   different control kind or duplicating it in a pass is an error. This experiment
   has no component-local key namespaces.
2. Put side effects inside action branches. Unconditional mutation or IO in
   `render` may execute on both passes. The exactly-once check covers guarded
   button actions, not arbitrary Mojo effects. Local calculations still follow
   normal program order within an event pass; there is no reactive recomputation
   of an earlier local before a later handler uses it.

State lifetime is ordinary Mojo ownership. Hiding a function call does not destroy
its owner's fields. Hidden editor state is discarded separately. This is different
from Marko component-local state being recreated on remount, and must not be sold
as identical lifecycle semantics.

One compile correction to the sketch was required: trimming a String into itself
violated Mojo's borrowing rules. The compiled form selects into `source`, then
constructs a separate `selected = String(source.strip())`. The runtime also needed
explicit copy handling to satisfy today's component contract.

This prototype is a flat vertical view with buttons, checkboxes, and single-line
text inputs. It uses linear key lookup and retains historical keys for the root
lifetime. It has no async/effect lifecycle, component-scoped keys, virtualized
lists, responsive render branches on bounds, or automatic external-state update
scheduling. Direct external mutations require an explicit host refresh and App
rebuild. No performance or scalability conclusion follows.

## Assessment

**High confidence in narrow technical feasibility:** the proposed ordinary-Mojo
shape now compiles and drives real Moxi controls; the verified actions settle into
a consistent displayed view without replay. A counterexample in these scenarios
would weaken that conclusion.

**Moderate confidence in authoring promise, with comfort still unmeasured:** the
application no longer owns event switches, editor synchronization, or binding
objects. Complexity moved into the runtime and its repeatable-render/key rules.
Unassisted edits involving reusable components, multiple instances, a long list,
or side effects could change the recommendation substantially. There is no claim
that this is universally easy or ready for public API adoption.

Not run: full repository suite, benchmarks, Linux/cross-platform hosts, browser
behavior, VoiceOver, actual IME input, OS clipboard integration, mouse caret/drag
selection, or a user-comprehension study. This experiment does not resolve the
earlier native accessibility observation or validate the earlier tracked-reactivity
probes. The next authoring assessment should use these actual Mojo sources.
