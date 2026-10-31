# After implementation

## Result

`screen.mojo` is a copied runnable workbench with a third `Editor`. The root
owns the third editor and passes the same `Services` used by the left and right
editors. The editor's draft and note remain component-local; only Apply reaches
the shared document, using the current shared permission and length limit.

The root toggle hides the child and replaces its stored editor, discarding
private state. Showing it increments `third_epoch`, constructs a new editor
from current services, and renders it under the new `third_key`. The route
requires both visibility and the current key, so a retained callback or event
from the previous mount cannot reach the new pane. Existing pane fields,
routes, keys, preview scope, inspector behavior, and ordering logic remain in
place.

## Check

Command run from `/Users/davmash/code/moxi`:

```text
pixi run --locked mojo run -I /Users/davmash/code/moxi/experiments/composition-evaluation/author -I /Users/davmash/code/moxi/src -I /Users/davmash/code/moxi/experiments/typed-boundaries -I /Users/davmash/code/moxi/experiments/state-access -I /Users/davmash/code/moxi/experiments/method-binding -I /Users/davmash/code/moxi/experiments/selective-updates /Users/davmash/code/moxi/experiments/composition-evaluation/author/check.mojo
```

Result: exit `0`; `PASS composition: private third editor, shared settings,
hide/show remount, stale callback and event rejection`.

The final check covers private note/draft state, left/right isolation, shared
length-limit and writable-permission behavior, an unsaved draft discarded on
hide, remount from a changed current document, and retained callback plus old
event rejection. The concise final log is `/tmp/moxi-composition-check-3.log`.

## Assistance and limits

No runtime internals or previous experiment conclusions were needed. I read the
specified app-facing sources first, then inspected the existing simple
composition probe and runner only after saving `attempt1.mojo`. No dependencies,
existing files, commits, or pushes were changed. `attempt1.mojo` and the final
`screen.mojo` are byte-for-byte identical because no implementation correction
was required after the check ran.

The unresolved conceptual points are whether omission alone destroys a field's
state and exactly what a retained callback captures; this variant makes those
boundaries explicit with reset-and-remount plus key validation. Human usability,
visual layout quality, held-out checks, and broader repository compatibility
were not established. This is not a human-usability claim.

## Changed sites

- `screen.mojo:8,21-25,38-42,53-65,98-100,105-121` — third-pane state,
  toggle, generation-key route, and conditional child.
- `attempt1.mojo` — immutable first implementation saved before feedback.
- `check.mojo:5-97` — runnable behavioral checks.
- `before.md` — app-facing ownership/routing/lifetime model and uncertainties.
- `attempt-history.md` — first-attempt record and explicit check corrections.
