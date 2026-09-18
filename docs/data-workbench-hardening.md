# Workbench hardening evidence

This report records the 2026-09-18 hardening work on `feat/data-workbench`,
starting at `c267311`. The changes and measurements use a dirty working tree;
artifact hashes identify the tested executables. It supplements the earlier
[application validation](data-workbench-validation.md).

## Delivery and accessibility

Packaging now seals build provenance into the signed bundle and validates both
the staged and installed artifact. The artifact gate rejects a modified sealed
resource. The repaired prose guard rejects missing inputs and known editor
artifacts. Desktop launch remains a separate check: process presence alone does
not establish a responsive window or ordinary quit.

The first isolated replay used executable SHA-256
`c4f64bdbc10170b6c916913767a9ab0b1cfaa6ccd87f043e3cfdbb134f697b1c`,
PID 47019, and a unique copied bundle. Native automation observed the initial
48-row window, activated Sort Y once, observed descending order, and issued
Command-Q. The observer recorded process disappearance and no possible matching
crash report. LaunchServices startup stderr was unavailable. The local process
record and paired native observations are archived under
[`first-launch`](benchmarks/workbench-hardening-2026-09-18/first-launch/).

After the integrated suite rebuilt the bundle, the second isolated replay used
PID 60933 and executable SHA-256
`9f9f419dab5ea5bc7085cf01e64f5b4e88d81004e23f98c5c41782cbde37c477`.
Keyboard Return sorted descending, one AX press sorted ascending, and one
pointer click sorted descending. A screenshot showed both plots and the table.
Command-Q terminated this new process without a possible matching crash report.
The paired records are under
[`rebuilt-launch`](benchmarks/workbench-hardening-2026-09-18/rebuilt-launch/).

The native accessibility failure was an ABI mismatch. Six Mojo `Int` flags were
passed to C `int` parameters. On Apple ARM64 the argument layout corrupted later
fields, including the action mask, leaving otherwise published buttons inert.
Explicit `Int32` arguments fix publication. A regression test crosses the actual
Mojo/C boundary and checks all 64 flag combinations, float range values, and the
trailing action mask. Test probes are not linked into the application.

Native replay on macOS 26.6.2 (25G83), arm64, with the U.S. keyboard verified:

- AX Sort Y alternated descending and ascending with one action per change.
- AX field cycling and row selection changed the intended state.
- AX threshold replacement and keyboard editing filtered rows while retaining
  a selected source row hidden by the filter.
- CSV import loaded a controlled three-row fixture. AX selection and export
  produced exactly `key,time,value,y` and `1,2.0,5.0,8.0`; SVG export parsed as XML.
- Keyboard dead-key composition committed `café` in the path field.

This is AX-client evidence, not VoiceOver acceptance. VoiceOver speech and
navigation, CJK marked-text composition/cancellation, mixed-script paths, and
focus recovery across resize remain unverified. The dead-key check does not
establish those broader input behaviors. No reliable backing-scale measurement
was recorded for this replay; the raster parity test separately covers 1×/2×.

## Arbitrary source keys

`PlotDataTable.append_rows` validates an entire batch before mutation using a
temporary key set. It rejects malformed columns, negative keys, and duplicates
without a partial append. It preserves generated keys, version changes, typed
column missing values, and public mutable key storage. There is no persistent
index that can become stale. The workbench uses this batch path in source order.

Three repetitions at 100k rows measured reversed, shuffled, and sparse keys at
about 3.2–4.9 ms with batching, versus 3.35–4.31 seconds for repeated keyed
appends. Monotone keys are a tradeoff: about 3.5–6.6 ms batched versus 1.4–2.5 ms
for the existing fast single-row path. Raw local evidence is
[`plot-key-baseline.tsv`](benchmarks/workbench-hardening-2026-09-18/plot-key-baseline.tsv)
and [`plot-key-comparison.tsv`](benchmarks/workbench-hardening-2026-09-18/plot-key-comparison.tsv).

The batch has expected O(existing + incoming rows) validation time and temporary
set storage. The workbench also builds five parallel lists, roughly 18 bytes of
raw payload per visible row before capacity/allocator overhead. Allocation/RSS
cost was not profiled. Single-row arbitrary-key insertion remains unchanged;
callers ingesting large batches should use the documented batch API.

Regression cases cover invalid batches, mutation/copy/move/replace, exhausted
generated keys, arbitrary imported key order, sorting, filtering, hidden
selection, and exact selected-row export.

## Drawing measurements

See the [measurement method](workbench-benchmark-method.md) for exact boundaries
and reproduction commands. The native lane sums two independent offscreen
custom-command paints, not the complete native widget/window pipeline. It does
not measure event queueing, input-to-display latency, or window presentation.

On an Apple M4 (Mac16,13), using Mojo `1.1.0.dev2026082605`, the baseline
collected 100 measured repetitions per operation in each of three
fresh processes, after three warm-up cycles. At 10k rows, scroll median CPU work
was 19.984 ms; process medians were 20.089, 19.901, and 19.972 ms. At 100k rows,
the corresponding values were 185.065 ms and 184.277, 181.645, and 187.190 ms.
The first process overlapped some compilation/UI work; raw tails are retained
and are not presented as isolated-host latency guarantees.

