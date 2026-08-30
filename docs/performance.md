# Performance and benchmark policy

Moxi treats performance as part of the UI contract. The benchmark suite makes
the amount of work visible in deterministic counters and records host timing
separately. This keeps comparisons useful across Mojo/compiler and GPU-driver
changes without pretending that a single machine's wall-clock result is a
portable guarantee.

## Run the suite

```sh
pixi run benchmark
```

The harness runs the retained layout/reconcile/paint path, the shared plotting
scenario, and the synchronized offscreen Metal scene. Each workload runs three
times by default. Use one run for a quick local check or choose another count:

```sh
MOXI_BENCHMARK_RUNS=1 pixi run benchmark
MOXI_BENCHMARK_RUNS=10 pixi run benchmark
```

Each Mojo benchmark prints deterministic counters such as scene commands,
vertices, rasterized pixels, and a checksum. `/usr/bin/time -p` prints `real`,
`user`, and `sys` for the host process around each run. The process timing
includes runtime startup and, for the portable cases, compilation/loading;
the Metal binary is compiled once before its measured runs.

## Workloads and budgets

| Workload | What it exercises | Stable signals |
| --- | --- | --- |
| Retained pipeline | layout, identity reconciliation, paint, scene conversion, fixed-extent range math | passes, child count, paint commands, checksum, operations/frame |
| Portable plot | plot scales, axes, labels, line/scatter/bar scene emission, software rasterization | commands/frame, rasterized pixels/frame, checksum |
| Offscreen Metal | scene batching, CPU vertex upload, one GPU draw submission, synchronized completion | frames, vertices/frame, overflow count, checksum |

`PerformanceCounters` exposes the first two workloads' work accounting to
applications and test harnesses. `PerformanceReport` can turn counters and a
caller-provided elapsed duration into average frame time, FPS, and a 60/120 Hz
budget check. A 60 Hz frame budget is 16.67 ms; 120 Hz is 8.33 ms.

The counters are not a frame-time promise. They are the regression signal to
compare first, followed by wall-clock timing on the same machine and build.
GPU work must report both CPU-side scene/vertex work and synchronized GPU
completion until an asynchronous presentation path exists.

## Optimization log

- The retained runtime uses an open-addressed `(id, kind)` index so a rebuild
  does not scan every old node for every new node.
- Virtualized lists release stale slots before allocating new ones, which
  turns scrolling into bounded reuse instead of unbounded view growth.
- The Metal backend batches rectangle and line geometry into one shared vertex
  buffer and one draw submission per frame.

When changing a hot path, add or update a deterministic counter, run the same
scenario before and after, and record the reason for the change in the commit
message. Do not optimize the plot or demo by changing its data shape: the
shared scenario is also a component and documentation contract.

## Current limits

The GPU slice currently renders basic rectangles and line geometry. Text,
images, path tessellation, gradient shaders, asynchronous frame pacing, and
GPU timestamp queries remain follow-up work. The iOS, Android, and Web targets
currently expose honest platform contracts; their native hosts/renderers are
not yet release targets. See [ARCHITECTURE.md](../ARCHITECTURE.md) and
[PROJECT-PLANNING.md](../PROJECT-PLANNING.md) for the staged roadmap.
