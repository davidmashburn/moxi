# D03 demand-grown native tables

This change starts directly at `379b1e5e708bc4e1f51f2963375e3fc02c94f2a2`.
Ordinary AppKit windows keep the historical 1024-slot allocation cost; valid
demand promotes their tables to the existing 4096-slot ceiling. The ordinary
1,000-visible-node consumer still passes. The **8 ms p95 native pan gate still
fails**, at 374.157 ms in this run versus 377.674 ms at the base.

## Storage and ownership

`MoxiWindowState` owns one backing object, initially `MoxiBaselineWindowTables`.
Its borrowed field pointers preserve the adapter's existing array accesses.
A valid indexed writer requests capacity before taking a slot address. The
ordered-entry count and image registry can also trigger promotion independently.
Ordinary/semantic capacity remains 4096; ordered capacity remains 4160.
Invalid submissions retain their previous refusal/overflow behavior.

`macos_window_tables.def` defines both fixed Objective-C layouts, their pointer
views, binding and copies. All 118 original fields retain their names, types
and dimensions. ARC owns object arrays and strong members of slot structs.
Promotion uses typed assignment for these fields; only float color arrays and
integer ordering arrays use `memcpy`. It rebinds pointers before releasing the
old backing and initializes only the new tail, preserving sparse defaults.
The window, canvas, field editor, semantic elements and payload objects retain
their identities. Callback owner selection remains unchanged.

Promotion occurs once per instance. Small frames and window close retain its
high water; destruction releases storage. A new instance starts at 1024 again.
Existing custom-paint arrays remain inline and unchanged. No public ABI,
Mojo publication algorithm, dependency or other native backend changed.

The table includes both state and backing, rather than treating the smaller
state class as the entire allocation. Payload objects and other AppKit/renderer
allocations are outside these totals.

| Storage on arm64 macOS | Class-layout bytes | Allocator-reported bytes |
| --- | ---: | ---: |
| Historical 1024-slot state, `bbf8b25` | 22,388,720 | 22,396,928 |
| Base 4096-slot state, `379b1e5` | 27,039,728 | 27,049,984 |
| Changed ordinary state + backing | 22,389,648 | 22,396,928 |
| Changed expanded state + backing | 27,040,656 | 27,049,984 |

The ordinary class-layout total saves 4,650,080 bytes versus the requested base
and adds 928 bytes versus the historical baseline. Allocator totals match the
corresponding historical sizes. Measurements use `class_getInstanceSize` and
`malloc_size`, not an RSS attribution. The changed state alone is 20,838,792
bytes; the baseline/expanded backings are 1,550,856/6,201,864 bytes. Both backings
coexist briefly during promotion: their combined class-layout total with the
state is 28,591,512 bytes, excluding payloads. Promotion adds an allocation
during submission; no allocation-failure recovery or shrinking policy is added.
A single warmed, empty-table promotion measured 0.810375 ms with `-O2` in
the final regression. This is not a latency distribution or a measurement of
promotion with a large live payload.

## Matched timing comparison

The identical `tests/canvas/native_window_cost.m` driver was compiled with
strict `clang -O2` against native archives of `bbf8b25`, the requested base,
and the changed checkout. Three fresh processes per variant ran serially,
reversing the middle triplet. Each measures 40 empty frame resets, empty
semantic publications and small frames through actual AppKit `drawRect` at
320×240, asserting counts, geometry and button pixels. Each cell pools 120
samples, including first samples, with nearest-rank percentiles.

| Small default window operation | Historical p95 ms | Base p95 ms | Changed p95 ms |
| --- | ---: | ---: | ---: |
| Empty frame reset | 1.622333 | 0.012583 | 0.012625 |
| Empty semantic begin/end | 0.242167 | 0.001250 | 0.001167 |
| Small submission including semantics | 1.924125 | 0.074416 | 0.086083 |
| Small frame through `drawRect` | 2.155292 | 0.195250 | 0.209542 |

Small-frame p95 increases by 0.014292 ms in this run. Median creation time over
the three processes is 0.019584 ms at the base and 0.301459 ms after moving
baseline initialization into instance construction. Median window-open time
is 156.147375/158.556042 ms; median destruction is 19.832125/19.624000 ms.
These few cold samples include AppKit startup and are not a speed-ratio claim.

The unchanged large-canvas Mojo driver was linked against base/changed native
objects using the same flags. Three fresh processes per version ran serially
in alternating pair order. Each measured 40 normal `ScrollEvent` dispatches
through App publication, `render_canvas`, semantics and native `drawRect` at
1200×800. This uses 1000 ordinary button components, 3015 views, 3013 paint
commands and 3014 ordered entries, with no native overflow. The historical
7000×4000-root submission is also checked. PNG encoding is outside the timers.

| Large native phase | Base p95 ms | Changed p95 ms |
| --- | ---: | ---: |
| Full scroll dispatch through `drawRect` | 377.674000 | 374.157000 |
| Dispatch/publication | 147.994000 | 146.337000 |
| Submission including semantics | 96.926000 | 94.032000 |
| Native reset, within submission | 0.070417 | 0.074583 |
| Semantic begin, within submission | 0.168875 | 0.193166 |
| Semantic end, within submission | 76.718417 | 75.529917 |
| Native `drawRect` | 137.984000 | 138.065750 |

Phase percentiles are independent and must not be added. Growth happens during
the initial large submission, before these scroll samples. Unchanged phases
vary with host load; these measurements establish neither an isolated speed
ratio nor a compositor/presentation latency. The host was an Apple M4 with
10 CPU cores and 32 GB RAM, arm64 macOS 27.2.1 (26B131), Mojo 1.1.0
(`8189361e`), with other work active. Capture date: 2026-11-26 UTC.