At 100k rows the scroll phase medians were 0.750 ms dispatch, 0.087 ms retained
paint/conversion, 21.480 ms plot-scene construction, 3.343 ms native submission,
and 152.610 ms rasterization. At 10k, rasterization alone cost 16.375 ms. These
values support targeting rectangle drawing before adding a scene cache.

Attribution identified custom rectangle rasterization as the dominant cost.
The candidate replaces per-mark AppKit path objects with direct Core Graphics
paths, preserving separate alpha-composited fill/stroke operations and matching
AppKit flatness/line defaults. Oversized radii and degenerate geometry keep the
original path. Pixel comparison against the previous renderer passes exactly at
1× and 2× for fractional overlapping translucent, stroked, and clipped marks.
It introduces no persistent cache or mark reduction.

The same 3 × 100 comparison supports retaining this modest optimization:

| Scroll workload | Baseline median | Candidate median | Candidate p95 | Change |
| --- | ---: | ---: | ---: | ---: |
| 10k rows | 19.984 ms | 19.305 ms | 20.508 ms | −3.40% |
| 100k rows | 185.065 ms | 177.451 ms | 187.248 ms | −4.11% |

All twelve case medians improved by 3.1–4.8%. Each candidate scroll process
median was below every baseline process median. Confidence is moderate because
the host was not isolated. The measured raster span itself was almost unchanged
at 10k (16.375 → 16.390 ms), and fell only slightly at 100k
(152.610 → 151.554 ms). Reduced AppKit object cleanup outside that timer is a
plausible explanation for some total-boundary savings, not a separately measured
conclusion.

A phase-clock-off comparison used three processes with ten repetitions per
case. Median differences ranged from −0.60% to +0.75%, with mixed signs: no
systematic phase-clock cost was resolved at this precision. Outer and built-in
native draw timers remained enabled. All raw samples, per-process summaries,
and hashes are preserved in the [evidence bundle](benchmarks/workbench-hardening-2026-09-18/README.md).

Both scroll workloads still exceed the proposed 16.67 ms CPU target. This does
not establish 60 Hz support at 10k or 100k. At 100k, even scene construction
alone exceeds that budget; drawing remains the largest total cost. The next
performance decision should address repeated per-mark work while preserving
source identity and hit testing, rather than claim that this optimization
solved the support limit.

The persistent offscreen soak completed 506 interaction cycles over 630 seconds
(30 seconds warm-up plus 600 seconds measured), with every embedded correctness
assertion passing. RSS was 563.2 MB after warm-up and 413.9 MB at the end; during
the last roughly 330 seconds it stayed between 411.3 and 414.1 MB. No sustained
growth was observed in this interval. This is not a leak proof, and the process
overlapped other development activity.

A separate observation followed the actual rebuilt desktop process (PID 61848)
for 30 seconds warm-up plus 600 seconds measured, checking its identity, signature,
and executable hash. Eleven recorded native cycles filtered the 100k-row CSV on
`x > 600` / `x > 500`, scrolled, sorted, cleared the filter, and zoomed the window.
They were periodic, with a roughly three-minute gap between the first two cycles;
this was not continuous input. Selection remained intact, and the final export
contained exactly source key 0 with its original values. Both plots and the table
were visible at the end, and Command-Q terminated the process.

Desktop RSS was 603.9 MB after warm-up and 619.0 MB at the end, with a sampled
maximum of 765.8 MB. The final 4½ minutes ranged from 608.0 to 655.3 MB, with
no sustained upward trend. The differing window sizes and intermittent activity
make this an observation of bounded behavior during this run, not proof of leak
freedom or a low-memory guarantee. Raw samples and paired interaction records
are in the evidence bundle's `native-window-soak` directory.

## Integrated checks

`pixi run check` passed: 72 Mojo test files, artifact failure checks, API and
benchmark contracts, text conformance/parity, native rectangle capacity and
pixel equivalence, and the 64-case accessibility ABI regression. Native
screenshot parity passed its existing tolerance with 2 of 10,240 pixels
mismatching. Android/iOS host checks were explicitly skipped because their SDKs
were unavailable. Web/browser host and live-reload checks passed.

The native-window RSS observer was added after that integrated run; its syntax
and rejection paths were checked separately. No full software-lane performance
rerun, Linux benchmark build, VoiceOver acceptance, or CJK IME test was performed.
The benchmark harness currently links AppKit in both lanes and therefore builds
on macOS; this narrows harness portability without changing framework support.
No PR was opened, so remote CI was not checked.

## Authoring and remaining acceptance

An agent added a filter-sensitive count/mean panel in an isolated source copy
and passed routed-filter and existing workbench tests. The public guide now
explains visible-row accessors, derived labels, and the app-specific height
adjustment. The [exercise report](workbench-authoring-exercise.md) includes the
recipe and limitations. The worker already knew some implementation details;
an independent human authoring exercise remains open.

Confidence is high in the ABI diagnosis and batch-key correctness given direct
native reproduction and targeted regression checks. Broader reliable-desktop
acceptance remains open until VoiceOver and real IME workflows pass. The modest
CPU improvement does not establish native input-to-display latency. A failure
in those workflows, pixel parity,
or source-identity tests would change these conclusions.
