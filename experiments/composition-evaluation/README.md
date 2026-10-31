# Composition acceptance evaluation

Evaluate the existing simple-composition candidate at implementation baseline
`af3b547`, without changing its API or production runtime. The intended outcome
is a bounded decision about experimental adoption, separate from whole-branch
merge readiness and the failing locked-environment CI setup.

The three gates are:

1. An unfamiliar smaller-model author adds an editable pane, shared context,
   and a hide/remount policy, preserving its first implementation before feedback.
   The parent reviews the explanation and independently verifies behavior.
2. A bounded large-tree and mount-churn probe measures real update/paint work,
   retained control counts, and surviving editing state. Preparation and timing
   are separate so compiler activity does not overlap measurement.
3. Replacement probes distinguish same-owner updates from new owner lifetimes,
   and test retained actions and queued events independently.

Source of truth: `../simple-composition/screen.mojo`, the unchanged Editor and
domain in `../state-access`, and `../method-binding/runtime.mojo` and
`bindings.mojo`. Results are scoped to this prototype. A model author is not a
human usability study; headless CPU measurements are not native latency.

No production edits, API redesign, merge, or branch integration is included in
these evaluations. Unrelated documentation edits remain untouched. Conclusions
and remaining gates will be recorded here and on the existing planning branch.


## Decision after the author and lifetime checks

Keep ordinary owned fields, direct methods, and typed shared contexts as the
reference authoring model. **Moderate confidence** that this is comfortable for
routine additions: one example-assisted GPT-5.6-Luna author at maximum reasoning
added the requested pane without implementation corrections or runtime-internals
reading. This is not an independent human usability study or a comparison with
Marko, Solid, or another syntax.

Do **not** call the current identity/lifetime conventions a production-ready,
universally easy contract. **High confidence** in that narrower conclusion:
the independent collision test fails, and whole-owner replacement has executable
counterexamples. These are concrete engineering gates, not a reason to reopen
the entire framework-pattern inventory.

## Unfamiliar author and assisted repair

The author read the existing simple screen, Editor/domain, and pane definitions;
saved `author/attempt1.mojo` before compiler/test feedback; and then inspected
existing probe/build helpers to write checks. `author/screen.mojo` remains byte
identical to the first attempt. The task added a third editor with private state,
shared settings/document, hide/show, discard-on-hide, and stale delivery rejection.

The ordinary checks pass. The root/composition source grows from **85 to 108 code
lines** (blank lines, comments, and docstrings excluded). This dynamic child has
more lifetime responsibilities than the earlier seven-line static-child task;
the counts should not be treated as the same operation.

The parent-held-out `author_collision.mojo` mounts the new pane and then performs
101 actual inspector hide/show cycles. The new pane's `200 + epoch` and the
inspector's `100 + epoch` both reach key 202. Rendering aborts with
`duplicate identity: /k3:202`. The author copied the baseline's identity idiom,
so this is evidence against the example convention as well as a missed test.

In a second, explicitly assisted round, the same smaller model used negative
third-pane generations. `author-repair/attempt1.mojo` preserves that repair before
feedback. Parent verification passes its ordinary and 110-remount checks and the
unchanged held-out test. Source length remains 108 code lines. The repair is
adequate for these two counters within the integer range; it is not a general
compositional naming scheme. Future dynamic siblings still require key-space
coordination, and the repair author read identity and binding internals.

The first explanation identified ownership, routing, and explicit reset policy.
It initially described draft/note as private until Apply; the note actually stays
private even after Apply. Its final explanation correctly says only Apply reaches
the shared document. Its check history also records locator and expectation
corrections. Worker prose is preserved as a study artifact; the parent's verified
outcomes in `author-results.json` take precedence over broader worker claims.

## Replacement is a separate lifetime decision

`replacement.mojo` checks retained Action descriptors and old targeted Events
separately. Six observations are asserted in `replacement-results.json`:

- Same-owner field update: both old deliveries still work, as intended.
- Remove/append through the same Keyed allocator: both are rejected.
- Replace the collection with a new Keyed allocator that restarts keys: both
  reach the replacement child.
- Replace the root with its initial generation: both reach the replacement.
- Replace the root with a fresh externally supplied generation, retaining the
  HandlerHost: both are rejected and a fresh event still works.
- Construct a new HandlerHost with a fresh model generation: the old descriptor
  is rejected, but a deliberately injected old Event hits the reused control ID.

The three counterexamples concern the intended **new-lifetime** interpretation.
Assignment can instead mean a same-logical-owner update; the API currently does
not choose that semantic policy for the application. Current-owner routing avoids
capturing an obsolete object address, but does not by itself prevent semantic
retargeting. The last test is synthetic cross-host delivery, not evidence that a
native host actually forwards old queued events into a new session. A host/session
boundary must either prevent that forwarding or distinguish the event's session.

