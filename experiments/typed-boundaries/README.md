# Typed component boundary experiment

Research contract, October 30, 2026. Baseline: `feat/data-workbench` at `e66cdd9`.

Test whether whole typed inputs plus ordinary component state provide a correct,
maintainable cache boundary for a heterogeneous application. Compare selective
caches against an always-rebuild reference through real Moxi App views and
paint output. Keep production Moxi and earlier research unchanged.

The workbench has two document editors, a settings panel, activity history,
conditional inspector, independent scratchpad, header, and read-only preview.
Scenarios include local edits, commit/conflict/undo, permission changes, external
transactions, new local/shared reads, hidden/remounted panels, stale actions,
copied hosts and deterministic mixed operations. Component authors retain plain
fields, methods, and render calls; no dirty flags or per-field dependency lists.

The experiment may introduce a generic typed cache in its private runtime.
It must expose all application wiring and costs. Whole-value comparisons are
not dependency tracking; each supplied context is compared in full. The test
must distinguish skipping declarations from selective layout or painting.
No compiler integration, async/effect system, production adoption, universal
comfort or cross-framework timing claim is in scope.

Decision criteria: (1) fresh-render parity after every operation, (2) new fields
and reads do not require cache dependency edits, (3) independent panels stay
cached, (4) conditional lifetime rejects old actions after remount, (5) report
all routing, ownership, snapshot and transaction ceremony. Any failed criterion
must change the recommendation or be repaired and retested.

## Captured result

`python3 experiments/typed-boundaries/check.py` passes eight programs with Mojo
1.1.0 (`8189361e`). Two are expected compile rejections; two are expected
runtime failures exposing positional identity and same-key remount. [`results.json`](results.json)
records commands, output, the generated editor, and 153 source hashes.

The ordinary editor is imported unchanged from `state-access`. The base and
extended application each execute 500 mixed transactions, plus focused domain,
lifetime, and editing scenarios. After every paired operation the selective
and forced-refresh hosts have equal root values, complete `ViewNode` values,
and complete `PaintCommand` values, including identities, geometry, semantics,
selection, composition and changed flags. Root layout metadata and paint-stream
changed/removed counts, dirty bounds and removed regions also match. Both use the same composition and
routing implementation: this isolates caching errors; it is not an independent
implementation of the whole runtime. Separate expected-state assertions check
commits, conflicts, undo, validation, Unicode, permissions, and local isolation.

Measured declaration counts in the base workbench:

| Operation | Boundaries checked | Boundaries rendered |
| --- | ---: | ---: |
| Edit left editor's private note | 8 | 1 |
| Commit shared document name | 8 | 5 |
| Change an undisplayed setting | 8 | 5 |

The five shared readers are the left/right editors, activity, preview, and
inspector. Header, scratchpad, and settings remain cached for the name commit.
The undisplayed setting also rebuilds Settings and all four `Services` readers,
while the document-only inspector stays cached. This is conservative
over-invalidation, not automatic read tracking.
Each check can traverse a whole value; eight checks is not eight constant-time
operations. Parent composition, App reconciliation and paint still visit the
whole composed view.

The generated extension adds `reviewer`, its setter/input, and a label reading
`settings.max_length`. Host, boundary, and workbench source stay byte-identical.
The new local field rebuilds one boundary; a limit change updates all three
editor labels. A read outside Inspector's `Document` context is rejected by
the compiler. The cache's redundant generic context type is also checked by a
compile-time assertion before its `rebind`; an incorrect type is rejected.

Conditional inspector removal/remount rejects both an old retained callback
and an old targeted event; the new inspector has empty local state. A copied
host routes actions to its current copied model even with an old cached context. Focus, caret insertion, IME
composition across a sibling update, and resizing preserve parity. This does
not cover arbitrary async work or all event types.

## A separate authoring failure: positional identity

Inserting a conditional notice before an input changes its positional path.
The unscoped fixture fails with `control kind changed: /p1`. This happens in
ordinary retained reconstruction too; selective updates are not its cause.
Putting the conditional block in the existing named scope preserves the input
ID and active composition:

```mojo
if self.notice:
    ui.begin_scope("notice")
    ui.label("Unsaved changes")
    ui.end_scope()
ui.text_input("Note", self.note, Self.set_note)
```

This is evidence against calling the authoring API universally easy. The
fixture tests both the failing unscoped version and the scoped repair. Other
structural changes, such as same-kind reorder, need their own identity policy;
this experiment does not claim to solve those.

