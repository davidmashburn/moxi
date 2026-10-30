# Ownership decision experiment

October 29, 2026. Decision evidence, not a public API or three complete UI hosts.

Run from the implementation checkout:

```sh
python3 experiments/ownership-decision/check.py
```

`results.json` records the baseline, compiler, commands, outputs and hashes of
the Mojo sources and lockfile used. Logs also go into a new temporary directory.
The existing handler check writes its own ignored diagnostic artifacts.

## What is actually compared

`contract.mojo` gives three transports the **same** domain policy:

- A owns a `Document` value and temporarily projects it for a handler.
- B gives two consumers copied `ArcPointer[Document]` handles. This is the
  stronger, policy-preserving shared-owner version, not an observed cell.
- C owns a `Document` value and queues edits for the owner to apply at settlement.

All pass normalization, rejected/no-op edits, atomic interval changes, one-step
undo/redo, redo invalidation, current-owner Save, ordered commands before refresh,
and 100 edit/undo/redo/save cycles. Local draft cancellation is checked as value
isolation; it is not a text-editing or focus test. `Edit` is only a test transport
format, not a proposed public message/reducer API. A committed domain edit is not
a raw keystroke: real fields need to permit incomplete drafts while typing.

The common domain engine additionally tests superseded and duplicate request
completions, stale results after edit+undo, and entity replacement. These are
deterministic completion simulations, not network/thread tests. Negative controls
demonstrate copied-handle aliasing, raw mutable access bypassing policy in A and B,
and stale controlled props before/after settlement. They assert the bad condition
is observable rather than making the runner itself fail.

`mechanics.mojo` verifies that a read-only receiver, including the actual
experimental `Screen.render(self, ui)`, can mutate an `ArcPointer` pointee.
It also verifies value snapshots versus handle aliases and the already-supported
`App(HandlerHost(TwoForms()), bounds)` constructor inference.

The runner rechecks existing handler event/render contracts, controlled child
settlement and cursor behavior, and production request cancellation/generation
tests. Those fixtures are earlier experiments or existing tests, not new native
UI integrations. Their exact sources are hashed because some are uncommitted.

## Limits

The transport test uses a movable `Document` with `List` history. It does not
implement the implicit-copy requirement of the existing `Component`/`Screen`
traits. Production workbench state provides an explicit copy initializer for
similar storage; choosing copy or move semantics remains an integration cost.
No generic stored paired lens, subscription engine, automatic tracked property,
subscriber teardown, or three-way widget host was implemented here.

No performance winner, end-to-end native result, memory/thread safety proof,
accessibility result, usability result, or full-suite result follows from these
checks. Prior native checks were not rerun. The planning worktree contains the
decision reasoning in `docs/design/ownership-decision.md`.
