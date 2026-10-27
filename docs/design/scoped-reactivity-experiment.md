# Scoped reactivity: experiment findings and practical shape

Status: experimental findings; no public API adoption or implementation priority
change. Recorded October 27, 2026.

Implementation inspected: `feat/data-workbench` at
[`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a),
plus the uncommitted `experiments/scoped-bindings/` directory. The experiments
are not in that commit or available through a hosted source link yet. The
unrelated working edits to `docs/API.md` and `docs/capability-bus-design.md`
were not part of the experiment. This record summarizes checks performed earlier
in this session; saving it did not rerun implementation tests.

## Decision and subsequent authoring assessment

Keep Moxi's explicit execution core and public API unchanged. Confidence is high
about correctness and work parity in the tested model. This evidence supports a
possible runtime mechanism; it does not establish an appealing authoring API or
decide whether a Tags API, template language, or compiler extension is worthwhile.
These findings do not supersede the active workbench-hardening gates.

The initial interpretation recommended another component-local tracking
experiment in ordinary Mojo. Subsequent discussion identified that recommendation
as premature for the motivating question: the explicit read context and
subscription plumbing miss the desired authoring comfort. The
[authoring comparison](authoring-comfort-experiment.md) now examines complete
Marko and proposed Moxi components before choosing a runtime mechanism. It leaves
new syntax open for evaluation rather than treating ordinary Mojo as a prior
constraint. This revises the design recommendation, not the measured results.

The author subsequently found both proposed surfaces confusing. The provisional
preference for the declarative sketch has been withdrawn; no replacement surface
has earned adoption. The comparison now records that feedback and a simpler
Marko reference for the desired experience. Confidence in a replacement remains
low until realistic changes can be understood without exposing more machinery.
No authoring usability or native end-to-end advantage has been established.

The motivating Marko idea is keeping dependencies consistent with expressions.
Marko itself discovers the graph at compile time; this experiment collects
reads at runtime and does not measure Marko's implementation. Official context:
[reactivity](https://markojs.com/docs/reference/reactivity) and
[targeted compilation](https://markojs.com/docs/explanation/targeted-compilation).

## Evidence from the two probes

The first probe compared root invalidation, explicit scoped invalidation, and a
text-binding helper. One editor fed a greeting and character count beside 1,
100, or 1,000 independent rows. All three used real text editing, child views,
parent layout, retained reconciliation, and paint-command generation.

For 100 edits beside 1,000 rows, explicit scoping and the binding helper both
eliminated 100 sibling rebuilds. Layout inputs fell from 200,800 to 100,800,
while all modes still reconciled 100,500 parent nodes and generated 100,700
paint commands, of which 202 changed. Explicit and binding work matched at
every sibling count. The helper shortened one edit/invalidate sequence but left
the dependency declarations unchanged. This did not test dependency inference
or establish a timing benefit.

The stronger probe used four sources and five consumers, including a
branch-selected name, shared nested greeting/count helpers, a removable detail
consumer, and an independent consumer with 100 static rows. It compared
conservative explicit unions, precise explicit branch dependencies, tracked
reads, and an independent full-recompute oracle.

| Variant | Evaluations | Parent frames | Nodes reconciled | Tracked reads | Subscription rewrites |
| --- | ---: | ---: | ---: | ---: | ---: |
| Explicit union | 2,044 | 819 | 89,314 | 0 | 125 |
| Explicit precise | 1,639 | 736 | 80,316 | 0 | 371 |
| Tracked | 1,639 | 736 | 80,316 | 3,824 | 371 |
| Full recompute | 4,633 | 1,008 | 109,942 | 0 | 0 |

All 1,008 checked transactions passed output parity, including branches,
batching, unchanged writes, Unicode, removal while dirty, hidden edits, and
consumer recreation. Tracked dependencies matched precise manual masks and
evaluation/frame counts at every flush. Subscriptions remained bounded.
An intentionally omitted explicit dependency produced stale output as expected;
this demonstrates test sensitivity, not a developer error rate.

Compared with conservative wiring, tracking saved 19.8% of evaluations and
10.1% of frames. Precise manual wiring achieved the same savings. All three
incremental variants rebuilt the independent consumer 123 times.

Nine warmed, order-rotated headless samples, each with a separate 1,000-action
trace, gave median times of 384.9 ms for the union control, 343.3 ms for precise
manual wiring, and 343.6 ms for tracking. Observed ranges were 379.8–397.1,
339.5–384.4, and 340.8–375.0 ms respectively. Mount and compilation were
excluded; instrumentation and the graph adapter were included. The final run
had no other agent-started build/test running. The roughly 0.1% precise/tracked
median difference is below sample variation. These timings cannot resolve
tracking overhead or support a native rendering claim.

## What this looks like in practice

This is the actual experimental helper shape, not an existing public Moxi API:

```mojo
def selected[tracked: Bool](mut reads: Reads[tracked], values: List[String]) -> String:
    if reads.read(values, SELECTOR) == "alternate":
        return reads.read(values, ALTERNATE)
    return reads.read(values, PRIMARY)

def greeting[tracked: Bool](mut reads: Reads[tracked], values: List[String]) -> String:
    return String("Hello, ", selected(reads, values))
```

The owning driver starts a fresh read collector, computes the greeting, and
installs its collected dependencies. This illustrative greeting-only build
uses methods and types from the experiment:

```mojo
var reads = Reads[True]()
var text = greeting(reads, self.values)
self.replace_dependencies(GREETING, reads.mask)
self.views[GREETING] = leaf(GREETING, text)
```

With the primary name selected, the greeting subscribes to `SELECTOR` and
`PRIMARY`. Editing an unselected alternate name does not rebuild the greeting.
Changing the selector schedules it; its next build reads `ALTERNATE` and replaces
the primary subscription with the alternate subscription. Several writes before
flush coalesce. Source reads see new values immediately; cached derived output
settles on flush. Removing a consumer drops its subscriptions and pending dirty
entry; recreation builds from current source state.

The precise explicit alternative maintains a second rule beside the expression:

```mojo
var source = PRIMARY
if values[SELECTOR] == "alternate":
    source = ALTERNATE
return (1 << SELECTOR) | (1 << source)
```

Tracking removes that rule. It still requires an explicit read context through
helpers and explicit state ownership, writes, scheduling, and lifecycle
boundaries. The conservative explicit alternative can avoid branch rewiring by
subscribing to both names, at the cost of the measured extra rebuilds.

## Boundaries and next useful evidence

The existing execution graph supports adding dependencies, but no replacement
or removal method. The experimental adapter filters the edge list and rebuilds
the fanout index. Both precise variants use it: 371 rewrites and 2,795 filtering
edge visits each, versus 125 and 1,313 for the union variant. These visits exclude
the index's internal rebuild work. Tracking also records 3,824 reads. The fixed
four-source bit mask is not a general scalable dependency representation.

Raw `values[...]` access can bypass tracking. Source scopes are never removed,
and hidden consumer slots retain their cached views; arbitrary resource
destruction and lifetime safety are not established. Full parent composition,
layout, and reconciliation remain on every emitted frame. The probe does not
memoize shared derived nodes or implement effects.

The originally proposed next slice compared an existing component's explicit and
tracked implementations through a source-selection feature change and consumer
removal. That slice remains unimplemented and is deferred behind the
[authoring comparison](authoring-comfort-experiment.md). If tracking is pursued
later, its validation still needs independent output parity, fresh remount state,
resource cleanup, bounded subscriptions, concrete before/after authoring changes,
and measured native costs. Reject or revise the approach if plumbing outweighs
removed wiring or dependency bypass remains easy. The authoring experiment is
allowed to explore new syntax; it does not authorize implementing a compiler,
general signal registry, or hidden effect scheduler.

## Reproduction and provenance

Run from the implementation checkout with pinned Mojo 1.1.0 (`8189361e`):

```sh
pixi run --locked mojo run -I src experiments/scoped-bindings/probe.mojo
pixi run --locked mojo run -I src experiments/scoped-bindings/dependencies.mojo
pixi run --locked mojo run -I src tests/execution.mojo
```

Both probes and the existing localized-execution/keyed-subtree scheduling tests
passed in the session. Full details and raw artifacts remain beside the
experimental code: `README.md`, `DEPENDENCIES.md`, `results.csv`,
`dependency-results.csv`, and `dependency-timings.csv` under
`experiments/scoped-bindings/`. They remain uncommitted at capture time; do not
describe the base revision as containing the experiments.

SHA-256 identities for the stronger probe and its result artifacts:

- `dependencies.mojo`: `a807c0e505b91968e84b7667f59f22ebcac29f8eeb51c86743b6784b6c53ff3c`
- `dependency-results.csv`: `60ce854de85f8fb334a9dadd6e13d671328e352b918c54c7812c443629e8dab2`
- `dependency-timings.csv`: `924d685eb41e3058bed3a8a1facd98b9b6adee36a40f0430c82d7cc70b20dd64`

Skipped: the full repository suite, native rendering, App event routing, focus
and complete IME integration, content-sized layout, asynchronous effects,
source-scope disposal, arbitrary resource destruction, allocations,
multi-threading, and compiler inference. The original editor probe checks some
text-edit behavior separately; it is not integrated with the read collector.
