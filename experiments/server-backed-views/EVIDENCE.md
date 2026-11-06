# P02 implementation evidence

The approved local experiment is executable with actual Moxi application state,
events and SVG scene rendering. Confidence is **high for this bounded tested
path**, supported by native/Wasm fixture parity, HTTP cancellation/restart tests,
and real browser gestures with equal grid results. Another browser/toolchain,
long-running resource growth, different data distribution or a failing identity
case could change that assessment. This is not a supported general browser target.

## Source and capture provenance

Captured 2026-11-06T11:24:16.672Z on macOS arm64, Chrome 156.0.8078.81,
1440×1100 CSS pixels, scale 1. Base: `b4d8109ec94a8331415aa5f3548e1a6bdabb879e`.
The implementation is **uncommitted**, as required for parent review. The gallery's
`revision` field therefore identifies the integration base only, and its visible
title explicitly discloses that limitation. Schema validation passes; the
shared contract's **committed-source provenance gate is not yet satisfied**.
The parent must commit, rebuild and recapture before treating it as committed-source
evidence. The capture script detects changes to its executable source inputs.

- Executable-source SHA-256: `8e28a07461f10339875e539b3cfa45ccc47f5c76724237a8657de261f8c203ce`.
- Wasm SHA-256: `125a3bcf3a9487488ac1c0c52710c5a60a9a0324c2b83dd647d08b86e76618e9` (442,213 bytes).
- Dataset SHA-256: `cbc893afb24c38048ff9e30813c114c47ee1052bd18aa8963008ff93a04c991f`.
- [Raw comparison](comparison.json) records all eight runs, identities, individual
  timings, allocations and main/worker CDP snapshots. Separate
  [capture provenance](../../artifacts/demo-slideshows/server-backed-views/capture-provenance.json)
  records source inputs, screenshot hashes and actual per-view state.

Nine genuine browser PNGs cover initial grid, pending retained data, fresh grid,
aggregate selection, capped exact details, real network failure, retry, disposal
while pending and two-view restart. All nine were visually inspected. The selected
cell contains 966 records; the detail response returns 32 stable source IDs,
explicitly capped. [Slideshow](../../artifacts/demo-slideshows/server-backed-views/index.html)
and [manifest](../../artifacts/demo-slideshows/server-backed-views/manifest.json)
use the shared generator. The [README](README.md) gives exact commands and actions.

## Measurements and their scope

One run per route/delay, in alternating route order; no statistical performance
claim. Each fresh page loads the same million points and uses the same Moxi view,
then pans 72×30 pixels in eight pointer moves and wheels −160. The harness asserts
identical final camera bounds and all 1,024 counts for each route pair. B is disposed
before gesture and memory measurements. Initial server reductions can overlap B
and contend for the Python GIL; the reducer values below are only the settled pan
and zoom queries. Both routes display the same aggregate fidelity.

| Route | Server delay ms | Response/source body bytes | Reducer ms, pan / zoom | Local SVG submission ms, min–max | Fresh SVG ms, pan / zoom | Final main JS heap MB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| reduced | 0 | 17,094 | 402.7 / 586.3 | 5.7–7.2 | 431.4 / 601.5 | 2.93 |
| full | 0 | 20,000,000 | 17.1 / 15.2 | 4.4–6.0 | 317.9 / 320.4 | 2.99 |
| reduced | 150 | 18,049 | 386.6 / 364.1 | 5.0–7.3 | 558.2 / 531.6 | 3.00 |
| full | 150 | 20,000,000 | 20.2 / 18.8 | 5.0–6.4 | 324.6 / 322.3 | 4.89 |
| reduced | 600 | 18,050 | 342.7 / 281.6 | 5.0–6.1 | 961.4 / 899.0 | 4.88 |
| full | 600 | 20,000,000 | 18.2 / 17.9 | 5.0–6.1 | 339.8 / 326.9 | 4.87 |
| reduced | 1800 | 18,049 | 284.2 / 263.1 | 4.6–5.9 | 2107.5 / 2074.8 | 4.89 |
| full | 1800 | 20,000,000 | 17.2 / 14.8 | 4.1–5.7 | 319.4 / 315.3 | 4.88 |

Body bytes include initial data, subsequent queries and cancellation replies for A;
request-body bytes are recorded separately. Common HTML/JS/Wasm assets, HTTP headers,
TCP overhead, metadata and B are excluded. Full-data A fetches 20,000,000 bytes once
and retains them in a worker; it does not receive artificial delay. Reduced A never
fetches the full source and initial grid bodies are approximately 5,120 bytes. Detail
coordinates are available only through the separately capped exact route.

