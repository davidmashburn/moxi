# Data workbench validation — September 18, 2026

Later fixes and stronger measurements are recorded in the
[hardening report](data-workbench-hardening.md). This document preserves the
original validation evidence and its limitations.

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

Use this as a local macOS numerical explorer with the documented bounded CSV
subset. Prefer 10,000-row exploratory workloads until native timing is measured.
The 100,000-row fixture is a correctness and stress workload, not a guarantee
of fluid interaction. Input limits protect ingestion size; they do not promise
that every accepted dataset is cheap to plot. In particular, arbitrary
nonmonotonic imported keys still exercise duplicate-key scans during plot
construction and can take quadratic time; the benchmark fixture uses monotone
keys. A future indexed or bulk construction path would be needed to extend the
large-data performance claim to arbitrary key order.

Native input-to-display latency, per-operation allocations, leak/soak behavior,
and cache reuse were not measured. Process peak RSS is not a leak test.
A known native accessibility activation defect remains: selecting custom
buttons by accessibility element did not invoke their action, although pointer
and keyboard activation worked and accessibility text assignment succeeded.
Headless semantic-action routing passes. The exact native/tooling boundary
has not been isolated, so the accessibility acceptance portion of planning
slice A2 remains open.

IME marked-text entry, mixed-script native editing, and VoiceOver usability
remain unverified. Accessibility publication and headless text conformance do
not establish those claims. No independent developer usability study or
cross-platform runtime test was performed. No release or public API promotion
is implied.
