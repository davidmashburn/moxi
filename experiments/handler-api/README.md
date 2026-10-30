# Ordinary Mojo handler experiment

This is a bounded authoring experiment, not a public Moxi API. It runs against
`feat/data-workbench` at `c8c7cbb` without changing production code, adding a
dependency, parsing another language, or generating application source.

```sh
bash experiments/handler-api/check.sh
bash experiments/handler-api/native.sh
```

The native demo contains two independent instances of the same form. Read
[`examples.mojo`](examples.mojo) for the actual compiled application source and
[`runtime.mojo`](runtime.mojo) for the temporary adapter. Terminal results,
diagnostics, native observations, and source hashes are in [`results.txt`](results.txt).

## The authoring idea

Rendering reads application state; handlers receive mutable state when called.
For example, these are the compiled counter methods:

```mojo
def increment_shared(mut self):
    self.shared += 1

def render(self, mut ui: UI[Self]):
    ui.label("Independent counters")
    counter(ui, self.first, Self.increment_first)
    counter(ui, self.second, Self.increment_second)
    ui.label("Shared counters")
    counter(ui, self.shared, Self.increment_shared)
    counter(ui, self.shared, Self.increment_shared)
```

The reusable counter takes a value and an ordinary function:

```mojo
def counter[S: ImplicitlyCopyable](
    mut ui: UI[S], count: Int, increment: def(mut S) thin -> None,
):
    ui.button("Clicked " + String(count) + " times", increment)
```

The form similarly supplies `Self.set_name`, `Self.set_use_nickname`, `Self.save`,
and `Self.restore`. Its Save method computes the selected name from current state,
so it does not capture a potentially stale derived local from rendering. The
native demo's Save records a String in application state; it performs no network
or filesystem I/O.

## Execution and identity

`UI[State]` stores thin function pointers and, for list handlers, an owned Int item
key. No borrowed application fields are retained. Event dispatch calls one
handler with current mutable state, then calls the read-only `render` once.
Cursor, selection, and composition-only changes refresh the view without invoking
a value-change handler. This is tested separately from actual text changes.

`HandlerHost` bridges to today's `Component.build/update`: it caches the completed
view and callbacks, and `build()` copies and lays out that view for App. Rebuild,
resize, and paint do not dispatch or rerender application code. This bridge is
experimental runtime machinery, not a claim that an abstraction layer vanished.

Fixed sibling controls have positional identity. Named scopes are local to the
parent; each scope has its own positions. Conditional sections use explicit
`begin_scope`/`end_scope`, and list rows scope themselves by item ID. Scope paths
encode key byte lengths to avoid delimiter ambiguity. Duplicate active paths and
changes of control kind at an active position are rejected.

Removed controls retire their native IDs. A later remount gets new IDs, so stale
events from the former mount cannot reach it. Application fields survive hiding;
editor state does not. Reordering a still-mounted keyed row preserves its ID,
focus, cursor, and item context.

**Position is not general-purpose identity.** The check deliberately demonstrates
that two unkeyed text fields swapping order transfer focus to the other logical
item. Same-kind substitution cannot be diagnosed from position alone. Conditional
siblings and reorderable data still require deliberate identity boundaries.

## What this removes, and what it adds

| Concern | Existing Component API | Prior render experiment | This experiment |
| --- | --- | --- | --- |
| Events | Explicit `update` routing and actions | `if ui.button(...)` in mutable render | Stored methods; read-only render |
| Rendering | Separate `build` | Dispatch render plus display render | One display render after dispatch |
| Identity | Explicit node IDs; ComponentSlot namespaces | Root-global strings on controls | Fixed positions plus local named scopes |
| Editable values | Application owns editor synchronization | Borrow fields during render | Values plus setter methods |
| Reuse | Component/ComponentSlot child routing | Borrow ordinary nested fields | Generic value/handler helpers; explicit forwarding to nested state |

This is a qualitative comparison of inspected source, not a controlled timing or
line-count benchmark; the existing `src/moxi/form.mojo` example has fewer features
than the experimental greeting form.

The composition cost is substantial. `TwoForms` contains ten forwarding methods
for five actions on each nested form. The reusable form's signature exposes five
callback types. Rows use `button_for`/`text_input_for` and receive an explicit item
key, which handlers look up in current state. Begin/end scope pairs add another
author rule. These costs are visible in the application source rather than hidden
in demo-specific runtime logic.

The locked compiler accepts stored non-capturing methods. It rejects a captured
closure passed to the thin-handler API. Mojo's
[1.1 closure reference](https://mojolang.static.modular.com/1.1.0/docs/reference/closure-declarations/)
also documents restrictions on escaping closures and the absence of built-in
existential closure storage. This experiment does **not** establish that elegant
typed composition is impossible in Mojo. It does not implement a typed view tree,
compile-time state projection, custom closure erasure, or integration with Moxi's
existing ComponentSlot routing.

## Results and limits

The checks pass through the real Moxi App for independent/shared counters, copied
hosts, form validation/Save/reset, conditional lifetime and stale events, reusable
nested forms, keyed row changes, focus/cursor continuity, shared editors, synthetic
composition, Unicode, App clipboard, and keyboard routing. A counter verifies one
handler then one render for an action; rebuild/resize/paint do not replay it.

Compiler fixtures reject a wrongly typed setter at the call site, mutation through
read-only `self` in render, and a captured closure where a thin handler is required.
The runtime fixture rejects duplicate sibling scopes. Logs preserve the actual
diagnostics; rejecting a fixture is not a claim that the diagnostic is novice-friendly.

The native demo built and opened. Keyboard editing, Enter activation, independent
saves, conditional nickname validation, and editing worked. An automated lowercase
`space` attempt did not visibly activate Save; uppercase `Space` was rejected by
the automation tool (`keyNotFound("Space")`). Native Space behavior is unresolved;
the synthetic App Space event passes. Earlier native accessibility-focus issues
were not re-investigated.

Remaining prototype limits: linear lookup and historical identity records grow
with churn; no list virtualization or memory reclamation; flat vertical layout;
no responsive render branches driven by bounds; direct external state mutations
require `host.refresh()` and `App.rebuild()`; no async/request lifecycle integration.
Read-only `self` prevents direct component mutation during rendering, not arbitrary
external I/O. Exactly-once checks mean once per accepted event, not durable effect
delivery. Handler failures, reentrancy, and production-scale workloads are untested.

Not run: full repository suite, performance benchmarks, other host platforms,
browser behavior, VoiceOver, actual IME input, OS clipboard integration, mouse
caret/drag behavior, or an independent authoring/comprehension study.

**Assessment:** high confidence that separate handler dispatch works in ordinary
Mojo and avoids dispatch-time rendering. Moderate confidence in the usefulness of
this authoring direction; low confidence that this particular composition surface
meets the desired comfort. Keep the architectural separation, but do not promote
this API. Readable nested-state composition and unassisted edits without identity
mistakes would change that recommendation; passing the current behavior checks
alone does not.
