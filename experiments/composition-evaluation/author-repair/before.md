# Before repair

## Contract

Repair the copied composition candidate after the parent-held-out identity
finding. Keep the third editable `Editor` owned by `Workbench`, with private
draft/note state, shared `Services`, a root hide/show toggle, discard on hide,
fresh construction from the current document on show, and rejection of stale
callbacks/events. Do not change the earlier `author/` artifacts, the parent
held-out source, the unchanged `Editor`/domain/panels, or the runtime API.

## Evidence read

I read the complete round-one artifacts in `../author/`: `before.md`,
`attempt1.mojo`, `screen.mojo`, `check.mojo`, `after.md`, and
`attempt-history.md`. I also read the source-of-truth app files used by the
candidate: `../simple-composition/screen.mojo`,
`../state-access/domain.mojo`, `../state-access/editor.mojo`,
`../typed-boundaries/workbench.mojo`, and `../method-binding/bindings.mojo`.

The held-out source `../author_collision.mojo` mounts the third pane once and
then hides/shows the inspector 101 times. The third key is initially `202`
(`THIRD_BASE + third_epoch`), while the inspector reaches `202` at its 101st
show (`INSPECTOR_BASE + inspector_epoch`). The unchanged held-out run exits
with `duplicate identity: /k3:202`.

## Public API detail needed

I inspected only the relevant declarations and retained-control behavior in
`../method-binding/runtime.mojo`:

- `UI.begin_scope` (`125-129`) converts a child key to a string scope path.
- The two `UI.child` overloads (`151-176`) accept only `Int` keys and retain
  that key in `child_action` routing.
- `RetainedUI.claim` and `finish` (`210-224`, `197-208`) identify controls by
  active path and deactivate unseen old controls.

I read these parts to determine whether the collision was a routing bug or an
identity-space bug and to verify what stale actions/events can be rejected by
the app-owned route. I also read `Action` and `child_action` in
`bindings.mojo` (`50-118`) to confirm a retained child action carries the old
route key. No production runtime source or new runtime abstraction was needed.

## Repair decision

The inspector's existing generations are positive and unbounded for this
experiment; choosing a larger positive offset would only postpone the same
collision. The copied third pane therefore gets a named negative key namespace:
`third_key = -third_epoch`. This is disjoint from the existing stable positive
slots and positive inspector generations while preserving the route's existing
visibility-and-current-key guard.

The initial repair candidate is saved as `attempt1.mojo` before any compile or
test feedback. `screen.mojo` is the copied candidate used by the checks. The
copied check is strengthened to retain old actions and event targets through
110 third-pane remounts and to toggle the independent inspector counter 110
times.
