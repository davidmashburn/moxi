# Current-state composition gate

Intent: compile and exercise two reusable editors with independent drafts and a
shared document through the existing real Moxi `App` and handler host.

Boundaries: new experiment files only; preserve existing experiments and public
Moxi APIs. No shared cells, parser, new language, generic UI framework, native
backend changes, or performance claim. The existing handler runtime remains the
event/refresh source of truth.

Scenarios: owner validation, atomic commit and undo, concurrent-draft conflicts,
local note editing, a third instance, nested placement, reorder, removal/remount,
stale events, cursor/focus continuity, and side effects occurring once. Application
code must not contain per-field forwarding or a settlement loop. Count any
component-specific adapter code honestly as an authoring cost.

Ownership: `Document` owns policy and committed history; `Editor` owns its draft,
base revision, local note and error. A single root route temporarily supplies the
current editor and document to a stored thin callback. Nested containers are plain
data and do not forward individual actions. This is a bounded callback route,
not a generic stored lens or a newly adopted public API.

Verification: run the experiment's `check.mojo` through the locked Mojo compiler;
use real App event dispatch, layout, focus, paint and retained input state. Record
results and source hashes after the scenario checks pass. Native interaction,
full-suite execution and usability testing are outside this gate.

## Result

Run `python3 experiments/composition-gate/check.py` from the repository root.
The four scenario groups pass on Mojo 1.1.0 (8189361e). `results.json` records
the command, compiler, baseline, output and source hashes. This exercises the
real App and handler runtime with synthetic events; it opens no native window.

Behavior passes; the comfortable-composition adoption gate remains open.
`Document` owns validation, normalization, commit history and undo. Each `Editor`
owns an incomplete draft, a revision token, a private note and an error. Apply
commits the draft; Reload explicitly discards it and reads the current document.
A stale draft is rejected, including after undo. Those are chosen product
semantics, not requirements imposed by current-state ownership.

Adding a third instance or the private-note field requires no per-field forwarding
in `Application`, `Shell` or `Workspace`. Reusing the editor in the test's second
root requires another root route but no change to the editor. The nested UI scope
is an identity namespace in a flat column, not a nested layout or independent
child host. State-container depth is also tested, not arbitrary component trees.

The reusable component still contains **eight adapter functions for four
actions**, a route trait and a callback type. Its owner implements one lookup
route, which knows the component's type and location. Some bridges accept unused
document/text arguments. Ordinary Editor methods avoid those parameters, but the
component author still writes the bridges. No new runtime code hides that cost.
Stable keys, copy initializers for lists, and the existing HandlerHost are further
visible requirements. This is not a demonstrated authoring win over shared handles.

Policy updates in the test use two Document methods because direct assignment to
the deeply nested scalar field after the preceding UI operations crashed the
compiler during investigation. An isolated assignment immediately after App
construction compiles; the cause is not diagnosed. The working tests retain the
policy assertions; they do not skip that scenario. The reduced failing source is
`diagnostics/policy_assignment.mojo`, excluded from the passing gate command but
included in the source manifest. Run it with the same Mojo include flags as
`check.mojo` to investigate the compiler failure.

Not tested: independent windows/hosts, asynchronous callbacks, nested layout,
observation, invalidation efficiency, allocation/copy costs, native interaction,
or usability. Stale explicitly targeted events are injected at HandlerHost's
component boundary; ordinary editing/actions go through App.
