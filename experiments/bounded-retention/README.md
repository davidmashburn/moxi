# Bounded retained controls

This experimental copy of `../method-binding/runtime.mojo` reclaims unseen
control records and indexes paths and event IDs. Application fields, methods,
Int child keys, routes and declarations are unchanged. The production runtime
and historical experiments are untouched. Baseline: `feat/data-workbench` at
`c4f259d`; observed 2026-10-31 UTC (2026-10-30 local).

## Results

Eight live minimal panes have 32 active records. After 0/100/1,000 remount cycles,
the baseline retains 32/432/4,032 records; the candidate retains **32/32/32**.
Both allocate next IDs 33/433/4,033: IDs are never recycled within the host.
This measures record counts, not heap bytes or peak allocation. Compaction copies
live records and rebuilds both maps each frame; temporary allocation still exists.

Median real update + paint, milliseconds, same source probes compiled against
each runtime (O3, two warmups/five samples):

| Visible minimal panes | Baseline | Candidate |
| --- | ---: | ---: |
| 10 | 0.045 | 0.037 |
| 100 | 0.557 | 0.329 |
| 300 | 2.737 | 1.273 |
| 1,000 | 22.072 | 7.347 |

At 1,000 panes the candidate is about 3.0 times faster in this run. Median update
is 21.199 versus 6.512 ms; paint is 0.902 versus 0.835 ms. Combined medians are
computed per sample, not by adding separate medians. Combined ranges are
21.662–22.606 versus 7.295–7.880 ms.

The 1,000-remount batch takes 93.565 versus 53.302 ms (ranges 91.619–94.672 and
50.535–53.714). Each cycle contains two frames; these are batch totals, not
single-frame latency. The 100-cycle batch is 5.413 versus 5.121 ms. Zero cycles
is an empty control. Baseline and candidate run serially, baseline first, after
all compiler/correctness work finished. The machine is unisolated; this is one
local diagnostic run, not a randomized statistical comparison or native latency
measurement. Each pane has one input/button and generates four records/three
view leaves in a 960 by 20,000 logical viewport. Do not compare directly with
the complete editor workloads from earlier experiments.

## Verification

GPT-5.6-Luna at maximum reasoning implemented the copied runtime and probes.
The parent reviewed the runtime diff, correctness tests and runner, verified
source/binary hashes, reran candidate correctness independently, and recomputed
timing medians. Both variants pass visible 10/100/300/1,000 and churn 0/100/1,000
checks, including live editing state, focus, caret/anchor, active IME/ranges,
reordering, copied retained indexes, and stale action/event rejection.

The primary scale check reorders siblings around the focused editor and uses a
collapsed ordinary selection. The separate parent combined check in
`../scoped-identity/run_combined.py` moves the focused editor with a nonempty
selection and active IME. All five combined checks pass. It also verifies empty
record/index reclamation, clearing removed focus, remounting the exact same path
with fresh IDs and fresh editing state, and independent retirement in a copy.
The combined runtime is generated temporarily; neither candidate is overwritten.
Its performance was not measured.

## Contract and limits

A live path retains its record, ID and editing state. An absent path is reclaimed
at the end of rebuild. Reappearance after absence receives a new monotonically
allocated ID, even when its path is identical. Copied hosts own independent
record lists/maps. Duplicate paths and kind changes still hit the existing
runtime guards; this slice does not broaden supported declarations.

Retained descriptors still require application route guards. The runtime does
not infer new model lifetimes, prevent generation reuse across root/collection
replacement, or scope IDs across different host sessions. It still rebuilds all
declarations, and other scans remain; no claim of linear whole-frame complexity
is made. Counter overflow, allocated memory bytes, native event queues/pixels,
full production tests, CI, and human authoring comfort were not evaluated here.

High confidence that reclamation bounds retained record count for the tested
churn while preserving behavior. Moderate confidence in the measured speedup's
size beyond this machine/workload. A regression under realistic large documents,
other ownership patterns, or native interaction would change the recommendation.

## Reproduce

```sh
python3 experiments/bounded-retention/run.py --prepare
# After compiler and other experiment work finishes:
python3 experiments/bounded-retention/run.py --measure experiments/bounded-retention/prepared.json
python3 experiments/scoped-identity/run_combined.py
```

`prepared.json` records hashes, compiler/platform, build commands and correctness
outputs. `results.json` records all 70 timing samples and separate update/paint
summaries. Delayed measurement verifies source and binary hashes. Temporary paths
are local evidence; rerun preparation on another machine to regenerate binaries.