## Evidence and reproduction

The local evidence root is `/tmp/moxi-d03-demand-tables`. `manifest.json` records
commands, source/binary SHA-256 hashes, environment, UTC times, raw samples and
per-process/pooled statistics. `run.py` builds the comparisons from source
archives without another worktree. `schema-audit.json` reconciles all original
fields. `storage-reference.log` measures the historical allocation sizes;
the growth regression reports both current allocations.

All four large native content captures (all visible, selected last node, moving
last node and panned) are byte-identical between the first base process and the
last changed process; hashes are in `large-capture-comparison.json`. The changed
all-visible and moving captures were directly inspected. Pixel and interaction
assertions, rather than screenshots alone, establish visibility and behavior.

The binaries use this checkout's native implementation and the existing Mojo
toolchain in a macOS GUI session, with synthetic fixtures and no account role.
There is no browser or local web URL: this is AppKit. Tested content sizes are
320×240 for storage/small-frame checks, 1200×800 for the large canvas,
1060×780 for rich/graph replays, and 560×640 for lifecycle integration.
`capture-inventory.json` records hashes, pixel dimensions and approximate UTC
capture times for all 58 PNGs; command intervals and source/binary hashes are
in `manifest.json`. The native source hashes used in the timing runs remain
unchanged in the delivered implementation. Later changes extend test coverage,
documentation and capture-source inventories only.

| Scenario and steps | Expected result | Observed result and local evidence |
| --- | --- | --- |
| Run the unchanged native capacity regression; fill/sparsely address slot 4095, reset, shrink and overflow | Preserve defaults, semantic identity, isolation and the 4096/4160 ceilings | PASS; `validation-capacity.log` |
| Submit each of 12 ordinary/semantic kinds at -1, 1023, 1024, 4095 and 4096 on fresh instances | Invalid writes do not allocate; grow once at valid demand; release on destruction | PASS; growth regression and ASan log |
| Grow midway through a frame containing owned paragraphs, images, strong-member structs and a marked native editor | Preserve payloads, editor and semantic identities; release old backing | PASS; `validation-table-growth-asan.log` |
| Grow two windows, invoke A's callback while B is selected, then close A | Separate storage/counts; restore B's context; B stays open | PASS; same growth regression |
| Fill ordinary/custom ordering and image registry independently; replace a registered ID and saturate the registry | Correct growth, retained order/IDs and existing refusal behavior | PASS; same growth regression |
| Replay 1000 ordinary nodes, select/move the last, cancel, pan, hit-test and refuse excess publication | Every node paints; geometry/input align; overflow is refused before frame mutation | PASS in six matched processes; `large-*-*.log` and four byte-identical capture pairs |
| Replay rich/graph controls, native editing, zoom/parent scroll, invalid connection and reconnect | Preserve geometry, clipping, editor identity and transactional state | PASS; 11 captures per consumer and `validation-{probe,graph}-capture.log` |
| Edit a deep row, exercise owner callbacks, close/reopen and retain the sibling's independent edit | Preserve row/editor state and window ownership | PASS; `validation-lifecycle-retry.log` and 12 captures |
| Run native authoring and accessibility ABI regressions | Preserve input delivery, late callbacks and all 64 semantic flag combinations | PASS; `validation-native_authoring.log`, `validation-native_accessibility_abi.log` |
| Run retained presentation, paint cache, rectangle equivalence and text alignment regressions | Preserve rendering and retained-state behavior | PASS; corresponding `validation-native_*.log` files |
| Run canvas check, consumer, build and benchmark modes plus retained engine/native layout contracts | Preserve shared canvas and retained-layout behavior | PASS; `validation-canvas-*.log`, `validation-retained-layout.log` |

The rich zoomed editor, reconnected graph and reopened A captures were also
directly inspected. The first lifecycle attempt failed because this evidence
runner omitted its output directory; creating it and rerunning passed. A resume
script also initially omitted its compiler-flag variable; it was corrected
before the remaining checks ran. Both setup errors remain recorded locally.
The three gallery provenance scripts now include the new `.def` dependency;
syntax/source-inventory checks pass without regenerating tracked galleries.

Reusable native regression and small-window commands are:

```sh
bash scripts/canvas_checks.sh layers
bash scripts/canvas_checks.sh window-cost
bash scripts/canvas_checks.sh capacity
bash scripts/native_lifecycle_check.sh
```

Use a macOS GUI session and the repository's existing configured Mojo toolchain.
To compare an archive, compile the identical small-window driver with
`-DMOXI_WINDOW_SOURCE='"/absolute/archive/native/macos_window.m"'`,
`-O2 -Wall -Wextra -Werror -fobjc-arc -fmodules`, and link Cocoa/QuartzCore.
The ordinary rich/graph replay capture paths in this run are outside tracked
source. Tests use synthetic content and AppKit content drawing; no VoiceOver
or physical-input claim is made.

Confidence is high for the tested allocation, ownership and bounded-capacity
behavior; a failing owner/editor, sparse-slot or ceiling regression would change
that assessment. The pan gate remains open. Physical keyboard/mouse and real
IME interaction, VoiceOver (explicitly excluded), compositor/GPU presentation,
other platforms, allocation-failure injection, a full repository test sweep and
remote CI were not checked. ASan covers the focused growth regression; these
measurements do not attribute total process RSS or all AppKit allocations.
