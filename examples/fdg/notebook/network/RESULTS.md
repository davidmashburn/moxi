# P04 keyboard and assertion replay

The narrow viewport keyboard defect is fixed. A fresh local separate-kernel
replay passed **11 scenarios**, including the four strengthened assertions from
the review of `5301007`. The normal single-host notebook replay passed **16
checks**. Both final replays captured zero frontend exceptions. Physical
remote-host P04 acceptance remains unverified.

## Tested environment

- Separate-kernel capture started **2026-11-26 04:12:09 UTC** on base
  `530100772ee85696f61f6a7818a3f72524776589` plus the scoped changes accompanying
  this report. Its `evidence.json` records the checkout, dirty scope and source
  SHA-256 hashes. All recorded source/build hashes matched this checkout;
  `browser.wasm`, `widget.mjs`, `runtime.mjs` and `build.json` were byte-identical
  in both deployed copies. The bundled widget had no static import statements.
- Docker Desktop on one Apple Silicon machine, using cached image
  `moxi-p04-network:local`; Lab at `http://127.0.0.1:8952`, Kernel Gateway on the
  other container's internal bridge. Lab namespace `net:[4026533794]`, kernel
  namespace `net:[4026533642]`; no ipykernel process in Lab. Executing notebook
  code independently confirmed the kernel hostname and namespace. No external
  accounts, home/Docker socket mounts or live service data were used.
- Google Chrome **158.0.8127.37**, isolated headless Playwright profile,
  1600 × 1200 and 480 × 1100 at DPR 1. The normal Jupyter replay used this checkout
  at `http://127.0.0.1:8951` and also exercised DPR 2. Synthetic workloads were
  77 nodes/254 links and 256 nodes/1,024 links.
- Container Python 3.11.2, JupyterLab 4.4.10, Kernel Gateway 3.0.1, ipykernel
  7.4.0, anywidget 0.9.21 and ipywidgets 8.1.8. Wasm and the bundled widget were
  freshly rebuilt with Mojo 1.1.0 (`8189361e`), Apple clang 21.0.0 and LLD 24.0.0.
  This is a Linux runtime consumer check, not a Linux compiler lane.
- T3 preview was attempted first; two snapshot failures prevented usable visual
  evidence. The documented Chrome Playwright fallback produced the screenshots.

## Review requirements directly checked

The viewport stops propagation of scroll keys without preventing their native
browser action. Its listener uses the adapter's existing abort/disposal scope;
Tab continues into the graph, where the existing selection keys still work.

| Steps | Expected | Direct observation / result |
| --- | --- | --- |
| At 480 px, focus Dispose output; actual Tab, ArrowRight, ArrowLeft, Tab, ArrowRight | Viewport scrolls with focus retained; graph selection is unchanged until Tab enters the graph | **PASS:** native scroll became positive (3 px at the first observed animation frame), viewport retained focus, Left returned to zero; the next Tab entered the surface and Right selected another node. No injected widget handler or assigned `scrollLeft`. |
| Start a three-second real kernel execution; wait for its own busy status and stream marker; send 65 real pointer moves and release | Node/SVG feedback and pin/release occur before the execution finishes; bounded delivery and final backend release | **PASS:** x changed 891.336 → 923.336, SVG changed, pin was 1 during drag and 0 after release, with the execution still busy and unfinished at both observations. Maximum queue was 2; coalescing increased 16 → 56; final remote cumulative releases were 3. |
| Remove kernel interface, await resource shutdown, restore same IP, immediately click both Retry buttons | Recovery through Retry without a preceding execute warm-up | **PASS:** failure detected in 4.729 s; recovery observed in 2.681 s with the same channel identities and real remote ACKs. Hostname was queried only after recovery. |
| At 480 px, horizontally wheel each SVG target fully into view and click | Reachable full-size targets and meaningful actions without page overflow or wheel-induced zoom | **PASS:** Pause, Reheat, Fit, Labels, Neighbors, Export, search, empty-query Find, Less and More all exercised. Semantic target bounds were visible and enabled; document did not overflow; viewport was 338 px over an 800 px surface. Fit followed deliberate zoom; SVG download was saved. Less/More each reset cooled alpha to 1 while paused; charge magnitude is not exposed or asserted. |
| Observe ordered lifecycle mutations while rerunning A, including the detached old view | Old view/resources disposed before replacement becomes live | **PASS:** event 0 was old `live → disposed`, event 1 new `starting`, event 2 new `live`. All five old resource flags were false at disposal and at replacement live. This check runs before fault injection. |

