# Ordinary Mojo render experiment

Experimental, not a shipped Moxi API. Implementation baseline: `feat/data-workbench`
at `c8c7cbb7741519c9796a02ffa25c02e701b2f58a`, October 27, 2026.

The application owns ordinary fields. `render(mut self, mut ui: UI)` describes
the screen. Text inputs and checkboxes borrow fields during their calls; buttons
return whether they were activated. No field references survive a call.

The complete author-written examples are in [examples.mojo](examples.mojo).
There is no generated application source, parser, JavaScript, or new dependency.

```mojo
def counter(mut ui: UI, key: String, mut count: Int):
    if ui.button(key, "Clicked " + String(count) + " times"):
        count += 1
```

Independent versus shared state is just which field the caller passes:

```mojo
counter(ui, "first", self.first)
counter(ui, "second", self.second)
counter(ui, "shared-a", self.shared)
counter(ui, "shared-b", self.shared)
```

The greeting form uses the same ordinary fields for name, nickname, nickname
visibility, and the last saved greeting. Save only changes a local string.

## Run

From the repository root, using its existing locked Pixi environment:

```sh
bash experiments/render-api/check.sh
bash experiments/render-api/native.sh
```

`native.sh --build-only` builds without opening the window. The packaged macOS
demo shows both counter pairs and the form. Build artifacts stay in ignored
`generated/`. The demo uses real Moxi `App`, layout, focus, native text editing
state, rendering, and clipboard backends.

## Execution contract

1. A routed event enters one call to `render`. At most one keyed control consumes
   it. A button returns true only for its enabled activation, including keyboard
   activation. Inputs edit their borrowed fields using Moxi's `TextInputState`.
2. Moxi discards the potentially inconsistent view from that pass and calls
   `render` again without an event. All button calls now return false. This second
   view includes changes to content above the action, shared controls, and
   conditionals. Native editor state is synchronized without resetting a cursor
   when its text already matches.
3. Today's `App` rebuild/resize/paint path consumes a cached declaration and
   recalculates layout. It does not replay actions.

**Keep side effects inside button branches.** Unconditional mutations, file IO,
network calls, and similar work in `render` can execute on both passes. This is
not a general exactly-once guarantee for arbitrary Mojo code. Locals are evaluated
in normal program order; this experiment does not make reads reactive or move an
earlier calculation after a later mutation within the same event pass.

Control keys are nonempty strings, unique across the root, stable across passes,
and tied to one control kind. Duplicate keys fail with a diagnostic, rather than
silently sharing identity. Reordering two controls preserves their IDs and editor
state. Hidden editor state is discarded; application fields persist as long as
their owning struct persists. Hiding a counter does not destroy its owner's field.

## What the runtime hides

[runtime.mojo](runtime.mojo) owns the key registry, editor state, event consumption,
clipboard hooks, and the two passes. `RenderHost[Root]` is a **temporary adapter**
to the existing `Component.build/update` contract, used only at app startup. The
experiment necessarily has this implementation bridge; it has not replaced Moxi's
core component contract. Authors do not write event switches or binding objects.

The intended adoption option would put this behavior in Moxi's core. This
experiment neither adopts that option nor establishes that it is preferable.

## Verification and limits

[check.mojo](check.mojo) drives the actual `App`, covering independent/shared
counters, keyboard activation, fresh roots, labels and branches before a later
action, no action replay on redraw/resize, form validation/reset, hidden state,
stale-event rejection, focus/cursor preservation, Unicode and composition event
sequences, App clipboard commands, two editors sharing a string, reordered keys,
and conditional counter lifetime. `duplicate-key.mojo` must fail with a specific
diagnostic. Captured results and source hashes are in [results.txt](results.txt).

On October 27, 2026, `check.sh` and `native.sh --build-only` both exited 0. The
native build emitted 14 existing `as_c_string_slice` deprecation warnings from
`src/moxi/native_window.mojo`. Native interaction confirmed independent/shared
counters, keyboard focus and typing, live preview, Save, blank nickname disabling
Save, conditional nickname editing, and Restore defaults.

Accessibility-targeted activation did not transfer focus to the requested text
field (and button activation retained the previous focus). Keyboard navigation
worked. This repeats the earlier tags experiment's focus observation; the cause
was not isolated between native accessibility behavior and automation. Do not
interpret these checks as complete accessibility coverage.

This is a flat vertical layout with three interactive control kinds. The registry
uses linear lookup and retains previously used keys for the root lifetime; dynamic
key churn is not bounded. It has no component-local key scopes, responsive render
branches on window dimensions, async/effect lifecycle, list virtualization, or
automatic dependency tracking. Root types must satisfy today's copyable component
contract. Direct external field mutations require `RenderHost.refresh()` followed
by the normal App rebuild; external updates are not scheduled automatically.

Mouse caret positioning/drag selection, actual IME input, native accessibility,
cross-platform behavior, performance, and user comprehension require separate
verification. Synthetic composition/clipboard checks do not prove OS integration.
OS clipboard integration, VoiceOver, browser behavior, and the full repository
suite were not run for this experiment.

High confidence is warranted only for the behaviors actually checked. Whether
these rules feel comfortable remains a user assessment, not a test-suite result.