The Python reducer measures elapsed scan time, including scheduling/GIL effects.
The JavaScript worker reports summed active-chunk elapsed time excluding its
`setTimeout(0)` cancellation yields; browser timer clamping makes whole worker
queries take roughly 300ms. These are different implementations and timing scopes,
not CPU utilization or an architecture-only speed comparison. In this run the
Python reducer was slower and remote freshness worsened with added delay.

Local feedback starts at event-handler entry and ends after synchronous Moxi render
and SVG DOM submission, before requesting new data. Fresh timing starts at the last
camera event for the accepted query and ends after fresh SVG DOM submission; it
includes waiting for cancelled active work, transport, reduction and rendering.
Superseded queries have null freshness. Raw evidence separately records apply time
and the next animation-frame callback. Neither DOM submission nor next-frame
callbacks prove physical display presentation or hardware input latency.

CDP main heaps above exclude the full worker's 0.59–1.15MB used JS heap and its
20,009,272-byte backing storage (20,000,000 source bytes). Both routes also have
6,094,848-byte Wasm linear memory and SVG/DOM embedder memory; the raw snapshots
include these, DOM counts and allocator live/high-water values. These scopes overlap
and must not be summed as process RSS. No total-browser-memory speed/size win is
claimed from these snapshots. No forced GC, soak test, process RSS, server RSS or
peak transient-memory measurement was performed. The server retains source arrays
and a binary copy, approximately 40MB of data buffers before Python/runtime overhead.

## Focused verification

- `build.sh`: real Mojo compile, experimental P01 retarget/link, native/Moxi SVG
  fixture and Wasm checks pass. Geometry tolerance 0.0002px and color tolerance
  one 8-bit unit account for host floating-point contraction. Twenty recreate /
  dispose cycles end with zero live handles, allocations and bytes. Two independent
  views, nonfinite rejection and grid/exact caps pass. Clang emits the expected
  target-triple override warning.
- `test_server.py`: 10 tests pass, including million-point totals/binary digest,
  exact half-open fixture, real delay, cancellation before start/during delay/during
  reduction, one-job/session capacity, two sessions, request bounds and Host/Origin/
  static-path rejection. A real HTTP server stops/restarts on the same port with
  changed data; old revision is rejected and new revision succeeds. Python emitted
  ResourceWarnings for cleanup of expected HTTPError test responses.
- `adapter-check.mjs`: 40-change coalescing burst, at most one active and one pending,
  retained data, stale identities/malformed payloads, capped details, retry, disposal
  and isolated sessions pass. Original `probe.py` remains unchanged and passes.
- `browser-check.mjs`: nine captures and eight comparisons pass with no page errors;
  real pointer/wheel events, actual offline fetch failure, forged-session HTTP reply,
  stable exact IDs across reduction, same-cell reselection while details are pending,
  disposal/restart, concurrent restart and independent B are checked.
- Shared gallery generator's four tests pass. P02-only manifest validation and HTML
  generation pass; generated-gallery next/arrow/contact-sheet navigation and
  embedded PNG loading pass with no page errors. Whole-gallery validation fails because this checkout lacks the
  existing ignored `browser-fdg/01-initial.png`; other families were not changed.

Full logs remain in `/tmp/moxi-p02-build.log`, `/tmp/moxi-p02-server-tests.log`,
`/tmp/moxi-p02-adapter.log`, `/tmp/moxi-p02-probe.log`, `/tmp/moxi-p02-browser.log`,
`/tmp/moxi-p02-gallery-tests.log`, `/tmp/moxi-p02-gallery-scoped.log` and
`/tmp/moxi-p02-gallery.log`; generated gallery browser checks are in
`/tmp/moxi-p02-gallery-ui.log`. Live demo server output is `/tmp/moxi-p02-server.log`.

## Integration gates and exclusions

Parent review/commit and committed-source recapture remain outstanding. Restore or
reproduce other families' ignored PNGs before building the whole shared gallery.
Build outputs, PNGs and generated HTML are ignored local artifacts and need rebuilding
in another checkout. Reuse P01's runtime, retargeter and host at the integration base;
no core/native, P01 source, math editor or deferred-ledger changes are required.

The browser runs only the pinned experimental memory64 subset. Native window UI,
VoiceOver (paused), physical keyboard/accessibility usability, unsupported-browser
matrix, long sessions, multi-client load, actual remote/authenticated transport,
Jupyter, whole-repository tests and CI were not verified. Changed-revision recovery
is verified at the real HTTP contract boundary, not through an automated browser
backend-process restart. No public service, auth system, notebook adapter or general
query framework is introduced. No commits, pushes or PRs were made.
