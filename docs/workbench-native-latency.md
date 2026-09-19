# Native workbench timing

On 2026-09-18, a single macOS arm64 process recorded real native-window
interactions with opt-in instrumentation. Table scrolling took a median
19.203 ms at 10,000 rows and 83.364 ms at 100,000 rows from native event enqueue
to the end of the AppKit drawing callback. Confidence is moderate: this is a
small, instrumented run on a shared host, not display-presentation latency.

| Workload | Samples | Total median / p95 ms | Scene median ms | Drawing median ms |
|---|---:|---:|---:|---:|
| 10k table scroll | 12 | 19.203 / 20.463 | 3.737 | 8.593 |
| 100k table scroll | 12 | 83.364 / 90.845 | 24.505 | 50.337 |
| 100k row selection toggle | 6 | 396.438 / 424.949 | 88.163 | 261.393 |

The selection result is exploratory and was collected after the scroll runs.
Do not interpret differences from the earlier offscreen benchmark as a speedup:
the native window has different bounds, clipping, backing scale, and drawing
behavior. The shared host and small sample count also limit comparisons.

## Interpretation

In the baseline above, table-only scrolling rebuilt both plot scenes. `render_frame` called
`combined_scene`, which built scatter and histogram scenes and copied their
commands into the combined result. `MacOSCanvasSceneRenderer` then cleared and
resubmitted the native custom command buffer. The 100k scroll trace spent a
median 24.505 ms constructing scenes, 3.702 ms submitting them, and 50.337 ms
inside drawing; dispatch/layout itself took 0.732 ms.

This motivated retaining plot drawing output when only table offset changes:
caching scene construction alone would leave the larger drawing cost.
No rendering cache or optimization was implemented in that baseline
measurement pass.

## Plot output reuse

The workbench now opts into native custom-paint retention. A batch containing
only table scroll events skips scene construction and command submission if
both plot bounds still match the last rendered frame. Ticks that change state
and every other event invalidate reuse, including mixed batches. This is a
conservative event contract: filtering, selection, field changes, and plot
interaction all rebuild through the existing path.

The native host retains a transparent raster of the custom commands and
composites it at the same point in the draw order. New commands, custom clip
changes, view bounds, and backing scale invalidate the raster. Other native
hosts retain their existing behavior unless they explicitly enable the cache.

### Cache validation and native replay

Workbench tests passed, covering scroll reuse and conservative invalidation
for selection, filtering, axes, plot interaction, resize, and frame events.
The new `pixi run native-custom-paint-cache` check compares cached and direct
pixels at 1× and 2×, exercises warm reuse, and checks command, clip, bounds,
and backing-scale invalidation. It passed with six builds, eight hits, and
zero failures, and is now included in `pixi run check`.

The full `pixi run check` passed against the final source: 72 test files plus
native and host checks. Source hashes were unchanged across the run. Focused
cache pixel, rectangle equivalence, accessibility ABI, native capacity,
workbench build, and signed artifact checks also passed. Android and iOS
checks were skipped because the required SDKs were unavailable.

The native replay subsequently succeeded in a fresh desktop automation session,
using the exact path `dist/Moxi Cache Replay.app`. The normal packaged app also
launched and exposed its window successfully. No additional application change
was needed. The earlier `cgWindowNotFound` failure affected both corrected and
baseline bundles; its underlying cause remains unknown.

The same fixtures and twelve alternating one-page scrolls per size produced:

| Workload | Samples | Total median / p95 ms | Scene median ms | Drawing median ms |
|---|---:|---:|---:|---:|
| Cached 10k table scroll | 12 | 5.291 / 5.886 | 0.000 | 0.812 |
| Cached 100k table scroll | 12 | 4.589 / 5.018 | 0.000 | 0.653 |

