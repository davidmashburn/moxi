# Paint cost isolation with equivalent retained trees

This October 30 follow-up keeps the authoring source unchanged and isolates
runtime work before making another API decision. The previous research is
committed as `022209f` on `feat/data-workbench`; its planning record is committed
as `39814af` on `project-planning`. This follow-up is committed as `247cad2` under
`experiments/paint-costs` and is still experimental.

## Question and contract

The preceding adapters produced different retained trees. Their timing could
not separate declaration caching from composition overhead. Here both modes use
exactly the same `SelectiveHost`, retained tree, owned services snapshots and
routing. One compares the whole shared context before deciding what to rebuild;
the other forces every editor declaration to rebuild. Application fields,
methods and render functions are unchanged.

The local event edits the final editor's draft. The shared event applies that
edit to the document through an explicitly targeted `ActionEvent`, not a pointer
click. Every timed pair checks expected domain effects, all logical root values,
retained nodes and root layout, paint command fields, changed flags, dirty
bounds and removed regions. Setup, validation and destruction are outside the
timer. Update and paint are measured consecutively within one actual frame.

Four disposable source trees isolate two groups of paint scans:

- Baseline: the exact production runtime.
- Command index: replace prior-command searches and removal membership scans
  with `(kind, id)` lookups, preserving first-match behavior and removal order.
- Paint facts: calculate overflow once per root/container and index parent
  lookup, preserving ancestor traversal and clipping order.
- Combined: apply both changes.

No production file is modified. Container overflow preparation still scans the
widgets once per container; this is not a fully linear paint implementation.

## Measured result

The frozen-input run passed all 120 measured pairs (240 timed frames), with
159 input hashes unchanged. Mojo 1.1.0 (`8189361e`), macOS ARM64, `-O3`.
Medians and observed ranges for 100 editors:

| Paint variant | Cached local frame, ms | Forced local frame, ms |
| --- | ---: | ---: |
| baseline | 33.353 (33.260–34.656) | 33.894 (33.715–38.680) |
| commands | 27.229 (26.850–28.092) | 27.493 (27.007–31.317) |
| facts | 10.264 (10.208–10.347) | 10.705 (10.676–11.000) |
| combined | 4.072 (3.966–4.170) | 4.415 (4.373–4.560) |

The combined variant reduces the cached local frame by about 88% (8.2×),
without altering application code or retained topology. Its median paint stage
falls from 30.632 ms to 1.411 ms; update remains about 2.6–2.7 ms. Stage medians
need not sum to the frame median. The two interventions are measured separately:
the overflow/parent group is the larger contributor in this workload, but the
experiment does not isolate overflow calculation from parent lookup individually.

On the combined runtime, caching one editor instead of declaring all 100 saves
about 0.34 ms, or 7.8% of the forced frame median. The shared operation rebuilds
all editors in both modes and takes 4.329/4.319 ms: that tiny difference supports
no practical winner. At 300 editors, cached/forced local frames are
30.898/31.761 ms, down from 295.500/300.973 ms on the baseline. Substantial
scaling costs remain; neither the update path nor container extent preparation
is established as linear. At two editors, local cached/forced medians are 0.058/0.065 ms on the
baseline and 0.019/0.022 ms combined. These tiny timings and fixed variant order
do not establish a reliable small-tree speed ratio; raw ranges remain in
`results.json`.

This establishes a local runtime bottleneck and a modest same-tree benefit from
selectivity with small shared state. It does not overturn the previous
large-history counterexample. The exact speed ratios are diagnostic estimates,
not portable performance guarantees.

## Verification and interpretation

The run uses Mojo `-O3`, two warmups and five samples per case, 2/100/300 fully composed
editors, and alternating cached/forced execution order. Variants execute in
fixed order on an unisolated machine. The tall viewport does not test list
virtualization; these are headless CPU timings, not native display latency.

All ten verification programs passed. The source audit verified 159 unchanged
inputs, exact generated runtimes, and raw-sample summary recomputation. Three
original-versus-candidate runs each replay ten frames; five existing runtime
checks pass on the combined variant, as does the 500-transaction typed-boundary
workbench and a separate baseline equality probe. Verification programs use
`mojo run`; timed binaries use `mojo build -O3`. The first timing attempt was
discarded when a fixture changed during measurement; only the frozen-input
rerun is reported.

The original-versus-candidate fixture exercises empty/idle frames, edits,
reorder, removal/re-addition, focus/hover/press, selection/composition, nested
clipping and scrolling, component surfaces, resized bounds, and panel/scrollbar
commands sharing an ID. Existing runtime checks and the heterogeneous workbench
provide additional bounded regression evidence.

