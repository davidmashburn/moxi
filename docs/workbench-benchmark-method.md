# Workbench CPU measurement

The workbench benchmark has two separate lanes. `software` preserves the earlier
headless software renderer workload. `native_offscreen` submits the same scenes
to the macOS custom-command adapter and draws them through AppKit into a
1280 × 900 bitmap at scale 1. Neither lane measures event queue latency,
window-server presentation, input-to-photon latency, or native text widgets.
This benchmark harness currently builds on macOS because both adapters are linked.

Run one lane at a time on an otherwise quiet host:

```sh
MOXI_BENCHMARK_PROFILE=full MOXI_WORKBENCH_LANE=software pixi run workbench-benchmark
MOXI_BENCHMARK_PROFILE=full MOXI_WORKBENCH_LANE=native_offscreen pixi run workbench-benchmark
```

Full mode uses three fresh processes, three unreported warm-up cycles per
process, and 100 measured repetitions of each case at 10k and 100k rows per
process. Quick mode uses one process and one measured repetition. Override
`MOXI_WORKBENCH_RUNS`, `MOXI_WORKBENCH_REPETITIONS`, and
`MOXI_WORKBENCH_WARMUP` to change those counts. Positive integers are required.
Use `MOXI_WORKBENCH_DIR` to preserve a named before/after artifact directory.
Each directory includes a frozen executable, pre-build source hashes, raw output,
process resource records, all individual samples, and per-process summaries.
Outliers are retained. The report checks case counts and correctness counters.

Each cycle recreates the fixture and App, then measures filter, hover, selection,
scroll, and resize in the same order. This avoids steadily accumulating selection
or reaching the table scroll limit. `cold_load` means fresh fixture/App/renderer
construction plus the first frame inside a warmed process; only the first
process startup is actually process-cold, and it is not an application launch
measurement. The fixture has monotone generated keys. Explicit key-order scaling
belongs to the separate key benchmark.

The initial viewport is 1180 × 820, resizing to 1280 × 900. The software surface
remains 1180 × 820 to preserve its original workload. The native bitmap is
1280 × 900 so it does not clip the resized scene. Retained and combined plot
scenes are submitted and rasterized separately, as in the earlier software
benchmark; this is a custom-command workload, not a replay of the native host's
retained widget rendering. Do not compare the two lanes as interchangeable
implementations of a complete native frame.

In the AppKit lane the retained and plot raster times are the sum of two
independent fresh bitmap paints. They are not composited into a single bitmap.
The host's overall `plot_bounds` clip is not installed. These boundaries stay
fixed before and after the drawing change, making the comparison useful for
that custom drawing path, without establishing complete native-frame timing.

## Timing boundaries

These are elapsed-time spans around synchronous CPU work, not thread CPU-time
samples. Scheduling and concurrent host activity can affect them. The baseline's
first process overlapped a short application/ABI compilation and desktop replay;
that contention and every resulting outlier are retained rather than rerun away.

| Field | Included work |
| --- | --- |
| `in_process_elapsed_ms` | Complete operation dispatch and frame work, including validation overhead |
| `dispatch_ms` | App dispatch, state changes, plot replacement, reconciliation and layout triggered by the event |
| `retained_ms` | Retained paint extraction and conversion to a Scene |
| `scene_ms` | Both plot scenes and combined scene assembly |
| `submission_ms` | Native custom-command submission; zero in the software lane |
| `raster_ms` | Software raster call or AppKit drawing into the offscreen bitmap |
| `validation_ms` | Software pixel checksum scans; zero in the native lane |

The spans intentionally do not claim to separate state mutation from plot data
construction inside dispatch. Native bitmap allocation, context setup, and object
cleanup are included in total time but outside the existing AppKit drawing timer.
Cold construction is likewise outside the frame phase spans. Total time therefore
need not equal the sum of reported phases. Scene command counts and App execution
invalidation counters accompany each sample. Native overflow is asserted to be
zero. Plot packet rebuild counters are observations of that specific cache; zero
does not imply that ordinary scene geometry was reused.

Correctness checks require valid views, source row preservation, a reducing
filter, nonempty emitted plots, successful hit-tested selection, scroll movement,
and resize validity. Native samples do not have a bitmap checksum; native visual
parity is a separate required check before accepting a drawing optimization.

To estimate incremental span overhead, repeat a lane with
`MOXI_WORKBENCH_INSTRUMENTED=0`. This disables phase timestamps while retaining the
outer operation timer, correctness checks, and the native helper's built-in draw
timer. Compare equivalent workloads with:

```sh
python3 scripts/workbench_benchmark_compare.py before/full.json after/full.json
```

The comparison rejects different lanes or host/toolchain settings and prints all
process medians beside aggregate changes. An improvement should exceed observed
between-process variability. A lower instrumentation-off median alone is not a
precise overhead estimate on a noisy host; retain the range and raw evidence.

Process peak RSS is not an allocation profile or a leak test. Recreating App
objects in these cycles is also not the planned persistent native-window soak.
That ten-minute workflow and interval resident-memory observations remain a
separate acceptance check. The proposed 16.67 ms CPU budget is a host-specific
target, not evidence of a displayed 60 Hz frame rate.

A supplementary persistent-App offscreen soak is available after building a
benchmark executable:

```sh
bash scripts/workbench_soak.sh dist/workbench-hardening/candidate-native/moxi-data-workbench-benchmark
```

It cycles filter, hover, selection, scroll, and resize on the same 100k-row App,
warms up for thirty seconds, then continues for ten minutes. Current resident
bytes come from `mach_task_basic_info` at thirty-second intervals. Raw samples
and the executable hash are preserved under `dist/workbench-hardening/soak`.
This observes App/renderer memory behavior without opening a window; it does not
close the persistent native-window soak requirement.

To observe the separately staged native application while replaying the 100k-row
workflow through the desktop, use an already running process:

```sh
python3 scripts/workbench_window_soak.py --pid EXISTING_PID --app '/absolute/staged/Moxi Data Workbench.app' --output-dir dist/workbench-hardening/native-window-soak
```

The observer never launches, interacts with, or quits the application. It records
RSS every thirty seconds through thirty seconds of warm-up and ten measured
minutes, verifies the process command and start-time identity, and checks the
application signature and executable/plist hashes before and after observation.
Pair those samples with the separately recorded desktop interaction replay;
resident-memory observations alone do not establish workflow correctness.
