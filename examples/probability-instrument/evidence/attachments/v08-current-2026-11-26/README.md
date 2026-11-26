# V08 current attachment provenance

This additive replay addresses the I05 attachment provenance gap in concept audit
`d1da7c0`. It does not replace the nine PNGs and narrative in the parent directory
or attribute them retroactively to a source revision.

The checkout started clean at fetched public `main`
`b2bfa42d713b4e78b50298c83b1fde5dfad76d6a` (contains `8caa40f`). The application,
HTML, geometry fixture/generator and Moxi dependencies are unchanged from that
revision. Only the existing browser check changed: it records source hashes and
DOM observations, verifies the actual served HTML, strengthens fractional-transfer
assertions and permits retaining a minimal screenshot subset. Its exact patch is
[capture-check.patch](capture-check.patch); its executed SHA-256 is in both
[results.json](results.json) and [manifest.json](manifest.json). The manifest's
revision identifies application source, not the formerly uncommitted recorder.

Chrome 158.0.8127.37 on macOS 27.2.1 arm64 exercised the normal running Python app
using public Moxi Python rendering, fresh isolated browser contexts, synthetic
probabilities and device scale 1. Capture interval: 2026-11-26 03:46:24–03:46:32 UTC
(November 25 Eastern). The recorder starts its own loopback HTTP server on an
ephemeral port; exact run URLs are retained in results. CSS viewports were
1280×800 and 390×844. PNGs are full-page captures; their heights differ from the
viewport. Every retained PNG has its actual SHA-256 and IHDR dimensions in the
manifest. Dependency Git tree IDs and repository-relative source SHA-256 values
identify the exact tested paths without a machine-specific checkout path.

| Actions | Expected | Observed |
| --- | --- | --- |
| Pin mean; outcome 1; request .2 on plot; transfer to triangle; Enter | Same pending probe, selection, pin, request, reading .2/reference .5/change −.3 and draft (.4,.2,.4); commit advances reference to .2 | PASS at both viewports; exact text/cells and triangle dot (266,121) asserted. |
| Outcome 2; hold pointer through Escape, move/release; repeat and commit; request .8; switch attachment | Cancel survives release; second edit commits (.5,0,.5); infeasible input stays available with Apply disabled and reference .5 | PASS at both viewports; reload resets the experiment; independent triangle basis measurements also passed. |
| Reload with mean free; outcome 2; request .3333333333333333; transfer plot → triangle; Apply | Draft (.2222222,.4444444,.3333333), mean 1.111111, survives transfer; committed cells change only on Apply; document stays within 390 px | PASS at both viewports. Narrow screenshot/table visually inspected. Field remains a native fixed-width number input and can horizontally scroll its long text; the table and controls fit the document. |

[Open the seven-frame offline deck](index.html). Each slide has its action,
expected result and screenshot; the manifest also stores observed outcomes.
The result record retains all fourteen state observations from both viewports,
including states whose redundant PNGs were deliberately not retained.

The [offline record](offline.json) verifies local `file:` loading with browser
networking disabled, decoding/hash/dimension checks for every embedded PNG,
all Next/thumbnail targets, Previous, both arrow keys and wraparound. Its
[capture](offline-navigation.png) is a deck-navigation screenshot, not another
application state. No HTTP request, failed resource or uncaught page error was
observed. This establishes offline **evidence navigation**; the live app still
requires its local Python server.

Reproduce from the repository root using the commands in the manifest. The run
used Python 3.14.7, Playwright Python 1.65.2 and the installed Chrome. The
[model log](model.log) records three passing tests, including the 4,356-request
feasibility grid; the [browser log](replay.log) records both viewport passes.
To verify the deck again after installing the documented `playwright-core` version:

```sh
NODE_PATH=/tmp/moxi-evidence/node_modules node examples/personal-instrument/evidence/mode-graph/v12-current-2026-11-26/offline-check.cjs examples/probability-instrument/evidence/attachments/v08-current-2026-11-26
```

The deck uses the existing `scripts/demo_slideshows.py` loader/renderer directly,
without rebuilding any global index. To validate or render just this manifest:

```python
from pathlib import Path
from scripts.demo_slideshows import load_manifest, render
p = Path("examples/probability-instrument/evidence/attachments/v08-current-2026-11-26")
manifest = load_manifest(p / "manifest.json")
# Only when intentionally regenerating this scoped deck:
(p / "index.html").write_text(render(manifest))
```

[provenance.json](provenance.json) inventories the retained artifacts, source
hashes and verification commands. High confidence applies to these bounded
software sequences and their source/image identity. A failed replay at matching
path hashes or a failed integrity check would change that conclusion. No Mojo
fixture regeneration, physical touch/hardware, VoiceOver, human evaluation,
other browser engines, repository-wide suite, packaging or CI was run. No app
code, historical capture, global index/ledger, external post or push changed.
