# Scoped mount identity experiment

Intent: remove collisions between independent sibling mount counters without
changing application ownership or methods. A typed MountKey contains a stable
sibling slot and a generation; these are encoded separately and delivered intact
to the existing route. Static integer keys remain supported in a disjoint path
namespace. A generation is meaningful only within its stable slot and owner.

Boundary: copy the experimental binding/runtime into this directory; preserve
production, historical experiments and the frozen author attempts. No new
language, model wrapper, automatic dependency tracking or implicit reset policy.
This slice does not solve root/collection/session replacement or claim universal
comfort. Generation guards remain explicit. Stable slots still must be unique.

Verification: the original 101-remount held-out collision, ordinary author checks,
independent counters with equal generations, stale actions/events, nested owners,
legacy integer-key compatibility and unchanged replacement counterexamples. Record
code size and the exact ceremony; do not confuse correctness with reduced burden.

## Authoring tradeoff

The application still owns ordinary fields and declares children with inferred
`ui.child(...)` calls. A remountable child uses:

```mojo
def third_key(self) -> MountKey:
    return MountKey(THIRD_SLOT, self.third_epoch)

def route_third(mut self, key: MountKey, action: Action[Editor, Services]):
    if self.show_third and key == self.third_key():
        action(self.third, self.services)
```

The root/composition module grows from 108 to 110 code lines (excluding comments,
blank lines and docstrings). The key type/encoder adds 18 shared code lines; the
copied runtime/bindings gain a generic key parameter. No per-call generic
arguments are needed. This removes arithmetic range coordination, not explicit
routes, sibling slot allocation, generation increments, or visibility checks.
The path encoder accepts Int or MountKey, not arbitrary application key types.

High confidence in the narrower correctness improvement: distinct sibling slots
cannot collide merely because their generation counters meet. Duplicate slots
within one parent remain an application error, detected as duplicate identity
when mounted concurrently. Generation reuse after replacement and integer
exhaustion are not addressed. Moderate confidence that this is a better example
idiom; no new unfamiliar-author or human usability trial establishes comfort.

## Reproduction and scope

Run `python3 experiments/scoped-identity/run.py`. The runner records commands,
compiler/platform, source hashes, outputs and line counts in `results.json`.
The frozen first author's collision fixture is executed unchanged against the
new screen/runtime. Legacy field adapters and nested application behavior run
against the candidate bindings; replacement characterization must retain its
exact six observations, including three unsafe-new-lifetime counterexamples.

This experiment does not include retained-record reclamation. That independent
candidate lives in `../bounded-retention`; the combined compatibility runner overlays its RetainedUI into a temporary
copy of this runtime without modifying either candidate. No production suite, native event-queue or pixel
validation, CI, or human comfort study is part of this slice.

The nested fixture initially crashed Mojo 1.1.0 (exit 139) when assigning
`app.component.root.reverse = True`. Prefix isolation passed through capturing
the old action and failed when this assignment was added. Moving that mutation
into `Root.reverse_children()` allowed the complete fixture to execute. A
minimal nested declaration and the same routing with a real context both
compiled; this is a compiler obstacle/workaround, not a diagnosed runtime bug.
The final fixture additionally verifies that the context-bearing route mutates
the supplied copy's context and that a rejected old generation leaves context
unchanged. Initial logs remain in `/tmp/moxi-nested-*.log` on the test machine.


Seven standalone checks pass: ordinary workbench behavior, unchanged held-out
collision, editing churn, nested routing, legacy field adapter, legacy application
behavior, and exact replacement characterization. See `results.json`.

`python3 experiments/scoped-identity/run_combined.py` adds a temporary combined
runtime and runs ordinary/collision/nested/editing checks plus retention edges.
It explicitly bounds record count during typed-key churn, moves the focused
editor during active IME, checks removal of all controls/indexes, same-path
remount with a fresh event ID, removal of focused controls, discarded IME, and
independent retirement in a copied retained host. This checks compatibility;
it does not benchmark the combined runtime.
