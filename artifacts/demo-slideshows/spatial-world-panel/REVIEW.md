# D08 range and gallery verification

The repaired range contract passes on public integration
`85b915424e7a7de85b18c0ccea46195d3617948c`. Six fresh, actual AppKit offscreen
frames were inspected at full 2000×1420 resolution. The offline deck and its
contact sheet decode the exact recorded PNG bytes and navigate correctly.
Confidence is **high for these fixtures and bounds**. A contrary native range,
clipping, ownership or lifecycle result on the same source would change that
assessment. This does not establish physical text-input or accessibility usability.

The capture began at `2026-11-26T03:19:50Z` on macOS 27.2.1 arm64, Mojo 1.1.0,
Apple clang 21.0.0 and SDK 27.0. All 194 scoped source files match the Git bytes
at that revision; aggregate source hash is
`ff972c8f7c77528d7e9723689a95d5024d1979d3c0f1c01df80f423148cb3def`.
The source remained unchanged through capture. The executable hash, sizes,
source inventory and toolchain are in [provenance.json](provenance.json).
Artifact-only edits are outside that application source inventory.

The native source owner is 400×240 points; the canvas is 1000×710 points at
2 pixels per point, with a 940×420 Metal target. Tests use synthetic controls
and native event/protocol calls, without accounts or customer data. Offscreen
AppKit capture includes the actual copied Metal texture/depth pass.

## Repaired range contract

[The native test](../../../tests/spatial/panel_native.m) checks insertion `0+0`
and substring `3+2` against independently projected four-corner bounds, allowing
0.01 point error. It also checks clipping, a populated scene, native focus,
snapshot isolation, invalid owners, retirement and recovery.

The critical native clipping case requests `3+2`. AppKit returns the full source
rectangle `(49.28125,56,14.6015625,19)` before clipping. With only half visible,
AppKit shortens its rectangle to `(49.28125,56,7.30078125,19)` while leaving
`actualRange` as `3+2`. The repaired destination rejects that incomplete range:
zero rectangle and `{NSNotFound,0}`. The test also preserves editor identity,
selection, text and active owner, rejects the other three partial boundaries and
a fully hidden range, and accepts a visible zero-width insertion. The actual
`NATIVE_PARTIAL_CLIP` measurement is retained in
[check-panel_native.log](review-logs/check-panel_native.log).

All three gallery replays independently report projected insertion and substring
ranges. `BASELINE_SOURCE_ONLY` is an old source-local diagnostic for comparison;
it is no longer a failing world result. The native input session, inverse text
hit testing and selection are still not fully proxied to the world destination;
world semantic children/focus remain suppressed. Promotion remains rejected and
D05 remains OPEN.

## Six inspected states

| State | Observed result | Acceptance |
| --- | --- | --- |
| [01 oblique](01-oblique.png) | Complete perspective panel, Apply 0, level 40; texture text visibly softer than screen mode | pass |
| [02 capture outside](02-capture-outside.png) | Slider endpoint and level 100; replay retains capture at local x=500 outside width 400 | pass |
| [03 projected range](03-projected-range.png) | Yellow substring outline on oblique field, Apply 1, level 100; projected-range footer | partial world editing; range assertions pass |
| [04 hidden click](04-hidden-click.png) | Deliberate left clipping and real red scene occlusion; both routes reject input | pass |
| [05 screen editor](05-screen-editor.png) | Crisp edited text, Apply 2, level 99, coherent native caret and synthetic text/clipboard/keyboard contracts | partial physical/AT acceptance; assertions pass |
| [06 cancel recovery](06-cancel-recovery.png) | Edited text and Apply 2 retained in memory; Escape restores level 99 and clears capture | pass |

No blank frames or unintended clipping were observed. Still images establish
appearance; replay assertions establish routing and cancellation. Four states
have pass acceptance and two retain explicit limitations; all six bounded replay
scenarios pass. Per-state steps, expected/observed results and limits are in
[review.json](review.json).

The previous gallery retained at this integration commit records `d7fa3ed` and
189 source files. Compared with it, five files were added and 43 changed; all six
PNG hashes differ at the same dimensions. Checksum-matching old PNGs were found
in the existing implementation checkout and copied locally as `baseline-*.png`.
The old third image was also inspected in full: it says WORLD FAILED and lacks
the new projected range outline. The third scenario intentionally changes from
`03-text-focus-failure` to `03-projected-range`; the exact metadata differences
are recorded. Other old frames were checksum-checked, not visually re-certified.
No controlled performance comparison is claimed across the changed source/host.

## Checks and offline deck

The 900-second bounded focused suite passed in 181.89 seconds: three C++ tests,
three native tests, four source-free packaged Mojo consumers and three packaged
replays. This includes 1,832 contract, 2,522 assembly, 143 native and 140 native
assembly assertions. Complete current logs are retained with hashes. The
42.88-second build and each of the three native gallery replays were bounded
(900/120 seconds respectively); process-group timeout cleanup passed a separate
one-second child-process check. Superseded old timeout-attempt logs were removed.

[check_deck.py](check_deck.py) opened the generated file directly in isolated,
offline Chrome 158.0.8127.37 using Playwright 1.65.2. At both 1440×1000 and
390×844, all twelve embedded images matched the six PNG hashes. Each viewport
passed 24 observed states: initial load, Next/Previous including wrap, left/right
keys, modified-arrow rejection, all six contact buttons, reload to slide one,
and selection of the repaired range frame. No HTTP requests, failed requests or
page errors occurred. [deck-check.json](deck-check.json) records the observations,
HTML/checker/screenshot hashes, browser and capture time.

Both full-page screenshots were inspected: [wide](deck-1440.png) and
[narrow](deck-390.png). Captions and contact buttons wrap without horizontal
overflow. The narrow native frame is an overview; full-resolution text inspection
used the original PNG. Reproduce remained collapsed; its expanded layout was
not checked. Reload verifies deck initialization, not application persistence.

Three cold and 90 warm timing samples are retained. Whole-draw p50/p95/worst are
12.732/35.748/62.704 ms; bridge timings overlap those measurements. These samples
do not establish sustained performance, compositor latency or production readiness.

## Limits and handoff

Not checked: physical pointer/keyboard/IME candidates, non-US layouts, VoiceOver
(paused), an assistive-technology client, human acceptance, scanout/input-to-photon,
multi-DPI quality, physical capture loss, sustained/thermal or memory pressure,
fresh-host installation, full repository suite and remote CI. D06/D07 packaged
replay assertions passed, but their images were not visually certified. In-memory
mode switching was checked; persistence across application restart was not.

[verify.py](verify.py) checks the Git source inventory, binary, PNGs, rendered HTML,
log hashes, range measurements, navigation record and timing distributions.
Controlled negative checks confirmed that an incorrect recorded PNG hash and
changed generated HTML are rejected; the original bytes were restored afterward.
The PNGs, offline HTML and binary remain deliberately generated/ignored locally;
review metadata, reproduction scripts and portable logs are committed. Raw logs
remain in `/tmp`; only machine-local path prefixes were normalized in committed
logs, with original/published hashes recorded. No shared gallery, ledger,
application source, public main branch or remote system was changed. The separate
[historical finding](HISTORICAL-GALLERY-AUDIT.md) remains read-only.
