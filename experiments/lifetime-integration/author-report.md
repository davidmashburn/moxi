# Author trial report

## Scope

This is one unfamiliar application-author trial, not a runtime review or human-usability study. The worker authored files only in a temporary directory and did not edit the repository. The parent later preserved the artifacts here.

## First attempt

The first draft was preserved before compilation at:

`author-first-attempt.mojo.txt`

SHA-256: `33e14e2b13dde1e0748673570f41bbb4d4bb327def4f524a4a25174f2f9bb5b3`

The staged first-pass command was:

```text
pixi run --locked mojo run -I /tmp/moxi-lifetime-author/stage -I src -I experiments/typed-boundaries -I experiments/state-access /tmp/moxi-lifetime-author/stage/author.mojo
```

First-pass compile result: failed; no behavior run was reached. The compiler reported:

1. `Pane` was used but not imported.
2. `App` cannot be implicitly copied; the draft used `var duplicate = source`.
3. Mojo rejected `deliver(app=source, source_action)` because a positional argument followed a keyword argument.

The original diagnostic log was temporary; the exact first draft and the three
reported compiler failures above are preserved here.

## Corrections

The final draft at `author.mojo` made only these corrections:

1. Imported `Pane` from `runtime`.
2. Replaced implicit `App` copying with `App(HandlerHost[Workspace](copy=source.component), Rect(...))`, using the existing explicit host-copy constructor and a fresh application wrapper.
3. Changed the final delivery call to positional form: `deliver(source, source_action)`.

Final SHA-256: `13154cf6dd0b4594d492afb1b959ac3f8748a9d1eeb5c37aad760d74c62b5b6b`.

## Final result

The same staged command completed with exit code 0 and printed:

```text
PASS author-facing two-draft lifetime contract
```

The behavior assertions covered:

- two keyed editors retaining independent text and increment counts;
- reorder preserving each editor's text, cursor/selection, composition, and captured callback identity;
- same-document replacement of editor A followed by a captured pre-replacement button callback updating the replacement;
- `reset(app, Workspace())` clearing both drafts and counts, rejecting the old captured callback and targeted text packet, and accepting a fresh callback;
- a copied host sharing numeric control IDs but rejecting source-host callback/text packets while source and duplicate remain independent.

Parent verification of the final source is recorded in `results.json`.

## Confusing points and sources

The main author-facing confusion was that the README describes copying a host, while `App` itself is not implicitly copyable. The usable existing shape is an explicit `HandlerHost(copy=...)` followed by a new `App`. Locating a targeted control also required scanning public retained controls by kind and ordinal; no named target lookup was apparent in the consulted author-facing examples.

Sources consulted:

- `experiments/lifetime-contract/README.md`
- `experiments/lifetime-contract/runtime.mojo`
- `experiments/lifetime-contract/adapters.mojo`
- `experiments/lifetime-contract/delivery.mojo`
- `experiments/lifetime-contract/retired_scope.mojo`
- `experiments/state-access/probe.mojo`
- `experiments/state-access/application.mojo`
- `experiments/selective-updates/check.mojo`
- `experiments/scoped-identity/stress.mojo`

I did not read `lifetime_check.mojo`, `structure.mojo`, `copy_divergence.mojo`, `unpublished_reset.mojo`, or planning reports before the first attempt was saved; none was needed afterward.

## Limits

This does not establish production readiness, native queue behavior, concurrency behavior, full-suite/CI compatibility, performance, or human author usability. No library, production, commit, push, or external-system changes were made.

## Parent qualification

The source comparison confirms only those three compile corrections. The worker's
replacement method assigns fields rather than a complete Editor value; its selection
check compares cursor/anchor without deliberately creating a nonempty selection.
Those stronger scenarios are covered by the separate preceding lifetime suite, not
established independently by this author trial.