Compared with the earlier baseline, median scroll-frame latency was 3.6× lower
at 10k and 18.2× lower at 100k. Confidence in the magnitude is moderate: these
are separate small runs on a shared host, not a randomized paired benchmark.
All 24 scroll frames skipped scene construction. Pointer-move frames still
rebuild plots and are excluded from both baseline and cached scroll summaries;
this is not a measurement of the total work caused by a gesture or continuous
trackpad scrolling. A larger paired run could change the reported ratios.

Live screenshots and accessibility state confirmed initial plot placement,
retained output after scrolling, selection markers, filtering with a hidden
selection, both axis field changes, window zoom/resizing, hover tooltips, and
linked plot-click selection. Both app launches ended with normal Command-Q
exit. Plot pan/zoom is not enabled by the workbench's plot specification, so
plot zoom was not accepted as a live feature. A physical display/backing-scale
transition, VoiceOver, and CJK acceptance were not repeated.

The [cache replay evidence](benchmarks/workbench-plot-cache-2026-09-18/) contains
the trace, workload line ranges and summary, source patch, build metadata,
replay bundle plist, final signed executable hash, and checksum manifest.
The copied bundle was re-signed after adding its replay identity, so its
executable hash differs from the original bundle hash in `build.json`.

## Reproduction and boundaries

Set `MOXI_NATIVE_TIMING=1` for stderr output, or set
`MOXI_NATIVE_TIMING_FILE=/absolute/path/trace.log` to enable timing and write a
file. The file is truncated at process startup. With neither variable set,
timing is disabled. The packaged default app does not enable it.

The measured bundle was a copy at
`dist/native-latency-replay/Moxi Data Workbench.app`; its Info.plist added
`LSEnvironment.MOXI_NATIVE_TIMING_FILE` and the copy was ad-hoc signed and
strictly verified before launch through native UI automation. PID was 23151;
executable SHA-256 was
`79edf616b6ab28ae1a487dee2021308e92582c5bff79b7b3ae8dfc6fdd098b0e`.
Normal Command-Q exit was verified.

The 10k fixture is the header and first 10,000 rows of the prior 100k soak CSV,
SHA-256 `c0dfbef98fc4b2618466efdaab923ea2a4997659019cd4dbf37c35a9ac6648ed`.
The 100k fixture hash is
`cdf7a41e39e7696589eed173a02c3ac8023a7f726ac5b4d708198a8862665388`.
For each size, twelve one-page scroll gestures alternated down/up within the
table, ending at offset zero. The trace also includes pointer-move frames;
the reported scroll summary selects only event kind 11. Six AX row-zero
activations (event kind 20) ended with zero selected rows.

Each row measures the first enqueue through the end of drawing for an event
batch; first/last event kinds and event count expose batching. Queue wait begins
after the native callback enqueues an event, so OS input delivery before that
point is excluded. `dispatch_layout_ms` spans the batch's dispatch interval.
`scene_ms` measures scene construction; submission is separate. The gap between
dispatch and scene construction includes retained UI rendering. Drawing ends
at the final callback probe, before trace formatting/I/O and callback return.
Compositor work, presentation, and input-to-photon latency are not measured.

The [evidence directory](benchmarks/workbench-native-latency-2026-09-18/)
contains the full trace, zero-based half-open workload line boundaries, summary,
source patch, build provenance, test bundle plist, and SHA-256 manifest.
The summary uses median and nearest-rank p95; with these sample counts p95 is
the maximum. Independent phase medians need not sum to the total median.

## Baseline validation

Native object compilation, workbench build, workbench tests, artifact checks,
all 64 native accessibility ABI cases, and `git diff --check` passed.
Root reviewed the instrumentation and performed
the native import, scroll, selection, and quit replay. The full repository
suite was not repeated after this instrumentation-only change; it passed at
the preceding hardening checkpoint. Disabled-timing overhead and sustained
latency distributions were not measured. VoiceOver and CJK acceptance remain
open as recorded in [native acceptance](workbench-native-acceptance.md).
