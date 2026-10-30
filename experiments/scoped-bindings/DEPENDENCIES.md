# Dependency experiment

The first probe left dependency declarations unchanged. This follow-up tests
whether deriving dependencies from reads is useful enough to pursue in Moxi.
It is an executable experiment, not a proposed public API.

```sh
pixi run --locked mojo run -I src experiments/scoped-bindings/dependencies.mojo
```

## Decision and controls

The decision is whether to pursue automatic dependency wiring, and whether that
requires a template language. The gates are correctness against full
recomputation, work parity with precise manual dependencies, no accumulated
subscriptions across removal/recreation, and an honest accounting of the
tracking and lifecycle machinery. Timing is supporting evidence for this
headless workload, not a native frame-rate claim.

Four sources feed five independently built consumers. A selector chooses a
primary or alternate name. Greeting, character count, and summary consumers use
nested helpers to derive their outputs; summary calls both shared helpers.
A detail consumer reads the alternate name and can be removed and recreated.
An independent consumer reads a fourth source and includes 100 static rows.

Three variants execute the same expressions:

- `explicit_union` declares both branches' possible sources. This is the simple,
  correct control that requires no subscription changes when switching branches.
- `explicit_precise` declares only the selected branch's sources and manually
  updates those declarations after building. Its dependency helper is shared
  across consumers, rather than duplicating all wiring at each call site.
- `tracked` collects a deduplicated read mask while executing the helpers and
  replaces each consumer's subscriptions after it builds.

A separate full-recompute oracle bypasses the read helpers and dependency
declarations. Every checked transaction compares actual Moxi paint-command
content and geometry against that oracle. Frames skipped by an optimized variant
retain their previous change flags, so those flags are not compared across
different frame histories.

All variants use `LocalizedExecution`, real child views, parent layout,
`ColumnRuntime.reconcile()`, and paint-command generation. All emitted frames
still compose and reconcile the entire parent. Subscription tracking does not
remove that remaining work.

## Authoring and lifecycle costs

The tracked expression is ordinary Mojo control flow with explicit reads:

```mojo
def selected[tracked: Bool](mut reads: Reads[tracked], values: List[String]) -> String:
    if reads.read(values, SELECTOR) == "alternate":
        return reads.read(values, ALTERNATE)
    return reads.read(values, PRIMARY)
```

The precise explicit version also needs this separate dependency rule:

```mojo
var source = PRIMARY
if values[SELECTOR] == "alternate":
    source = ALTERNATE
return (1 << SELECTOR) | (1 << source)
```

Tracking removes the second rule, but requires passing the read context through
helpers. The probe avoids globals, erased callbacks, borrowed state pointers,
and duplicate source-state storage. Raw reads through `values[...]` can still
bypass tracking; this implementation cannot enforce complete dependencies.
The explicit variants share the context-shaped evaluation functions with
tracking compiled out for a controlled comparison. That does not establish that
tracking makes a normal explicit Moxi application shorter.

`LocalizedExecution` currently exposes addition of scopes/dependencies, with no
dependency replacement/removal method. This experiment's adapter filters its
edge list and rebuilds its fanout index. Both precise variants use that same
adapter. Removing a consumer drops its edges and pending dirty entry; recreation
builds from current state and installs fresh edges. Source scopes themselves are
never removed. This is consumer-subscription cleanup, not general scope disposal,
source-handle lifetime safety, or full keyed-component state preservation.
The fixed consumer slots also keep their cached views allocated while hidden;
this does not test destruction of arbitrary component-owned resources.

The adapter's edge-visit counter counts only its explicit filtering loop. It
excludes internal fanout-index rebuilding work and is not a total complexity or
allocation measurement. The fixed four-source bit mask is deliberately small;
it is not a scalable general dependency representation.

## Verification

Checks cover an inactive branch, switching away from a source, several writes
before a flush, unchanged writes, Unicode, independent-source changes, removal
while dirty, hidden-source changes, recreation with fresh output, and a seeded
1,000-action mixed trace. At each flush the tracked variant must match precise
manual evaluation/frame counts and dependency masks. Its edge count must remain
bounded across repeated consumer removal/recreation.

An intentionally omitted alternate-source edge in an explicit variant must
produce stale output. This checks that the test can detect the targeted failure;
it does not measure how often developers make such mistakes or prove that raw
reads cannot cause the same failure with tracking.