## Ceremony and limits

- Ordinary setters and commands need no dirty calls or per-field input lists.
  That comfort survives this application and the generated extension.
- `host.mojo` still spells out each boundary's type, construction, refresh,
  composition and dispatch. `workbench.mojo` supplies eight routes and the
  inspector lifetime policy. This is experiment wiring, not an acceptable
  claim of automatic arbitrary-tree composition.
- Typed contexts delimit available input; they do not infer reads. `Services`
  includes history, so an editor still compares data it does not display.
  Each changed boundary stores an owned snapshot; the preview additionally
  copies services to override permission. Large shared models can be expensive.
- Equality assumes owned values and complete equality contracts. Mutable
  aliases, external resources, custom equality that omits rendered state,
  render effects and external mutation without refresh are outside the contract.
- External writes require host refresh followed by App rebuild. The tests
  explicitly perform both. Routed actions do this through the host/App path.
- Same-key remounts fail explicitly; routes must still check mounted authority.
  The guard cannot revoke an arbitrary retained callback by itself. Mount IDs increase; control IDs use a fixed 4,096-slot namespace and fail
  closed when exhausted. Retired control records are not compacted.
- Generic constraint attempts using only `Child.Context` were not accepted in
  this prototype by the installed compiler; the explicit `C` parameter plus
  compile-time equality assertion is the working implementation. This does not
  establish that no better Mojo formulation exists.

No production API adoption, renderer/GPU test, allocation profile, arbitrary
dynamic collection coverage, async race test, human usability study, or full
Moxi regression run is claimed. Earlier experiment files and production sources
are unchanged. Cost measurements are below and in `selective-costs`.

## Whole-frame cost counterexample

`python3 experiments/typed-boundaries/cost.py` compiles once with `-O3`, then
runs one warmup and three measured samples per mode/history size. The timer
covers actual `App.update` plus `App.paint` for the same local draft edit; setup,
correctness checks, and destruction are outside it. This is backend-neutral CPU
work, not native/GPU latency. Raw samples/provenance are in `cost-results.json`.

| History entries | Cached median (range), ms | Forced median (range), ms |
| --- | ---: | ---: |
| 0 | 0.126 (0.124–0.127) | 0.143 (0.142–0.144) |
| 10,000 | 0.320 (0.320–0.322) | 0.193 (0.192–0.194) |
| 100,000 | 2.503 (2.245–2.571) | 0.742 (0.701–0.830) |

Cached renders one component; forced renders eight, and also refreshes its
snapshots. The forced path short-circuits equality. In this case the conservative
comparison work outweighs the avoided declarations even though both paths
have snapshot/preview-copy costs. These are three machine-local samples, not a
stable universal speed ratio. The machine was not isolated from other work.
They decisively invalidate the assumption that
fewer component renders always make this workbench faster.

Recommendation: keep the ordinary authoring surface, but do not install this
whole-context equality strategy as an unconditional default. It is a useful
correctness baseline and a possible bounded optimization. Whole-frame evidence
must justify enabling it for a particular boundary/model size. This experiment
does not implement a replacement observation mechanism or establish the best
way to avoid broad comparisons.

## Independent review follow-up

A static review challenged permission evidence, lifetime enforcement, the
comparison oracle and snapshot assumptions. The revised run:

- Uses a valid short draft, verifies permission toggles and rejected dispatch,
  and invokes the preview command directly to check read-only behavior beyond
  disabled controls. Shared name, history and commit count stay unchanged.
- Rejects same-key remount in the generic cache; the existing inspector route
  separately rejects callbacks/events from its prior mount.
- Checks root layout and paint-stream dirty/removed metadata as well as every
  retained node and paint command. The reference forces declaration rebuilding
  while preserving controls; it is not a fresh independent retained runtime.
- Dispatches a copied host against a changed root without refreshing its cached
  context first. Actions resolve current state rather than replaying snapshots.
- Separately demonstrates that an undisplayed setting rebuilds five boundaries.

The compiler crashed when an additional render-count assertion was placed in
the large behavior program. The same hidden-setting question is tested in the
small `overinvalidation.mojo` fixture, which passes. The compiler crash itself
was not fixed or reported upstream. This workaround adds no production code.

Owned-value/full-equality assumptions, adding a ninth boundary's wiring, async
lifetimes and human comprehension remain open; the review did not verify them.
