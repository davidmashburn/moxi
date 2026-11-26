# D03 ordinary-window reset follow-up

This change starts at `0d6978e33c9d275b67faa292242f397f9e5c5152` and removes
the capacity-dependent steady-state reset cost from small default AppKit
windows. The 1,000-visible-node contract remains intact. The **8 ms p95 pan
gate still fails**: the measured full native path is 289.744 ms after this
change, versus 317.334 ms at the base in this run.

## Change and boundaries

Ordinary draw defaults are initialized once per window, then restored through
the preceding per-kind count before counts are cleared. Semantic slots follow
the same rule. The loops and semantic snapshot use the window's direct ivars,
avoiding repeated retained owner lookups for each field. Shrinking snapshots
release unused string references. Semantic publication still creates fresh
child/ownership arrays, but does not reserve 4,096 entries in empty arrays.
Retained semantic identity, notifications and complete publication are preserved.

The first reset still initializes every slot, preserving defaults for sparse
public indices and their holes. A previous high slot still requires resetting
its entire span. This is a CPU reset fix; it **does not reduce inline storage**.
`MoxiWindowState` remains 27,039,728 bytes (25.79 MiB), versus 22,388,720 bytes
at `bbf8b25`. Window retirement and initial allocation are not made proportional.
The 4,096 ordinary/semantic ceiling, 4,160 ordered entries and custom capacities
are unchanged. No Mojo publication algorithm or public ABI changes.

## Measured comparison

The same strict `clang -O2` small-window driver was built against native source
archives of `bbf8b25`, `0d6978e`, and the changed checkout. It opens a real
320×240 default AppKit window. Each process measures 40 empty frame resets,
40 empty semantic publications, and 40 one-label/one-button/one-semantic frames
including the production `drawRect` into a bitmap. Counts, geometry and green
button pixels are asserted. This includes Cocoa drawing, without compositor
presentation, a physical click or VoiceOver.

Three fresh processes per version ran serially, with the middle triplet in
reverse order. Every table cell pools 120 samples, including first samples;
percentiles use nearest rank. No samples were excluded.

| Small default window operation | `bbf8b25` p95 ms | Base `0d6978e` p95 ms | After p95 ms |
| --- | ---: | ---: | ---: |
| Empty frame reset | 1.706666 | 7.248625 | 0.010459 |
| Empty semantic begin/end | 0.245083 | 0.908042 | 0.001000 |
| Small frame submission including semantics | 1.445458 | 9.718500 | 0.094167 |
| Small frame through actual `drawRect` | 1.607792 | 11.410833 | 0.324084 |

The unchanged large-canvas driver was linked against base/changed native objects
with the same flags. Three fresh processes per version, alternating pair order,
each measured 40 normal `ScrollEvent` dispatches through App publication,
`render_canvas`, semantics and native `drawRect` at 1,200×800. PNG encoding is
outside the timers. These are the same 1,000 ordinary button components, 3,015
views, 3,013 paint commands and 3,014 ordered entries used by the capacity
acceptance test, with no native overflow. The historical 7,000×4,000 root is
also submitted and checked.

| Large native phase | Base p95 ms | After p95 ms |
| --- | ---: | ---: |
| Full scroll dispatch through `drawRect` | 317.334 | 289.744 |
| Dispatch/publication | 117.259 | 114.635 |
| Submission including semantics | 87.092 | 75.981 |
| Native reset, within submission | 5.532416 | 0.057333 |
| Semantic begin, within submission | 1.705625 | 0.123875 |
| Semantic end, within submission | 65.833334 | 62.596875 |
| Native `drawRect` | 116.875 | 99.740917 |

Phase percentiles are independent and must not be added. Source changes explain
the reset and semantic-begin reductions; differences in unchanged dispatch and
drawing are host variation, not evidence of optimizations to those phases.
Other work was active on this Apple M4, 10-CPU, 32 GiB host, running arm64
macOS 27.2.1 (26B131), Mojo 1.1.0 (`8189361e`). These measurements were captured
on 2026-11-26 UTC. They do not establish an isolated hardware speed ratio or an
allocator/retained-memory improvement.

