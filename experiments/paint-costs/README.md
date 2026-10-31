# Paint cost isolation

Research contract, October 30, 2026. Implementation baseline: `022209f` on
`feat/data-workbench`. The preceding research found selective adapters slower
than a handler with a different retained tree. This experiment separates
runtime work from the declaration strategy before choosing an API direction.

Keep the ordinary editor, application, retained topology, routing, domain
commands, and production source unchanged. Compare `SelectiveHost[AllInputs]`
with the identical host using `ForcedInputs`: the same owned services snapshot,
but every handled action rebuilds all editor declarations. The local operation
renders one versus all editors; the shared operation renders all in both modes.
Neither mode silently narrows its dependencies.

`python3 experiments/paint-costs/run.py` generates disposable source trees and
builds four variants with Mojo `-O3`:

| Variant | Intervention confined to `ColumnRuntime.paint` |
| --- | --- |
| baseline | Exact original runtime |
| commands | Index prior commands by `(kind, id)` and current membership for removal detection |
| facts | Compute root/container overflow once per paint; index parent lookup |
| combined | Both interventions |

The command index preserves the original first-match rule. Removal order and
ancestor clipping order stay unchanged. Container overflow preparation still
scans the tree once per container: this is a bounded ablation, not a claim of a
fully linear paint algorithm. The generator asserts its replacement sites and
saves each exact patch and runtime hash with the results.

Each variant runs 2, 100 and 300 fully composed editors in a tall viewport,
with two warmups and five samples for local text input and a shared Apply
action. Cached/forced order alternates. The timer splits actual `App.update`
and `App.paint` within the same frame, so their sum is the measured frame.
Setup, validation and destruction are outside the timer. These are elapsed
times for headless CPU work, not native/GPU/display latency. Variants run in
fixed order on an unisolated machine; small differences need cautious reading.

Every timed pair checks the complete root state, retained nodes, root layout,
paint command fields, changed flags and dirty/removed metadata. Expected-state
checks independently establish the draft edit and shared commit. A separate
original-versus-candidate runtime fixture exercises painting across structural
changes; its coverage and results are recorded after execution.

Acceptance: identify a reproducible runtime cost with equivalent output, report
whether selective declarations help with the same topology, and retain the
large-history comparison caveat. No new public API, compiler integration,
production runtime fix, automatic read tracking, or usability claim is in scope.

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

`python3 experiments/paint-costs/verify.py` passed 10 programs and audited all
159 source hashes, generated runtime hashes, raw samples and recomputed
summaries. `verification.json` records commands, output and fixture hashes:

- Three original-versus-candidate comparisons, each replaying ten frames:
  empty/idle, edit, reorder, removal/re-addition, focus/hover/press,
  selection/composition, nested clipping/scrolling, component surfaces,
  panel/scrollbar identity collisions, and moved/resized bounds. Independent
  assertions cover valid trees, surface presence, idle frames, edits and removals.
- Five existing tests on the combined variant: animation, clipping, scroll App,
  widget catalog and components.
- The typed-boundary workbench on the combined variant: 500 mixed transactions,
  domain/lifetime expectations, focus/composition and resize.
- A baseline equality counterexample: independently owned applications have
  equal logical collection entries but compare unequal through generic
  reflection. This demonstrates unnecessary invalidation, not stale output.

The parity programs use `mojo run`; the timing programs use `mojo build -O3`.
The first timing attempt was discarded when its provenance guard detected a
fixture changing during measurement. Only the subsequent frozen-input run is
reported. Raw build/run logs remain at the temporary path in `results.json`;
raw timing output, exact patches and source hashes are retained in the report.
Reproduce timings first, then verification, without editing inputs between them.

High confidence: the tested runtime has substantial avoidable paint work, and
fixing it is a better next performance step than increasing author-visible
reactivity complexity. Moderate confidence: selective declarations are useful
beneath the ordinary authoring API when measured against broad input costs.
Collection equality and composition/lifetime ergonomics still need explicit
solutions. A representative workload without these runtime gains, or a simpler
composition mechanism with robust measured selectivity, would change priorities.

No production source changed. The full repository suite, native renderer/GPU,
allocation profiling, async behavior and human usability were not tested.

## Production integration follow-up

The combined variant is now integrated into `src/moxi/column_runtime.mojo` on
the implementation branch. `integrate.py` compares the production runtime with
frozen commit `247cad2`, runs the independent `tests/paint_index.mojo` against
both versions, runs the existing native scene replay contract, and repeats the
original equivalent-tree frame probe. It preserves the historical ablation
reports. Run `python3 experiments/paint-costs/integrate.py` with competing builds
and tests stopped; see `integration.json` for fresh results.

The new regression is registered in `scripts/test.sh`; `pixi run --locked test`
passed all **82** files after integration. Native scene parity is a structural
backend replay check, not pixel equality or end-to-end latency measurement.
Command/ancestor indexing removes repeated lookups, but computing overflow
extents still scans descendants. The whole algorithm is not claimed linear.
