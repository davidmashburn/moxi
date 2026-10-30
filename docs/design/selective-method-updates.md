# Selective updates beneath ordinary fields and methods

The editor-boundary experiment supports keeping the current authoring surface.
With 1,000 editors, typing in the last editor rebuilds one editor's declarations
and retained controls, without changing its fields, setters, commands or
`render`. It also exposes a concrete reason not to make hand-written render
input lists the default: a new shared read silently outgrows an old list.

**Recommendation, moderate confidence:** keep ordinary fields and methods;
continue with conservative component-level selectivity under them. Treat
narrow dependency projections as optional, tested optimizations. This is a
working direction, not an adopted public API or a claim that the frame pipeline
is already selective. A heterogeneous workbench that requires repeated input
bookkeeping, or unacceptable shared-snapshot/frame costs, would change it.

## Scope and provenance

Executed October 30, 2026 with Mojo 1.1.0 (`8189361e`), implementation branch
`feat/data-workbench` at `0764b1b5e8017526a8e94b2b367480a9d7f7590f`.
Experiment sources and results are preserved in [implementation commit `e66cdd9`](https://github.com/davidmashburn/moxi/commit/e66cdd95dcffce3519fb6970087a15fe1821a4db). The runs
used working-tree additions to the baseline above; their manifests retain that
original provenance. Planning is in the existing `project-planning` worktree, based on
`9969376de584045905d43151b08353fc33b02539`. No production sources were edited;
pre-existing documentation and experiment changes were preserved.

Implementation artifacts are `experiments/selective-updates/{selective.mojo,
check.mojo,extension.mojo,check.py,results.json,README.md}`. The result manifest
records exact hashes for imported Moxi sources, baseline authoring/binding
sources, Pixi environment files and new experiment code. The generated extension
source is included. Reproduce with `python3 experiments/selective-updates/check.py`
from the implementation checkout. No experiment source is copied into planning.

This follows the [Marko Tags API experiment](marko-tags-reactivity.md) and
[state-access comparison](state-access-comparison.md). Their existing results
were not rerun or changed here. The original Mojo state-access behavior program
was rerun; the four original authoring files remain byte-identical.

## What runs in practice

An editor still owns plain `draft`, `note` and `error` fields. Its setter assigns
those fields. Its command receives the current shared services. Its read-only
render calls `ui.text_input(..., self.draft, Self.set_draft)` and
`ui.button(..., Self.apply)`. There are no signals or field wrappers, no
new template language, and no dependency or dirty calls in those methods.

The experimental host retains one rendered region per keyed editor. It maps a
routed event to that region, invokes the existing current-state action route,
compares shared inputs once, then refreshes the local editor or every editor
if shared inputs changed. Retained controls preserve text state. The parent
composes the cached views for normal Moxi App processing.

The host is an adapter for the fixed Application/Shell/Workspace/Keyed editor
tree, not a generic implementation of arbitrary `ui.child` caching. Intermediate
panes currently only forward children, so the adapter renders editors directly
and uses the existing keyed current-state route. Generalizing that composition
machinery remains real implementation work. This prototype proves the local
mechanism; it does not hide that work in an authoring abstraction.

## Measured update work

At 1,000 editors; the same formulas passed at 2 and 100:

| Mutation | All shared value state | Explicit display projection |
| --- | ---: | ---: |
| Type in last editor's draft | 1 editor render | 1 editor render |
| Edit its private note | 1 | 1 |
| Change shared document name | 1,000 | 1,000 |
| Change writable permission | 1,000 | 1,000 |
| Change unrelated setting | 1,000 | 0 |
| Change command-only length limit | 1,000 | 0 |

Each editor render builds nine declarations, including one scope container,
and updates its actual retained controls. It re-evaluates all five dynamic
outputs. Thus a local edit evaluates five outputs here, versus one effect/leaf
in the earlier Solid/Marko examples; a shared name change evaluates 5,000 here,
versus 1,000 in Solid and the narrower Marko variants. These are different
measured units/stages, not equivalent-time benchmarks. No new cross-framework
performance ranking follows.

Both policies perform one shared-input comparison per measured mutation and
zero full fallbacks. Neither checks 1,000 per-editor dependency keys on a local
edit, unlike the preceding memo projection probe. The narrow policy skips even
editor enumeration for an unrelated service change. The conservative policy
fails that particular optimization gate: it rebuilds all readers.

That one shared comparison is not O(1). Conservative equality can traverse the
entire document history, and a changed snapshot copies that history. A separate
10,000-entry test verifies detection of a late history mutation and snapshot
independence; timing, copied bytes and allocation counts are unmeasured.
Existing `Keyed.route` also scans editor membership; editing the last child in
the scale test deliberately keeps that cost present. The binary-search cache
index does not remove it.

Parent composition still copies/visits all cached views, and the normal App
layout/reconciliation/paint pipeline remains broad. Counts cover editor render
and retained-control reconstruction, not a constant-time event or frame. The
full-render correctness oracle runs outside those measured counters.

## Where comfort survives, and where it breaks

| Change | Conservative shared comparison | Explicit display projection |
| --- | --- | --- |
| New local reviewer field | Field, setter and UI declaration only | Same |
| New label reading the length limit | UI declaration only | Must also update projection |
| Local event handler | Ordinary mutation; host discovers target | Same |
| External service-only mutation | Host `services_changed()`, then App rebuild | Same |
| Unknown direct local/root mutation or topology change | Full `refresh()` fallback | Same |

`AllInputs` uses recursive reflection and ordinary value equality, so its field
list does not need maintaining. `DisplayInputs` stores the shared name and
writable flag. In the extension test, adding a limit label makes that list
incomplete: changing the limit performs zero renders and leaves the label
stale. An independent full render detects the mismatch. Adding the limit to the
projection repairs it. The oracle is test machinery, not an always-on guard.

Command reads are a separate matter: changing a hidden validation limit need
not rerender the original form, but the retained Apply action must use the
current limit. Both policies passed that check, as well as document replacement
and copied-host routing. Cached render output did not turn commands into stale
closures over old application state.

There is still boundary discipline: writes outside host-routed actions are not
automatically observed. An external service transaction calls the host’s
`services_changed()` and then `app.rebuild()`; the latter composes the caches into the actual App view.
A negative/positive check verifies that the cache alone changes first and the
visible limit label updates only after App rebuilding. Normal routed events
already trigger that App rebuild. Unknown local/root writes use explicit full
refresh of both host and App. Child actions are assumed to mutate only that value-owned child and Services.
Reflection is not tracking for mutable shared pointers, foreign resources or
custom equality that ignores relevant state.

## Verification and limits

Three compiled programs pass, including 36 measured scale cases:

- Both policies through real `App`: private drafts/notes, normalized commit,
  conflict/reload, undo, validation/Unicode, permissions, repeatable rendering,
  replacement and current settings, independent copied hosts, retained callback
  rejection after remove/append, 100 remounts, reorder and direct-write fallback.
- Retained caret and clipboard behavior, plus all cached node text/kind/enabled/checked
  values checked against a fresh full render. Scale uses real retained input
  and action dispatch, not a sink-only simulation, but omits full App frame work.
- Generated new local field and new shared read; expected missing-dependency
  mismatch and explicit repair; a 10,000-entry shared history correctness probe.
- Original state-access behavior suite, including its known negative control:
  replacing the entire keyed collection can reuse identities. This new host
  does not fix that lifetime limitation. Its fixed-size control namespaces also
  remain experimental and fail closed on exhaustion.

Skipped: full Moxi regression suite (production sources unchanged), native UI
or manual interaction, timing, allocation/heap profiling, heterogeneous readers,
provider overrides, conditional mounted subtrees, async races, accessibility
audit, generalized runtime integration and human usability testing. Passing
these tests does not establish universal ease or application-scale performance.

The next gate should use a heterogeneous workbench and measure snapshot,
routing, parent composition and frame costs separately. First try coarse typed
ownership/input boundaries; do not require users to maintain per-field dependency
lists merely to obtain the local editor benefit already demonstrated here.

An [interactive result table](selective-method-updates.html) switches the measured
editor count and mutation while keeping the two input policies side by side.

A focused independent static review found no confirmed defect in the fixed
baseline flow, but identified the external App-refresh evidence gap. The added
actual-view check and explicit two-step contract address it. The review did not
run tests. Its other limits remain: shared comparison cost is broad, and the
node-value oracle does not verify IDs, parentage, geometry, accessibility or
action identity. Behavioral routing checks cover selected actions separately.