The busy assertion follows status messages belonging to that specific execute
request. Jupyter's aggregate kernel status read `idle` during the actual busy
execution, so that aggregate value alone is not used as proof.

Trusted Shift+wheel reached the adapter with `defaultPrevented=false` and did not
zoom. Its automated scroll distance was zero. Physical browser axis conversion
remains unverified; the instructions now state that limit. Search coverage is
hit/focus plus Find's empty-query action; text/IME entry is outside the adapter's
input contract.

The other separate-kernel scenarios passed: namespace proof, gestures/output
isolation, phase/transport metrics, backend rejection and Retry, actual kernel
restart (PID **14 → 61**) with old resources stopped and fresh live widgets, and
saved offline fallback with two static SVGs and no live adapter. Paint and comm
samples remain separate in the raw record; no WAN/performance claim follows.

The normal consumer's 16 checks additionally exercised capture loss, Escape,
DPR 2 hit testing, replaced identity rejection, output clearing, restart and
saved fallback. The Python protocol/fallback/capacity suite passed **3 tests**;
the Node channel check passed **10,000 updates**, bounded delivery, stale ACK
rejection, final release, timeout, closed comm and disposal. Syntax and diff
whitespace checks passed.

## Evidence and limits

The untracked local run root is `/tmp/moxi-p04-keyboard-5301007`:

- `network-scope/evidence.json`, `topology.json`, `paint.json` and `captures/`
  contain the final scenario steps, expectations, observations, ordered lifecycle
  events, metrics and screenshots. Relevant images include
  `02-busy-local-feedback.png`, `03-narrow-keyboard.png`,
  `04-narrow-right-controls.png`, `06-network-retry.png`,
  `08-restarted-live.png` and `09-offline-fallback.png`.
- `normal-consumer/` preserves the normal record, two Paint traces, saved HTML
  and 11 screenshots. `packaging-final.json`, `build.log`, `channel.log`,
  `python.log`, `normal-capture.log` and `scope-capture.log` retain validation;
  `cleanup-final.json` records removal of owned fixtures and closed local ports.
- Earlier attempts remain under `network/`, `network-final/`,
  `network-verified/` and `network-complete/`. Harness refinements corrected busy
  status tracking and the lifecycle enum. Two attempts were interrupted after
  backend recovery; a third recorded a 30-second timeout on generic execution
  after gateway restart. The final sequence passed, but repeated
  post-partition restart stability is not established. Kernel operations now
  have bounded waits and each completed scenario is written immediately.

The final narrow, busy, recovery, restart and fallback screenshots were reviewed,
including normal restart/fallback images. Fixtures were torn down after capture;
cleanup verification checks only the owned containers/networks. Generated assets,
notebooks, credentials, logs, traces and images remain outside the commit.
Follow [README.md](README.md) to reproduce with a fresh directory.

Confidence is **high for the keyboard fix and the strengthened assertions in
this Chrome/Jupyter environment**. Renewed focus loss, feedback deferred until
execution completion, a warm-up before Retry, or replacement live before old
cleanup would change that conclusion. Restart/reconnect repeatability has the
failure history above. Physical remote hardware/WAN routing, TLS/SSH/tunnels,
deployment authentication, other browsers/frontends, physical input and
independent human usability were not tested. VoiceOver was explicitly skipped,
as were unrelated repository suites and Docker image builds/downloads. Dense
labels and graph overflow into shared SVG chrome remain pre-existing renderer
limits; this change does not close those acceptance gates.