Timing uses the same mixed-action generator, excludes mount and compilation,
warms all three specializations, and rotates their order over nine samples.
Each sample executes 1,000 transactions without the per-transaction oracle.
The timed path includes the experiment's work counters and graph adapter.
Final strings are checked after the timer stops. Timings are local observations,
with no cross-machine or native-rendering generalization.

## Observed result

The October 27, 2026 run with the pinned Mojo 1.1.0 (`8189361e`) passed all
1,008 checked transactions, including the deliberately faulty wiring check.
The existing `tests/execution.mojo` tests also passed. No production source was
changed. Raw counters are in [dependency-results.csv](dependency-results.csv).

| Variant | Consumer evaluations | Parent frames | Nodes reconciled | Tracked reads | Subscription rewrites |
| --- | ---: | ---: | ---: | ---: | ---: |
| Explicit union | 2,044 | 819 | 89,314 | 0 | 125 |
| Explicit precise | 1,639 | 736 | 80,316 | 0 | 371 |
| Tracked | 1,639 | 736 | 80,316 | 3,824 | 371 |
| Full recompute | 4,633 | 1,008 | 109,942 | 0 | 0 |

Tracked reads saved 19.8% of consumer evaluations and 10.1% of parent frames
against conservative explicit wiring. Precise manual wiring achieved exactly
the same savings. All three incremental variants rebuilt the independent
consumer 123 times; tracking did not save any additional independent work.

The precise variants each performed 2,795 explicit adapter edge visits, versus
1,313 for the union variant. They visited 2,154 dependency edges during source
invalidation, versus 3,027 for the union variant. Tracking's benefit is avoiding
a separate dependency rule, not doing less work than that precise rule.

The final timing capture ran the compiled binary with no other agent-started
test or build running. Its 1,000-action trace excludes the eight hand-written
checks included in the work table. [Nine samples](dependency-timings.csv) gave:

| Variant | Median per 1,000 transactions | Observed range |
| --- | ---: | ---: |
| Explicit union | 384.9 ms | 379.8–397.1 ms |
| Explicit precise | 343.3 ms | 339.5–384.4 ms |
| Tracked | 343.6 ms | 340.8–375.0 ms |

The precise and tracked medians differ by about 0.1%, much less than sample
variation. This run cannot resolve the cost of read instrumentation; parent
work dominates this small graph. It supplies no evidence that tracking is faster
than precise manual dependencies. The roughly 11% lower tracked median versus
the union control is workload-specific evidence for precise scheduling, not a
general performance claim about a binding API.

## Relationship to Marko

Marko discovers its reactive graph at compile time and generates targeted client
updates. Its scheduling also distinguishes immediate source writes from derived
output that settles on flush. See the official [reactivity reference](https://markojs.com/docs/reference/reactivity)
and [targeted compilation explanation](https://markojs.com/docs/explanation/targeted-compilation).

This runtime read collector tests one authoring benefit associated with that
model: keeping dependencies consistent with expressions. Its tracking and
graph-rewrite costs are not measurements of Marko. It does not compile templates,
infer arbitrary Mojo reads, target retained properties directly, implement
derived-node memoization or effects, or reproduce Marko's scheduling.

## Decision

Keep Moxi's explicit execution core and public API unchanged. This probe supports
automatic dependency collection as an optional, component-local experiment:
it can remove a separate dependency rule while preserving precise scheduling
through ordinary Mojo helpers. It does not establish a need for tags, a template
language, or a compiler extension. Those decisions have different costs and
would need their own authoring and tooling evidence.

Confidence is high about correctness and work parity in the tested model, and
medium about the broader design recommendation. The strongest evidence that
would change the recommendation is a port of an existing stateful Moxi component
that demonstrates less coordination across actual feature changes, complete
resource cleanup, and acceptable native end-to-end costs. A tracker that requires
pervasive context plumbing or permits easy accidental raw reads could erase its
authoring benefit even when this workload passes.

Skipped: the full repository suite, native rendering, App event routing, focus
and IME integration, content-sized layout, asynchronous effects, source-scope
disposal, arbitrary resource destruction, allocation profiling, multi-threading,
and compiler inference. The original editor probe covers some text-edit behavior
separately; it is not integrated with this dependency collector.