## Regression evidence and reproduction

The local run root is `/tmp/moxi-d03-window-storage`. `manifest.json` records
exact commands, source/binary SHA-256 hashes, UTC times, environment, all raw
samples and per-process/pooled percentiles. `run.py` reproduces the comparison
from source archives, without another Git worktree. The earlier independent
report remains at `/tmp/moxi-pan-publication-e60317d/report.md`; this run uses
new measurements rather than copying that report's timings.

The reusable small-window probe can be run with:

```sh
bash scripts/canvas_checks.sh window-cost
```

To compare an archive, compile the identical `tests/canvas/native_window_cost.m`
with `-DMOXI_WINDOW_SOURCE='"/absolute/archive/native/macos_window.m"'`,
`-O2 -Wall -Wextra -Werror -fobjc-arc -fmodules`, and link Cocoa/QuartzCore.
Use a macOS GUI session and the repository's configured Mojo toolchain for the
large-canvas and lifecycle checks.

The boundary test now exercises every ordinary kind at sparse slot 4,095,
shrinks to empty/small frames, checks restored defaults and released payloads,
remounts the same semantic key at a new index, and retains an old child array
across republication. Existing tests retain overflow refusal, ordered capacity,
window isolation, input ownership, editor identity and native geometry checks.

| Check | Result and local evidence |
| --- | --- |
| Canvas rich/graph/keyboard/geometry contracts and clean precompiled consumer | PASS; `validation-canvas-check.log`, `validation-canvas-consumer.log` |
| Layer pixels/clips/owners and expanded high-slot reset/capacity | PASS; `validation-layers.log`, `validation-capacity.log` |
| Six large native runs, including translated NSEvent input, move/cancel/pan and preflight overflow refusal | PASS; `large-*-*.log` and four captures per process |
| Eleven-state rich and graph native replays, including editor identity through zoom/parent scroll | PASS; `validation-probe-capture.log`, `validation-graph-capture.log` |
| Native ownership/lifecycle and retained presentation/marked-range identity | PASS; `validation-lifecycle.log`, `validation-native_retained_presentation.log` |
| Authoring queue/focus/callback behavior, all 64 semantic ABI flag combinations, custom cache/rect equivalence, text alignment at 1×/2×, retained layout | PASS; corresponding `validation-*.log` files |
| Layout/component, canvas renderer/parity, native widgets/demo authoring, 200,100-rectangle capacity, paragraph/text parity and lifecycle runners | PASS; `extra-*.log`, `native-regressions.json` |
| Native frame resource validation | BLOCKED: local Kiwi archive/headers absent; documented bootstrap always fetches from GitHub, outside the no-remote scope. Initial link setup failure retained in `extra-build-native_frame.log` |

The manifest binds 58 native content PNGs to hashes, dimensions and capture
times. Six were directly inspected: large all-visible/moving-last, rich editor
zoom/clip, graph invalid/reconnected, and lifecycle reopened-A. These are
offscreen native content captures. Assertions establish interaction, identity,
refusal and in-process reopen behavior; screenshots alone do not establish it.
Detailed steps, expected/observed results and skipped checks are in the local
`report.md`. No compositor, browser, disk-persistence or physical-input result
is inferred from these captures.

Confidence is high in the reset reduction and tested compatibility. A failing
owner, editor, sparse-slot, semantic-snapshot or capacity case would change that
assessment. A new matching end-to-end run at or below 8 ms p95 would change the
gate result. Physical devices/IME, VoiceOver, compositor/GPU presentation,
60/120 Hz latency, sampled profiling, allocator profiling, other native
platforms, the full repository suite, sanitizers and remote CI were not tested.
No remote, shared ledger/index, other worktree or other agent was used.
