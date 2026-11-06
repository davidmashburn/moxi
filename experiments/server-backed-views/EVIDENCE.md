# P02 implementation evidence

The approved local experiment is executable with actual Moxi application state,
events and SVG scene rendering. Confidence is **high for this bounded tested
path**, supported by native/Wasm fixture parity, HTTP cancellation/restart tests,
and real browser gestures with equal grid results. Another browser/toolchain,
long-running resource growth, different data distribution or a failing identity
case could change that assessment. This is not a supported general browser target.

## Source and capture provenance

Captured 2026-11-06T11:32:45.218Z on macOS arm64, Chrome 156.0.8078.81,
1440×1100 CSS pixels, scale 1. Implementation: `536442af0e3dd46cadf690a2af4f3fcc8c6c8503`.
The parent reviewed and committed the source, rebuilt it on the integration
branch, and reran the browser capture and eight comparisons. Executable sources
match that commit; the capture script fingerprints its source inputs separately
from this report and raw measurements.

- Executable-source SHA-256: `30bb2e342f88402b6243f5497cef5ec85fa45c552c7ba2734e1283008e138eba`.
- Wasm SHA-256: `926d841d721cee1f856bfc5f069331665c1231c0e6e5ca4aa50a55614a809990` (441,849 bytes).
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
| reduced | 0 | 17,094 | 439.0 / 358.1 | 5.6–7.2 | 457.0 / 372.0 | 2.97 |
| full | 0 | 20,000,000 | 23.2 / 24.8 | 5.1–6.4 | 303.4 / 313.4 | 3.00 |
| reduced | 150 | 18,050 | 517.4 / 464.6 | 6.4–7.4 | 686.5 / 634.0 | 3.00 |
| full | 150 | 20,000,000 | 27.2 / 23.2 | 6.6–7.3 | 316.0 / 294.2 | 4.86 |
| reduced | 600 | 18,051 | 515.9 / 495.9 | 6.5–8.7 | 1142.2 / 1112.7 | 4.88 |
| full | 600 | 20,000,000 | 27.9 / 28.5 | 6.6–8.4 | 324.4 / 319.5 | 4.87 |
| reduced | 1800 | 18,051 | 496.7 / 377.0 | 6.7–7.3 | 2323.1 / 2198.0 | 4.90 |
| full | 1800 | 20,000,000 | 21.9 / 23.4 | 6.0–7.3 | 317.3 / 309.4 | 4.88 |

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

CDP main heaps above exclude the full worker's 0.75–0.92MB used JS heap and its
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
- `test_server.py`: 11 tests pass, including million-point totals/binary digest,
  advertised root URL redirect with query preservation, exact half-open fixture, real delay, cancellation before start/during delay/during
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
- All six integrated gallery manifests validate. All nine fresh P02 browser frames
  were visually inspected. Shared generator tests were already passed and were not
  repeated because its implementation did not change. Browser gallery checks load
  all 18 embedded images and pass next/previous/contact-sheet/wrap navigation.

Parent logs: `/tmp/moxi-p02-integrated-build.log`,
`/tmp/moxi-p02-parent-server.log`, `/tmp/moxi-p02-parent-adapter.log`,
`/tmp/moxi-p02-parent-probe.log`, `/tmp/moxi-p02-integrated-browser.log`.
The parent fixed the advertised root URL to redirect to the canonical app directory
before loading relative modules; the browser harness now starts at that root URL.
The integrated server on port 8899 serves the main checkout; its log is
`/tmp/moxi-p02-root-server.log`.

## Integration gates and exclusions

Build outputs, PNGs and generated HTML are ignored local artifacts and need rebuilding
in another checkout. P01 runtime, retargeter and host are reused unchanged.

The browser runs only the pinned experimental memory64 subset. Native window UI,
VoiceOver (paused), physical keyboard/accessibility usability, unsupported-browser
matrix, long sessions, multi-client load, actual remote/authenticated transport,
Jupyter, whole-repository tests and CI were not verified. Changed-revision recovery
is verified at the real HTTP contract boundary, not through an automated browser
backend-process restart. No public service, auth system, notebook adapter or general
query framework is introduced. Changes are committed locally; no pushes or PRs were made.
