# Simple composition after production paint integration

The paint scan optimization is now in `src/moxi/column_runtime.mojo` on the
implementation branch. The authoring API remains an experiment. These are two
separate outcomes: runtime performance is verified more strongly than human
comfort.

Implementation evidence: `44b2396` integrates the runtime optimization;
`af3b547` records the simpler composition experiment and both timing runs.

## Production runtime evidence

Command identity lookups now use `(kind, id)` indexes; ancestor lookups and
scrollability facts are computed once per paint. Existing output order, clipping,
changed flags, and removed-region behavior are preserved. Extent computation
still scans descendants, so this is not a claim of linear overall complexity.

Validation passed: the complete 82-file test suite; independent paint regression
assertions on both old and new runtimes; ten differential paint frames against
frozen `247cad2`; and the existing native Metal/software structural replay
contract. The native test checks backend behavior, not pixel equality or native
latency. The full release/check workflow and manual native interaction were not
run for this slice.

Repeating the same equivalent-tree frame probe on production source gives
**3.935 ms cached / 4.349 ms forced** for a local edit at 100 editors, versus the
historical baseline **33.353 / 33.894 ms**. The baseline timing was not rerun in
this integration pass. At 300 editors, the new local cached frame is **30.664 ms**;
that remaining cost still warrants attention before broad scalability claims.
See `experiments/paint-costs/integration.json` for raw samples, source hashes,
compiler/machine information, and verification output.

## A simpler whole-application reference

The new `experiments/simple-composition/screen.mojo` keeps the previous workbench's
ordinary fields, methods, eight explicit routes, typed contexts, read-only
preview policy, and inspector generation guard. It imports the existing Editor
unchanged. One `render` method declares children, and the existing generic
`HandlerHost` handles updates. There are no per-child cache fields or repeated
refresh/compose/dispatch registrations and no new runtime abstraction or language.

The root/composition authoring slice falls from **131 to 85** counted code lines:
the old root is 60 and operational host 71; the new screen module is 85, including
its imports and conditional/reorder test options. This excludes unchanged panel
definitions, editor/domain, and shared runtime on both sides. Including old
benchmark counter methods would inflate the baseline to 150, so that is not the
headline comparison. Historical source fixtures remain in the repository and
the original root type remains unused in an imported comparison module; these
are active authoring counts, not repository-wide deletions.

The reusable runtime and bindings remain 281 + 78 counted lines; this candidate
does not use the extra 65-line Boundary module. The count method excludes blank
lines, comments, and docstrings and differs slightly from earlier reports.

## Acceptance tasks and their remaining ceremony

- Add a local field: **five lines, one file**, field/init/setter/input sites.
  No parent, route, cache, or runtime edits; sibling state stays independent.
- Add an editor: **seven lines, one file**, five sites: named key, owned field,
  initialization, route, and child declaration. No repeated host registrations.
- Add a shared setting: **seven lines, three files**, domain declaration/init,
  settings action/control, and editor display. All three consumers refresh;
  no root, routing, cache, or runtime edits.
- Insert a conditional sibling and reorder children while editing: IDs, focus,
  caret, selection, and IME state survive. This moves whole keyed children;
  arbitrary positional insertion *inside* Editor was not solved by this test.
- Remove/remount a child with an old callback/event retained: both are rejected
  by the existing visibility/generation policy. The policy is still explicit.

The experiment also passes 500 differential mixed transactions against the
previous forced typed workbench, with independent domain checks. It verifies
private drafts, conflicts/reload/undo, permission enforcement, read-only service
scope, direct mutations, and routing through a copied host's current root.

The new tree flattens controls into one column; the previous host adds component
surfaces. Comparison normalizes identity, geometry, parent identity, and their
accessibility counterparts, then checks every remaining non-container ViewNode
field. Paint executes but the two layouts/paint streams are not claimed equal.

## Timing and decision

With eight panes and empty history, median real update + paint is **0.068 ms**
for a simple local edit, versus **0.075 ms cached / 0.103 ms forced** in the typed
host. A shared commit is **0.067 / 0.095 / 0.104 ms**. With 10,000 history entries,
local costs are **0.072 / 0.336 / 0.158 ms**, and shared costs are
**0.062 / 0.130 / 0.137 ms**.

This is a whole-candidate comparison with different topology, not an isolated
cache ablation. O3, two warmups/five samples, rotating mode order, setup/checks/
destruction excluded; the other suite and compilation work had finished. These
are small headless CPU times on an unisolated machine. Raw samples and min/max
are in `experiments/simple-composition/results.json`. An earlier successful run
measured the empty-history local edit at 0.041/0.047/0.064 ms; its raw samples
and source hashes are preserved in `repeat-observation.json`. Only the
behavioral reorder check changed between runs. Absolute timing variance is
substantial, so a small local-edit speed advantage is not statistically
established. The stronger final check moves the actually focused editor while
IME composition is active and verifies that its geometry changes.

**High confidence:** make simple full-declaration composition the reference for
continued API work, and require selective optimizations to beat its complete
frame cost. Do not expose the repeated cache host as application architecture.

**Moderate confidence:** ordinary fields/direct methods can be a comfortable
default for this application shape. There are still eight routes, stable child
keys, and explicit remount policy. No unfamiliar-reader study establishes
comfort, and the user's Tags API standard has not been met by evidence.

The prototype retains inactive control slots and uses linear searches. Large
pane counts, long-running mount churn, nested ownership extensions, and whole
root/collection replacement are not validated by this test. The earlier stale
callback counterexample for replacing a complete keyed collection remains open.

The next useful gate is an unfamiliar-author task on this exact source: add a
pane and explain ownership, event routing, and lifetime without reading runtime
internals. Pair that with a bounded mount-churn/large-tree probe before adding
more API machinery. Stronger evidence of full declaration cost dominating a
representative workload, or persistent comprehension trouble, would change the
recommendation.

Reproduce with `python3 experiments/simple-composition/run.py`; preparation and
measurement can be separated using `--prepare` / `--measure <prepared.json>`.
Both source and binary hashes are checked before delayed measurement.


## Follow-up acceptance evaluation — 2026-10-31 UTC

The [composition acceptance evaluation](composition-acceptance.md) completes the
three proposed gates against `af3b547`, with experiment artifacts committed in
`c4f259d`. An unfamiliar smaller-model author succeeds at ordinary composition,
but the parent's held-out test exposes colliding mount-key ranges. An assisted
negative-key repair passes for the two siblings without solving general key
coordination. Whole-root/collection replacement retains semantic stale-delivery
counterexamples. At 1,000 minimal panes, update+paint is 21.327 ms; 1,000 remounts
with eight live panes leave 4,032 retained slots (32 active).

Keep the fields/methods reference; do not stabilize its current identity/lifetime
conventions unchanged. The next work is bounded identity/session and retained
storage/update-cost fixes, followed by these regressions and another author task.
The previous paragraphs remain the historical small-application assessment.
