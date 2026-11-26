# D03 native capacity follow-up

The 1,000-visible-node workload now fits the ordinary AppKit presenter. The
8 ms p95 pan gate remains open. This work starts at public `bbf8b25`; it leaves
the D03 ledger and the D04 mind-map implementation unchanged.

## Bounded design

The existing instance-owned arrays now have 4,096 slots rather than 1,024.
Ordered paint retains another 64 entries for custom slices. No slot identities,
clips, editor ownership, event routing or wire values change. The canvas asks
the linked adapter for its capacity, checks both paint and semantic counts
before beginning the frame, and treats any adapter overflow as an error.
Rebuild the native adapter together with the Mojo package to provide the new
capacity-query symbol.

This is a finite capacity increase, not an unbounded allocation policy. On this
arm64 build, `class_getInstanceSize(MoxiWindowState)` grows from 22,388,720 to
27,039,728 bytes: **4,651,008 bytes (4.44 MiB) more per window state**. These are
inline state sizes; heap objects, allocations and resident memory were not
measured. Custom limits remain 32,768 lines, 4,096 circles, 262,144 rectangles,
256 text commands and 64 bitmaps. Component composition determines how many
objects fit; 4,096 slots do not imply 4,096 mounted components.

## Native output and input

The executable `tests/canvas_capacity.mojo` mounts ordinary button Components
on the existing 1,000-object / 2,000-port / 2,000-edge fixture. Its actual
1,200×800 AppKit window publishes 3,015 views, 3,013 PaintCommands and 3,014
ordered entries. After Fit All, a 64-point vertical pan keeps the entire graph
above the foreground minimap, avoiding obscured input targets and false pixel
matches against the blue minimap. The historical 7,000×4,000 root is submitted
separately and also fits.

| Scenario | Steps and expected result | Observed result |
| --- | --- | --- |
| All nodes | Render through `render_canvas`; rasterize the actual native `drawRect`; require button pixels for every node | PASS: 1,000/1,000 buttons; zero overflow |
| Last-node input | Verify object/port hits; enter ordinary child-control scope; send AppKit mouse-down/up NSEvents through the real translator and `dispatch_canvas` | PASS: last component clicked once; first component unchanged |
| Input scope | Test ordinary-control hits before entry, after entry, after leave and after pan/reentry | PASS: only the entered child's ordinary control owns the hit |
| Selected/moving | Select object 1,000; preview a −20,−20 world move; compare native button geometry with published bounds and hit the moved object | PASS: all 1,000 buttons still paint; moved geometry agrees |
| Cancel/pan | Cancel preview, verify restored world position; pan and recheck native/control/object geometry | PASS: restored position and aligned hits |
| Over-limit semantics | A 1,361-component fixture has exactly 4,096 PaintCommands but exceeds 4,096 semantic nodes | PASS: refusal before replacing the prior frame |
| Over-limit paint | Add component 1,362, exceeding the paint ceiling | PASS: refusal before replacing the prior frame; zero native overflow |
| Native boundaries | Set slot 4,095, reject slot 4,096, exhaust 4,160 ordered entries, reset and switch window owners | PASS: labels/buttons/panels/semantics retain high slots, reject overflow, clear storage and remain isolated |

Four PNGs come from caching the actual AppKit window content view, at 2× backing
scale (2,400×1,600): all-visible, selected-last, moving-last and panned. They are
native offscreen content captures, not compositor screenshots. Selected/moving
detail crops are enlarged review aids. Normal rich-node and graph consumers
also passed their eleven-frame native replays at 1,060×780 logical points,
including editor identity and geometry, child input, zoom/clipping and
move/cancel recovery. All fixtures are synthetic local consumers without an
authenticated user role.

## Repeatable measurements

Measured on Apple M4, 10 logical CPUs, 32 GiB RAM, arm64 macOS 27.2.1 (26B131),
Mojo 1.1.0 (`8189361e`), on 2026-11-26 UTC. Other work was active on this host;
these are local diagnostic wall times, not isolated hardware comparisons.
The native test bridge is built with `clang -O2`; Mojo uses `mojo build` defaults.

The CPU driver keeps the historical 7,000×4,000 workload, 40 samples per
operation, 3,015 published views and 8,443 Scene commands. It prints every raw
sample and consumes published geometry outside the timer. Three fresh-process
pairs alternated before/after execution order. Every process produced the same
geometry checksum, zero selection index writes and zero unrelated child builds.
Percentiles use nearest rank; the combined table has 120 samples per cell.

