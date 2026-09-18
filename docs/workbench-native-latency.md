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

Table-only scrolling rebuilds both plot scenes. `render_frame` calls
`combined_scene`, which builds scatter and histogram scenes and copies their
commands into the combined result. `MacOSCanvasSceneRenderer` then clears and
resubmits the native custom command buffer. The 100k scroll trace spends a
median 24.505 ms constructing scenes, 3.702 ms submitting them, and 50.337 ms
inside drawing; dispatch/layout itself takes 0.732 ms.

The next focused optimization should retain plot scenes and drawing output
when only table offset changes. Merely caching scene construction leaves the
larger drawing cost. Validate invalidation for selection, filtering, fields,
zoom, and bounds before accepting such a change. A repeated trace showing
another dominant cost would change this recommendation. No rendering cache or
optimization was implemented in this measurement pass.

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

## Validation

Native object compilation, workbench build, workbench tests, artifact checks,
all 64 native accessibility ABI cases, and `git diff --check` passed.
Root reviewed the instrumentation and performed
the native import, scroll, selection, and quit replay. The full repository
suite was not repeated after this instrumentation-only change; it passed at
the preceding hardening checkpoint. Disabled-timing overhead and sustained
latency distributions were not measured. VoiceOver and CJK acceptance remain
open as recorded in [native acceptance](workbench-native-acceptance.md).
