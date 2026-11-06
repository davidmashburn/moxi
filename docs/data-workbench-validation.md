# Data workbench validation — September 18, 2026

Later fixes and stronger measurements are recorded in the
[hardening report](data-workbench-hardening.md) and the
[support reconciliation below](#support-decision-and-remaining-evidence). The
walkthrough and measurements preserve their original September 18 scope; they
are not current-build acceptance results.

The workbench answers the synthetic tail-analysis question through a native
macOS window, with bounded local CSV input and CSV/SVG output. Confidence is
high for the tested data and event contracts, moderate for desktop usability.
A broader user study, native latency instrumentation, and assistive-technology
replay could change that assessment. This is an experimental application, not
a promotion of Moxi's platform or API stability claims.

Run `pixi run data-workbench`; see [the guide](data-workbench.md) for the data
contract and [the native host](../examples/data_workbench.mojo) for integration.
The implementation uses ordinary component, event, plot, and renderer APIs.

## Native walkthrough

Test host: Apple M4 (Mac16,13), arm64, macOS 26.6.2. The replay used the actual
AppKit window with pointer and keyboard input, screenshots, and macOS
accessibility-tree observations. Display backing scale and active input-method
identity were not recorded; input was Latin text and numeric values.

Verified in the visible application:

- Paste the absolute path to `examples/data/workbench-tail.csv` and import its
  12 observations. Select `value` as the filter field and enter `10`: keys
  6, 7, and 10 remain, with values 18, 21, and 28.
- Select those table rows and export CSV. Read the resulting file and confirm
  precisely those keys and all three numerical columns. Export scatter SVG
  and inspect its SVG document structure.
- Change the threshold to `20`: two rows remain visible while all three stay
  selected, with one hidden selection explicitly reported.
- Import malformed numeric input: the error is visible and the previous
  dataset and selection remain available.
- Clear the filter, sort, and activate the sort control with Return. Original
  row identities and selections survive order changes.
- Replace selected text using Command-A, copy with Command-C, and paste with
  Command-V. Paste through the native clipboard also works.
- Replace the dataset with a synthetic 200-row CSV, scroll the virtual table
  to source rows around 70, and resize the window. The scroll position remains
  stable. A focused row toggles with Return.
- Click the scatter point at source key 199 in the 200-row sample and export
  the selection: the CSV contains exactly `199,199.0,15.0`. Copy a focused
  table row with Command-C and paste its Y value (`1.0`) into a text field.
  Click the first histogram bin in that sample: all 18 observations in its
  value interval become selected, including source keys 0 and 1.
- Inspect distinct scatter/histogram regions, resized layouts, labeled text
  inputs, control names, and row identities in the accessibility tree.

The desktop replay exposed missing standard macOS menu commands. The native
adapter now installs Edit and Quit menus when its host has no main menu,
with responder-chain clipboard actions and a canvas fallback. This was a
reproduced integration defect, not an application-only shortcut workaround.
A 200-row replay also exposed the native custom rectangle buffer's 64-command
limit: scatter marks exhausted it and dropped later histogram rectangles. The
buffer now permits 262,144 rectangles (100,000 observations plus selection
overlays and plot decorations), with a native submission regression check.

## Correctness and regression checks

A subsequent fresh launch exposed a packaging defect missed by the earlier
running-instance walkthrough: macOS terminated the app before `main` with
`Taskgated Invalid Signature`. The executable's linker signature did not seal
the app bundle. Packaging now stages a fresh bundle, ad-hoc signs it, and runs
strict signature verification before installation. A fresh
`pixi run data-workbench` build and visible window launch passed after this fix.

The model tests cover stable keys, sorting/filtering, hidden selections,
atomic import failures, missing values, input size/row/column boundaries,
numeric parsing, and selected CSV round trips. App-level tests mount the
component and dispatch real routed pointer, keyboard, text, clipboard, resize,
and scroll events, including sparse-key histogram selection and file output.

`pixi run check` completed successfully, including 72 Mojo test files,
API/catalog/scenario checks, package builds, native text and screenshot parity,
and host checks. Its existing final prose-artifact guard names a missing
`Specification High-Performance Agent-Re.md` file and was therefore ineffective;
the command still returned zero. Focused workbench and native capacity checks
were repeated after the final plot/native fixes. Quick benchmark and benchmark
contract validation, text conformance, and the full regression benchmark also
passed. No remote CI or release preflight was run.

The application benchmark asserts row counts, selection identity, geometry,
and rendered output across cold load, filtering, hover, selection, scroll,
and resize at 10,000 and 100,000 source rows. Its timing boundary includes
retained paint and both plot scenes rasterized by the software renderer.

## Composed application measurements

[Recorded results](benchmarks/data-workbench-2026-09-18/full.json) include raw
samples, correctness counters, toolchain/hardware metadata, and process timing.
The [raw records](benchmarks/data-workbench-2026-09-18/records.tsv) are retained.
The [source manifest](benchmarks/data-workbench-2026-09-18/source-manifest.json)
identifies the measured implementation with SHA-256 hashes.
The source was an uncommitted implementation based on `a34963f`; these results
are exploratory and do not replace the repository's reviewed baseline.

Reproduce the three-run application benchmark with
`MOXI_BENCHMARK_PROFILE=full pixi run workbench-benchmark`.

Three process runs exercised all twelve workload cases (36 samples). Values
below are milliseconds, p50 / interpolated p95; three samples are too few for
a robust tail-latency estimate. The renderer is the headless software renderer,
not the native window. Cold load includes construction and first-frame work;
steady-state operations include dispatch, retained paint, and rasterization.

| Operation | 10,000 rows | 100,000 rows |
|---|---:|---:|
| cold load | 20.44 / 21.47 | 107.67 / 129.85 |
| filter | 9.59 / 19.19 | 28.15 / 39.35 |
| hover | 11.04 / 11.22 | 41.66 / 42.87 |
| selection | 10.97 / 11.01 | 39.55 / 42.90 |
| scroll | 10.73 / 10.84 | 38.96 / 39.64 |
| resize | 10.64 / 10.70 | 36.16 / 43.30 |

Most 10,000-row steady-state samples fit the proposed 16.67 ms CPU frame
budget, but filtering's p95 misses it. Every 100,000-row steady-state case
misses it. These measurements establish neither native frame rate nor visible
input latency. The benchmark still emits a mark per visible observation and
rasterizes the composed frame; it does not claim reduced geometry or cache
reuse. No timing decomposition proves which stage dominates. The support
decision is therefore experimental, with no 60 Hz guarantee at either size.

Peak process RSS was about 371 MiB across the combined two-size workload.
That includes the benchmark's software surfaces and both row-count cases;
it is not the native application's memory footprint or per-operation memory.

## Support decision and remaining evidence

Reconciled on 2026-11-06 against source at `fa42b6f` and the later evidence
linked below. This review adds no new desktop replay or performance samples.
The supported scope remains an experimental local macOS numerical explorer
with the documented bounded CSV subset. Prefer 10,000-row exploratory workloads;
100,000 rows remain a correctness and stress workload, without a general fluid
interaction or 60 Hz guarantee. Input limits bound ingestion size, not plotting
cost.

The [hardening report](data-workbench-hardening.md#arbitrary-source-keys)
supersedes the original arbitrary-key construction concern: the workbench uses
`PlotDataTable.append_rows`, which validates a batch atomically with a temporary
key set. The reported reversed, shuffled, and sparse-key timings belong to the
September 18 artifacts. Repeated single-row arbitrary-key insertion retains its
previous behavior; that is no longer the workbench's ingestion path.

The [native timing report](workbench-native-latency.md) decomposes event enqueue
through AppKit drawing completion and records implemented plot-output reuse for
table-only scrolling. Its September 18 cached-scroll p95 values were 5.886 ms
at 10k rows and 5.018 ms at 100k rows. Those small, instrumented samples exclude
pointer-move frames, which still rebuild plots; they establish neither complete
gesture cost nor input-to-display latency. Filtering, selection, field changes,
and other invalidating events retain the full rendering path. The original
software-rendered measurements above remain evidence for their own workload and
timing boundary.

[Offscreen and native soak observations](data-workbench-hardening.md) and the
[process memory profile](workbench-memory-profile.md) now provide bounded memory
evidence. The soak runs found no sustained RSS growth within their measured
intervals, while the profile separates residency, physical footprint, and heap
categories. They do not establish leak freedom, per-operation allocation cost,
or allocation ownership for the anonymous memory growth. Process peak RSS alone
remains insufficient for those claims.

The [native accessibility activation defect](data-workbench-hardening.md#delivery-and-accessibility)
was isolated to a Mojo/C integer-width ABI mismatch and fixed with explicit
`Int32` arguments. A 64-case ABI regression and native AX replay support that
resolution. The [native acceptance follow-up](workbench-native-acceptance.md)
also records path-field focus/caret preservation across window zoom/restore,
basic Japanese conversion and commit on September 23, and the user's observation
of spoken VoiceOver controls. Full IME editing, mixed-script input, the complete
VoiceOver workflow, and broader focus recovery remain unverified. VoiceOver
testing remains paused at the user's request; accessibility publication and
headless conformance cannot close that acceptance gate.

An [agent authoring exercise](workbench-authoring-exercise.md) supplies a tested
extension example, but independent human authoring remains open. The data
workbench has no recorded same-application cross-platform runtime acceptance;
Linux layout-workbench evidence concerns a different application. No fresh
current-build desktop acceptance or input-to-display latency measurement was
performed for this reconciliation. No release or public API promotion is implied.

Confidence is high that the documented batch-ingestion, AX ABI, and table-scroll
reuse mechanisms are implemented, and moderate in generalizing the historical
native measurements. Current-build native failures, a complete IME/VoiceOver
replay, independent human authoring, or presentation-timing measurements could
change this support decision.
