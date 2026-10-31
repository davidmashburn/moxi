# After repair

## Result

The repair uses a disjoint negative key namespace for third-pane generations.
`Workbench` still owns the third `Editor` and passes the same `Services` as the
existing editors. Hiding still replaces the stored editor, discarding draft and
note; showing increments the third generation, constructs a new editor from
the current shared document, and renders it under a new key. The existing
route guard rejects a retained action whose key is not the visible generation.

The held-out inspector can now advance independently because its positive
generation keys cannot equal a negative third key. No runtime abstraction,
panel, domain, editor, or prior author file was changed.

## Verification

Baseline held-out run against the unchanged round-one candidate:

```text
pixi run --locked mojo run -I src -I experiments/composition-evaluation/author -I experiments/typed-boundaries -I experiments/state-access -I experiments/method-binding experiments/composition-evaluation/author_collision.mojo
```

Result: exit `1`, `duplicate identity: /k3:202`.
Log: `/tmp/moxi-author-round2-baseline-collision.log`.

Repair ordinary behavior and stress check:

```text
pixi run --locked mojo run -I experiments/composition-evaluation/author-repair -I src -I experiments/typed-boundaries -I experiments/state-access -I experiments/method-binding experiments/composition-evaluation/author-repair/check.mojo
```

Result: exit `0`; the check reports a PASS covering private draft/note state,
shared settings and permission, discard-on-hide, current-document remount,
110 third-pane remounts, retained callback rejection, stale event rejection,
and 110 independent inspector hide/show cycles.
Log: `/tmp/moxi-author-round2-repair-check.log`.

Repair import path against the unchanged parent-held-out source:

```text
pixi run --locked mojo run -I experiments/composition-evaluation/author-repair -I src -I experiments/typed-boundaries -I experiments/state-access -I experiments/method-binding experiments/composition-evaluation/author_collision.mojo
```

Result: exit `0`; `PASS independent remount identities coexist`.
Log: `/tmp/moxi-author-round2-repair-collision.log`.

## Exact revisions and burden

- `attempt1.mojo:8-11,56-57` and the matching `screen.mojo` lines: remove the
  `THIRD_BASE = 200` offset, add one named namespace constant, and return the
  negative generation. No fields, route signatures, render branches, or
  runtime APIs were added.
- `check.mojo:2,38,99-135`: import the existing `HEADER` slot, assert the
  negative namespace, and add repeated stale-action/event and independent
  inspector-counter checks. These are supporting verification only.

Implementation burden: one new named constant and one arithmetic change in the
screen (plus explanatory comments); no new runtime abstraction or lifecycle
protocol. Conceptual burden: the workbench now relies on a key-space invariant—
existing slots/inspector generations are positive and third generations are
negative. Future remountable siblings must choose another disjoint namespace.

## Remaining limitations

This verifies the experiment's public retained-control behavior, not native UI
usability or performance. It does not prove that omission alone would destroy
component fields; the explicit editor reset remains the discard policy. It
also does not prove arbitrary queued-event semantics beyond the tested stale
target: correctness still depends on the public retained UI deactivating old
paths and on the route receiving the retained key. A finite `Int` counter can
eventually exhaust its negative range, and future children using negative keys
would need a coordinated namespace. Those limits were not exercised.

The parent-held-out source and all files under `../author/` remain untouched.