An experimental same-cell spatial-membership reuse path was tested and removed:
the end-to-end pan result did not improve consistently. The final CPU path is
unchanged from `bbf8b25`.

| CPU operation | Original p95 / p99 / worst ms | Rejected experiment p95 / p99 / worst ms |
| --- | ---: | ---: |
| Pan through Scene construction | 55.921 / 112.818 / 120.531 | 56.958 / 125.483 / 156.995 |
| Selection through Scene construction | 23.943 / 38.041 / 39.524 | 70.132 / 104.815 / 204.761 |
| Move preview through Scene construction | 26.089 / 53.329 / 57.064 | 31.677 / 48.752 / 55.450 |

Individual pan p95 pairs were 55.921→74.309, 39.877→56.745 and
70.934→50.555 ms. That variation prevents attributing a speed benefit to the
experiment. No samples were excluded.

The accepted native implementation also measures 40 alternating one-point
pans at 1,200×800. This timer includes normal App publication, paint submission,
semantics and an actual native `drawRect`, with no PNG encoding in the timer.
Every iteration must retain all 3,015 views and zero overflow; the final raster
must retain pixels for all 1,000 node buttons. Final native results and capture
hashes are recorded in the local artifact manifest described below.

| Accepted native workload | Samples | p95 ms | p99 / worst ms |
| --- | ---: | ---: | ---: |
| Pan through publication, submission, semantics and `drawRect` | 40 | 504.654 | 518.512 |

The first captured frame spent 1,055.151 ms in submission including semantics
and 114.493 ms in `drawRect`. Subsequent selected/moving/panned captures spent
296.118–330.691 ms and 99.237–103.802 ms respectively. These phase diagnostics
are separate from the 40-frame percentile population.

The 8 ms gate was not achieved. Full document/publication/index copies,
camera-dependent geometry and ordinary native submission/drawing remain in
this path. No profiler-based attribution or architectural lower bound is
claimed. A later solution needs new passing measurements with these output and
input checks retained.

## Reproduce and artifacts

```sh
pixi run canvas-contract
pixi run canvas-consumer
pixi run canvas-native-layers
pixi run canvas-capacity
```

`canvas-capacity` writes four actual-window PNGs to `dist/canvas-capacity` and
raw native samples to `/tmp/moxi-d03-capacity-consumer.log`. Set
`MOXI_CANVAS_CAPACITY_OUTPUT` and `MOXI_CANVAS_LOG_PREFIX` to keep a named run.
It requires a macOS GUI session. Test-only C helpers use the real adapter;
production clients continue using the normal AppKit ABI.

For a CPU comparison, build the same current driver against two source trees:

```sh
run_dir=$(mktemp -d /tmp/moxi-canvas-comparison.XXXXXX)
mkdir -p "$run_dir/base"
git archive bbf8b25 src | tar -x -C "$run_dir/base"
mojo build -I "$run_dir/base/src" -I examples tests/canvas_benchmark.mojo -o "$run_dir/before"
mojo build -I src -I examples tests/canvas_benchmark.mojo -o "$run_dir/after"
python3 scripts/compare_canvas_benchmarks.py "$run_dir/before" "$run_dir/after" --runs 3 --output "$run_dir/results"
```

The accepted sources intentionally preserve the original CPU algorithm. Use a
separate experimental source tree for any future optimization. The comparison
runner validates counts/checksums and retains individual logs, `samples.csv`,
binary SHA-256 hashes, run times and `summary.json`.

This run's local evidence root is `/tmp/moxi-d03-capacity`: `comparison/` holds
all six CPU logs and samples; `membership-reuse.patch` preserves the rejected
experiment; `accepted-capacity-consumer.log` holds the accepted native run;
`ui/` holds the four actual-window captures; `normal-probe/` and `normal-graph/`
hold the normal consumers' captures. `artifact-manifest.json` binds source,
binary and PNG hashes to the environment and capture times. These files remain
local and are not committed or published.

Confidence is high in the tested capacity, refusal, synthetic input and geometry
results, and high that these measured runs fail the 8 ms gate. An independently
passing end-to-end run with matching scene counts would change the performance
assessment. Physical devices, physical IME, compositor/GPU presentation, 60/120 Hz
latency, VoiceOver, memory/allocator profiling, other native platforms, the full
repository suite, sanitizers and remote CI were not tested. No shared ledger,
remote publication or shared-system communication was changed.