The existing large-history counterexample remains applicable: reducing paint
cost cannot make broad context comparison free. Likewise, a paint optimization
cannot resolve author-visible routing, lifetime or identity ceremony.

The separate passing probe establishes an equality boundary: two logically equal
applications with independently owned `List[Entry[Editor]]` storage compare
unequal through the generic reflection helper, even when each entry compares
equal. This establishes false invalidation for that collection,
not stale UI output. Automatic whole-value comparison needs a defined collection
equality contract before it can be treated as general infrastructure.

Native renderer/GPU latency, allocation profiles, async behavior, arbitrary
aliases/custom equality, the full repository suite, and human authoring comfort
are outside this bounded experiment.

## Decision and next bounded step

**High confidence:** prioritize the demonstrated runtime scans before adding
reactivity complexity to the public API. The equivalent-tree experiment removes
the earlier topology confound, both runtime interventions preserve tested paint
behavior, and the larger gain requires no application changes. Exact timing
ratios have lower confidence outside this machine and workload.

Keep ordinary fields/methods and current-state command dispatch. Keep selective
declarations optional or internal until they demonstrate a full-frame benefit
and a defined value-comparison contract. This run supports a small-context local
benefit; it does not establish universally cheap automatic change detection.

The next implementation slice should turn these temporary optimizations into a
reviewable production change with the repository's required validation, then
rerun equivalent workloads including small trees. Do not generalize the
remaining quadratic extent computation as part of that first slice without
separate evidence. The next authoring experiment should move routing and
lifetime machinery into normal retained composition, preserving the existing
editor source and explicitly testing conditional identity and collection
extension. It should not ask authors to supply field dependency lists.

**Moderate confidence:** that separation can preserve a comfortable API while
allowing useful internal selectivity. Comfort remains unmeasured. This priority
would change if representative native workloads failed to retain the runtime
benefit, or if compiled composition examples showed that ordinary fields and
methods require pervasive manual invalidation or identity wiring.

Reproduce with `python3 experiments/paint-costs/run.py`, then
`python3 experiments/paint-costs/verify.py`, on implementation `247cad2`. Its `results.json` retains raw samples, patches, compiler
and machine details, and source hashes; `verification.json` retains check output
and links verification to that report by hash. The user authorized publishing both the implementation research and planning
branches after reviewing these results.

The [compact comparison](paint-cost-isolation.html) shows the 100-editor result.

## Where performance and authoring comfort stand

Performance has stronger evidence than universal comfort. The latest gain is
confined to disposable runtime copies; it has not shipped in production Moxi.
It buys room to choose a straightforward authoring model without treating every
avoided declaration as essential. It does not establish fast scaling for all
applications: 300 fully composed editors still take about 31 ms in this probe,
and large-context equality has an independent performance counterexample.

Leaf authoring has measurable improvements. In the earlier direct-method
comparison, the editor fell from 57 to 37 nonblank, noncomment lines; eight
per-action adapters became zero; adding a local field fell from nine lines to
five, with parent routing unchanged. The complete application/domain total fell
from 153 to 134 lines. Those counts compare that earlier pair, not the present
heterogeneous workbench. A local field still needs declaration, initialization,
a setter and an input call. This is ordinary Mojo, but not yet the concision of
a direct two-way template binding.

The complexity moved partly into reusable framework code: that earlier runtime
grew from 261 to 359 counted lines, making the combined app/runtime total grow
from 414 to 493. Shorter application code is a useful gain when the runtime
contract is predictable and reusable, but it does not mean less total code or
less implementation risk.

Whole-application composition is the weakest front. The typed workbench repeats
eight boundary types, construction, refresh, compose and dispatch calls, plus
eight routes and an inspector lifetime policy. Conditional control insertion
requires explicit identity scope. Typed contexts help make state access clear,
but they neither infer dependencies nor remove this mounting machinery. The
current experimental host should not be adopted as the public API.

**High confidence:** preserve the ordinary leaf model and centralize repeated
routing/lifetime mechanics. **Moderate confidence:** it can become comfortable
across larger applications without another authoring language. **Low confidence:**
it is universally easy or as comfortable as the user's Tags API reference;
no independent comprehension exercise establishes that claim.

After the production performance slice, evaluate one integrated composition
example with explicit before/after application and runtime counts. Use five
changes as acceptance tasks: add a field, add another editor, introduce a shared
setting, insert/reorder conditional UI while editing, and remove/remount a child
with an old event still retained. Preserve correctness and measured frame cost;
count distinct concepts and edit locations as well as lines. Adding a field
should leave cache/routing code untouched. Adding a child should not require
repeating its registration through several host methods. An unfamiliar reader
should be able to predict state ownership, update behavior and lifetime without
reading runtime internals. Failure on those tasks would weaken the comfort
recommendation even if the resulting source is shorter.
