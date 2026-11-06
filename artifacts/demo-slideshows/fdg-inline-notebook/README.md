# Inline FDG notebook evidence (P04)

The actual Mojo solver, Moxi state/event routing and Scene renderer run in one
browser Wasm64 instance per output. Python receives bounded state summaries and
supervises the output lease through real anywidget comms. Local implementation
and automated acceptance pass; actual remote-kernel support remains unverified.

Open the [13-slide local gallery](index.html). Eleven acceptance captures and two
T3 collaborative-preview captures show selection/drag, pan/zoom/pause, isolated
outputs, resize/DPR 2, backend failure/recovery, actual kernel restart/recovery,
and offline saved SVG. All captures were visually inspected; PNG decoding,
dimensions and SHA-256 checks passed. The browser loaded all 26 slideshow and
thumbnail images and passed next/previous navigation. The master gallery validates
21 manifests. PNGs and generated HTML remain local and ignored.

[Manifest](manifest.json) and [evidence](evidence.json) record exact source/binary
hashes, dependency versions, checks and timing distributions. The acceptance run
used clean source at `08303c8`, comprising implementation `0cbd942` and test fixes
`f8b8cc9`/`08303c8`. Reproduce with
[INTERACTIVE.md](../../../examples/fdg/notebook/INTERACTIVE.md); gallery generation
rejects changed source or binary hashes. The two supplemental T3 captures use the
same binary, Chrome 154 at DPR 2, and are normalized to 1600×1200 screenshot pixels.

## Verification and measurements

The parent rebuilt the instrumented Mojo binary, passed three Python protocol/
real-fallback tests and the Node channel check (10,000 updates, stale ACKs,
timeout/closed comm cleanup), then ran actual JupyterLab/Chrome acceptance. It
verified busy-kernel feedback and final release, capture loss and Escape,
rerun/clear disposal, old-session rejection, a changed kernel PID, resource
shutdown, recovery, current SVG download and adapter-free offline SVG. There were
zero uncaught frontend errors. Two test assumptions were corrected after direct
diagnosis: capture loss is processed at the next pointer event, and a small drag
can change the next picked node through overlap. No adapter change was needed.

Python 3.13.11, JupyterLab 4.4.10, anywidget 0.9.21, ipywidgets 8.1.8,
jupyterlab_widgets 3.0.16 and Chrome 156.0.8078.81 were used. Full compiler and
resolved dependency versions are in the evidence file.

| Median milliseconds | 77 nodes / 254 links | 256 nodes / 1,024 links |
| --- | ---: | ---: |
| Solver/layout dispatch | 0.20 | 1.40 |
| Scene construction | 0.50 | 0.90 |
| SVG serialization | 1.30 | 3.60 |
| Wasm text transfer | 0.10 | 0.10 |
| DOM submission | 1.70 | 4.60 |
| Chromium Paint event | 0.441 | 1.2825 |
| Comm JSON serialization | 0.00 | 0.00 |
| Local comm roundtrip | 16.50 | 12.70 |
| Input to DOM | 3.60 | 11.20 |
| Input to next animation frame | 16.70 | 20.60 |

The timed windows collected 70 layout/Scene samples per workload after a 1.1-second
warmup. Paint events (153/138 samples) may occur more than once per frame and do
not measure GPU completion or scanout. Comm samples include earlier interactions
and intentional delay, so they are not network-only latency. Zero-millisecond
serialization medians reflect timer resolution. Input-to-DOM p95 was 3.9/11.6 ms;
input-to-next-frame p95 was 17.6/21.1 ms. Results are observations on one host with
other workers active, not a performance guarantee. The queue reached two slots
(one flight and one pending), with 34 coalesced updates and a maximum 285-byte
message against the 4,096-byte cap.

## Open gates and limits

Confidence is high for the exercised local lifecycle and protocol, based on real
notebook checks and source-backed instrumentation. Another frontend's cleanup
contract, a memory64-browser failure or remote-network results could change that
assessment. Actual remote kernel/network topology, other frontends/browsers/build
platforms, physical input and independent human usability remain untested.
VoiceOver remains paused. Full P02/P03 suites and CI were not rerun; their source
and shared seams were unchanged.

Visual inspection found crowded graph labels, zoomed nodes extending beyond the
graph rectangle, and clipped/cramped controls with visible horizontal scrollbars
at narrow width. The second graph is partly below the tall capture's viewport.
These captures establish the tested state and hit testing, not complete visual or
usability acceptance. The saved SVG is the initial settled state; explicit export
captures current state. Recovery recreates the initial graph rather than restoring
a checkpoint. P05 reuse and broader compatibility remain separate gates.

Raw traces, executed notebook and SVG are in `examples/fdg/dist/interactive/`.
Parent logs: `/tmp/moxi-p04-parent-prepare.log`, `-python.log`, `-channel.log`,
`-capture-final.log`; diagnostic failures are retained in `-capture-fixed.log` and
`-full-debug.log`. The browser script closed its own server/kernel; the separate
parent preview server was stopped and its ephemeral credential file removed.