The initial fixture crashed Mojo 1.1.0 when assigning a new Keyed value through
`app.component.root.children`. Moving the same assignment into an ordinary owner
method compiled; root replacement similarly uses a small `mut Root` helper.
No runtime change was needed. The original compiler crash was not diagnosed or
reported upstream and is not counted as a Moxi runtime failure.

## Large trees and mount churn

Prepared and measured on macOS arm64 with Mojo 1.1.0, O3, two warmups and five
samples. Each pane owns one text field and click count, and declares a text-input
label, input, and button. Four retained slots include the child scope. These are
minimal panes, not the earlier full Editor workload. The column uses a 960 by
20,000 logical viewport; this is a declared-tree measurement, not a promise that
all controls fit on a physical screen. No native renderer is timed.

Median real App.update followed by App.paint (paired sample sums):

- 10 children: **0.041 ms** (sample range 0.039–0.044).
- 100 children: **0.496 ms** (0.493–0.534).
- 300 children: **2.493 ms** (2.474–2.538).
- 1,000 children: **21.327 ms** (21.128–22.352).

At 1,000, median update is 20.493 ms and paint is 0.834 ms. Across these samples,
update dominates and grows faster than the child count. HandlerHost regenerates
all declarations; RetainedUI.claim/index and other runtime paths scan lists.
This probe does not isolate those contributions or establish a universal
complexity law. It does establish that the current default does not retain its
small-tree cost at 1,000 minimal panes. Earlier production paint improvements
are useful but do not eliminate this update cost.

For churn, eight children remain alive. After 0/100/1,000 hide-and-remount cycles,
there are **32/432/4,032 total retained slots**, always **32 active**, with next IDs
33/433/4,033. Retired controls clear actions/editor payloads but keep their slot
records; these counts are not a memory-byte measurement. The existing prototype
never removes those records.

Median accumulated update+paint work for 100 cycles is **5.340 ms**, and for
1,000 cycles **92.945 ms** (range 92.485–133.954). Each cycle includes a hide frame
and a remount frame; setup and test assertions outside the measured intervals are
excluded. These are batch totals, not single-frame latency or final-state update
costs. Normalized per cycle they are 0.0534 and 0.0929 ms, but variation and the
changing retained history preclude a precise long-run projection. The zero-cycle
row is an empty-batch control, not a measured zero-cost frame.

Correctness passes 10/100/300/1,000 children and 0/1/100/1,000 churn cycles. The
churn check preserves a surviving editor's focus, text, caret/anchor, composition
text, and composition selection range. It rejects old events and verifies that a
retained callback cannot mutate the freshly mounted child. It does not exercise
a nonempty ordinary selection range, every child position, or every input type.
The parent extended the worker's correctness run from 100 to 1,000 cycles and
expanded source hashing to include src plus the environment manifest/lock before
rebuilding and measuring. All compilers and child tasks had finished before
measurement; the machine itself was not otherwise isolated.

`scale/prepared.json` contains correctness output, source/binary hashes, exact
builds and environment; `scale/results.json` contains all 35 samples. The parent
independently checked the source hashes and recomputed the timing medians.

## Adoption gates

1. Specify and enforce collision-free sibling identity plus mount lifetime without
   application-authored integer ranges. Keep the first-attempt failure as a
   regression. A namespaced identity or host-owned allocator may satisfy this;
   this evaluation does not select or introduce a new public abstraction.
2. Specify same-owner replacement versus new lifetime, including collection/root
   resets and the host event-session boundary. Preserve ordinary field/method
   ergonomics and verify both descriptor and event behavior.
3. Bound retained-slot storage and remove avoidable scans as scale evidence
   warrants. Reclamation must preserve active editor state and reject old IDs;
   simply recycling integers would reintroduce the lifetime problem.

A corrected implementation passing these regressions, followed by another
unfamiliar-author task that does not require key-space coordination, would raise
confidence. More framework surveys would not resolve these observed failures.
The production paint optimization remains a separate merge decision from
stabilizing this experimental HandlerHost authoring API.

## Reproduction and limits

```sh
python3 experiments/composition-evaluation/run_author.py
python3 experiments/composition-evaluation/run_replacement.py
python3 experiments/composition-evaluation/scale/run.py --prepare
# Run after compilation and other experiment work finish:
python3 experiments/composition-evaluation/scale/run.py --measure experiments/composition-evaluation/scale/prepared.json
```

The author runner expects the frozen original's held-out failure. The replacement
runner expects its explicitly unsafe observations. Successful runners therefore
mean characterization matches the recorded evidence, not that every safety gate
passes. Generated JSON preserves commands, inputs, hashes, observations, and
local log paths; temporary binaries can be rebuilt with `--prepare`.

Production code and API are unchanged. The full repository suite, new CI runs,
main-branch integration, native event-queue behavior, native latency/pixel output,
human usability, integer exhaustion, and broader authoring tasks were not tested
in this evaluation. Previously reported production-suite/paint results are
inherited evidence, not rerun here. No merge or branch integration was performed.
