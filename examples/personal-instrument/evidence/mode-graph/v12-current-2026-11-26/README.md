# V12 current mode graph provenance

This additive replay addresses the I09/I12 mode graph provenance mismatch in
concept audit `d1da7c0`, including the later saved-graph recovery repair. The
parent directory's historical eight screenshots, fourteen hashed artifacts and
manifest remain byte-for-byte unchanged. Their old recorder/base and current
source are not treated as equivalent: only two of its four recorded source
hashes match this current checkout (`index.html` and `graph-check.cjs` differ).

The checkout started clean at fetched public `main`
`b2bfa42d713b4e78b50298c83b1fde5dfad76d6a` (contains `8caa40f`). Application code,
HTML, CSV and Moxi dependencies are unchanged from that revision. The existing
graph check only gained an initial capture, failed-startup/recovered-graph
captures and recovered graph/score observations. Its exact
[patch](capture-check.patch) and executed path hash are retained. The manifest's
revision identifies application source; the recorder ran with that capture-only
patch uncommitted. The separate scoped `offline-check.cjs` verifies decks, not
application behavior.

Chrome 158.0.8127.37 on macOS 27.2.1 arm64 ran normal pointer/keyboard/form routes
against `PYTHONPATH=python python3 examples/personal-instrument/app.py --port 0`
from this checkout. The exact loopback URL is in [results.json](results.json).
The check verifies the served HTML template's hash against the checkout before
acting. The isolated fixture uses repository CSV pitches and a synthetic score;
no personal browser/storage data is read. Capture interval: 2026-11-26
03:46:24–03:46:34 UTC (November 25 Eastern). CSS viewports were 1120×960 and
390×844, device scale 1. All eleven PNGs are full-page captures; their actual
SHA-256 values and IHDR dimensions are in [manifest.json](manifest.json), alongside
repository-relative source SHA-256 and dependency Git tree IDs.

| Actions | Expected | Observed |
| --- | --- | --- |
| Open Phrase controls; select step 2; Home/Right on Length; Extract Length; author Accent 75 → Length/keep, Length 37 → Accent/advance; Build preview | Direct source Length becomes 1; extraction/draft leave installed mapping/score intact | PASS: exact source edit, saved-record equality and custom build asserted. |
| Save; reload; select step 3; Input 68; Next/Apply/Next/Apply; repeat with focused pad Right/Space | Both modes/calculations/edges reopen; step 3 Length 60 and step 4 Accent 84, all unrelated fields intact | PASS: byte-equivalent full pointer/keyboard score; stable pad focus; correct keep/advance/wrap transitions. |
| Length midpoint 41; Ctrl+Enter; then not-a-number; Ctrl+Enter; reload | Valid calculation replaces panel without replacing focused editor/pad nodes; actual invalid `/build` returns 400 and preserves last-good 41% graph and full score | PASS: HTTP 400 awaited; active target, storage bytes, focus/node identity and persistence asserted. |
| Restore valid saved graph; inject HTTP 500 on startup `/build`; reload | Temporary defaults and explicit warning; exact stored graph and valid score retained | PASS: [fallback capture](saved-rebuild-failed.png), warning and byte-equivalent saved records. This transport fault is injected in the isolated browser, separately from the real calculation HTTP 400. |
| Remove 500 fixture; Versioned configuration → Copy saved to editor → Load draft → Save mapping; reload | Export retrieves the stored two-mode graph instead of defaults; Accent 75/Length 41, authored edges and full score reopen | PASS: exported graph equality, visible Length and byte-equivalent mapping/score after final reload; [recovered capture](saved-graph-recovered.png). |
| Reject invalid imports, storage faults/stale builds, corrupt records, legacy configs; resize to 390×844 | Last-good records survive; explicit repair/compatibility work; no document overflow or uncaught errors | PASS: ten scenarios, including 707 independent curve-oracle values, eight invalid build requests and six legacy cases. Full expectations/observations are in results. |

[Open the eleven-frame offline deck](index.html). Each slide contains actions,
expected results and a capture; the manifest also records observed outcomes.
The [offline record](offline.json) verifies `file:` loading with browser
networking disabled, embedded PNG decoding/hash/dimension checks, every Next and
thumbnail target, Previous, both arrow keys and wraparound. The
[navigation capture](offline-navigation.png) records the deck, not a live app.
No HTTP request, failed resource or page exception occurred. The live desk
continues to require its local Python build server; offline **evidence
navigation** is the claim here.

Reproduction commands are in the manifest. This run used Python 3.14.7,
Node 26.10.0 and `playwright-core` 1.66.0-alpha-2026-11-18 with installed Chrome.
The [graph log](replay.log) records all ten scenario passes. The unchanged
[baseline check log](baseline.log) records pointer/keyboard, persistence,
recovery, failed writes, wrap, narrow layout and muted playback scheduling.
Audibility was not assessed. To rerun the independent deck check:

```sh
NODE_PATH=/tmp/moxi-evidence/node_modules node examples/personal-instrument/evidence/mode-graph/v12-current-2026-11-26/offline-check.cjs examples/personal-instrument/evidence/mode-graph/v12-current-2026-11-26
```

The deck reuses the existing `scripts/demo_slideshows.py` loader/renderer directly.
To validate or render only this scoped manifest without touching any index:

```python
from pathlib import Path
from scripts.demo_slideshows import load_manifest, render
p = Path("examples/personal-instrument/evidence/mode-graph/v12-current-2026-11-26")
manifest = load_manifest(p / "manifest.json")
# Only when intentionally regenerating this scoped deck:
(p / "index.html").write_text(render(manifest))
```

[provenance.json](provenance.json) records artifact/source integrity and commands.
High confidence applies to these bounded sequences and exact source/image
identity; a failed replay at matching path hashes or an integrity mismatch would
change that conclusion. No arbitrary control extraction, arbitrary code/plugin
compilation, I10 consumer, physical/custom hardware, human authoring evaluation,
VoiceOver, other engines/devices, multi-tab behavior, broad suite, packaging or
CI was verified. No application code, historical evidence or global index/ledger
changed. No external posts or pushes occurred, and no additional agents ran.
