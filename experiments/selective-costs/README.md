# Selective-update cost experiment

This is an isolated, bounded timing follow-up to
[`selective-updates`](../selective-updates/). It measures work that the earlier
experiment intentionally did not measure: full `App` dispatch/rebuild/paint
around an identical edit, plus shared equality and snapshot creation. It does
not modify the earlier experiment, the state-access authoring files, Moxi
production code, or any build manifest.

## Reproduce

From the repository root:

```sh
python3 experiments/selective-costs/run.py
```

The runner compiles `benchmark.mojo` exactly once with:

```text
pixi run --locked mojo build -O3 -I src \
  -I experiments/state-access -I experiments/method-binding \
  -I experiments/selective-updates -I experiments/selective-costs \
  experiments/selective-costs/benchmark.mojo -o <temporary-binary>
```

It then runs the binary once, writes machine-readable raw samples and summary
statistics to [`results.json`](results.json), and keeps compiler/run logs in a
temporary directory. The report records the compiler, machine, branch/commit,
commands, working-tree status, and SHA-256 hashes for the benchmark and every
Mojo source used by the benchmark, including `src/` and the imported earlier
experiment sources.

## Protocol

The three compared modes are:

- `handler`: the old `HandlerHost[Application]`, which renders the whole
  declaration tree after a handled update;
- `all_inputs`: `SelectiveHost[AllInputs]`, including reflective comparison and
  an owned `Services` snapshot; and
- `display_inputs`: `SelectiveHost[DisplayInputs]`, comparing only document
  name and writable state.

For each mode at 2 and 100 editors, `frame` samples create a fresh App, warm it
with two unreported runs, paint a baseline frame, and then time the same
logical operation. The 1,000-editor case uses one warm-up and one measured
sample per operation as an explicit feasibility cap:

```text
App.update(event) + App.paint()
```

The local operation edits the last editor's draft from `Ada` to `Local`. The
shared operation first prepares that same draft outside the timer, then sends a
real pointer click to that editor's Apply control; the timed operation changes
the shared document to `Local` and commits it. The update is actual `App.update`
dispatch, not only `Component.update`, and the paint is the backend-neutral
Moxi command stream. It excludes native window work, renderer submission, GPU
execution, and display latency.

Additional stage rows are deliberately labelled:

- `build_layout`: `Component.build()` including parent composition and
  `ColumnView` layout, without `App` runtime reconciliation;
- `app_rebuild_idle`: an idle `App.rebuild()` including component build and
  retained-runtime reconciliation, without paint; and
- `paint_after_update`: `App.paint()` after a real local update, excluding that
  update.

The stage rows are not substitutes for the `frame` rows. In particular,
`app_rebuild_idle` is not an edit path and `build_layout` is not a native frame.

Separately, `snapshot_create`, `equality_same`, and
`equality_alternate_tail` use history sizes 0, 10,000, and 100,000. Each model
case has one warm-up and three measured samples. The equality cases compare a
snapshot with identical data and with data differing only at the tail (or the
document name when history is empty), so the walk is observable rather than a
constant known mismatch. Checksums and expected boolean results are consumed
outside the timed regions. Frame/stage checksums omit retained identity IDs and
non-leaf composition/decorative records (component containers, surfaces, and
panels); they are compared across all three modes as a visible-leaf output
equivalence check. The selective tree has additional retained composition
wrappers by design, so this is not a claim that the full retained trees or
command streams are byte-for-byte identical.

## Captured findings

The verified run was on commit `e66cdd95dcffce3519fb6970087a15fe1821a4db` on
`feat/data-workbench`, using Mojo `1.1.0 (8189361e)` at `-O3` on an Apple M4,
macOS `27.0.1`, arm64. Validation passed for 87 frame/stage rows and 27 model
rows. Exact raw samples, ranges, source hashes, and the pre-existing dirty-tree
status are in [`results.json`](results.json).

Frame medians at 100 editors, in milliseconds (`App.update + App.paint`):

| mode | local edit | shared Apply edit |
| --- | ---: | ---: |
| handler | 14.974 (14.968–15.102) | 14.972 (14.866–15.662) |
| AllInputs | 33.997 (33.585–38.536) | 34.826 (34.630–34.917) |
| DisplayInputs | 33.773 (33.683–34.319) | 34.812 (34.725–39.628) |

At 2 editors the medians span 0.038–0.040 ms for local edits and
0.039–0.050 ms for shared edits. At 1,000 editors the cases completed only
with the explicit cap of one warm-up and one measured sample per stage/frame;
the single frame samples were handler `1,427.731/1,410.760 ms`, AllInputs
`3,412.468/3,338.096 ms`, and DisplayInputs `3,305.459/3,304.376 ms` for
local/shared operations. These are feasibility measurements, not stable
statistics.

At 100 editors, the separate stage medians were `build_layout`: handler
0.145 ms, AllInputs 0.445 ms, DisplayInputs 0.404 ms;
`app_rebuild_idle`: 0.359/2.836/2.787 ms; and `paint_after_update`:
13.577/32.065/33.177 ms, respectively. This decomposition shows where the
measured frame cost appears in this headless command-stream path, but it does
not prove a particular implementation-level cause.

The model timings were snapshot creation `0.004/8/77 µs` at history
`0/10,000/100,000`; equality with the same data `0.004/62/531 µs`; and
equality against an alternate tail `0.002/59/504 µs`. Empty-history values are
normalized from 1,024 repetitions because one call is below useful timer
resolution; the raw totals and repeat counts are retained in the JSON. The
snapshot loop includes temporary construction/destruction and may be optimized;
these microbenchmarks are diagnostics rather than allocation-cost measurements.

## Limitations

The experiment measures elapsed time for CPU work in an optimized Mojo process. It
does not establish native renderer, AppKit, GPU, input-device, scheduling, or
end-to-end user latency. It also does not measure allocations or memory. The
same source and compiler are used for all three modes, but the modes have
different retained identity bookkeeping and composition wrappers by design;
the correctness check compares visible leaf kind/text/enabled/checked state,
not the full structural command stream.

The large-history baseline is intentionally modest: three measured samples and
one warm-up at each size. The 1,000-editor case is also intentionally capped to
one warm-up and one measured sample because the full-render baseline is
multi-second on this machine; the cap is recorded in the report rather than
silently presenting it as a multi-sample result. No old result generator or
manifest is run or changed by this experiment.
