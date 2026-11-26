# D08 native world-panel slideshow

Captured from clean public integration `85b915424e7a7de85b18c0ccea46195d3617948c`.
The [local offline deck](index.html) contains six actual 2000×1420 AppKit
`cacheDisplay` captures of the native/Metal replay. All six full images were
inspected. The third state now shows the repaired projected text range.

[REVIEW.md](REVIEW.md) records the range regression, six outcomes, source and
binary checks, offline navigation, and limits. [review.json](review.json) binds
those observations to image and log hashes. The separate
[historical finding](HISTORICAL-GALLERY-AUDIT.md) covers the remaining catalogs
and required master gallery; no shared index or ledger was changed.

Verify the retained local bundle from repository root:

```sh
python3 artifacts/demo-slideshows/spatial-world-panel/verify.py
```

Regenerate the native evidence on the intended clean source revision:

```sh
pixi install --locked
python3 artifacts/demo-slideshows/spatial-world-panel/capture.py
```

[capture.py](capture.py) retains the published gallery assertions and bounds the
build at 900 seconds and each native gallery replay at 120 seconds. A timeout
kills the complete process group. A one-second descendant-process exercise
verified that cleanup. Run the focused checks with the same bounded runner:

```sh
python3 - <<'PYTHON'
import runpy
runner = runpy.run_path('artifacts/demo-slideshows/spatial-world-panel/capture.py')
runner['run'](['bash', 'examples/spatial-world-panel/check.sh', '--skip-build'],
              '/tmp/moxi-d08-checks.log')
PYTHON
```

The actual recorded check run passed in 181.89 seconds under that 900-second
suite bound. It includes the packaged replay, so its captures are also bounded.
To check the generated HTML, install Playwright 1.65.2 in an isolated environment
and run [check_deck.py](check_deck.py) with that Python. It opens the actual
`file://` deck in installed Chrome, offline, with a 90-second overall bound:

```sh
python3 artifacts/demo-slideshows/spatial-world-panel/check_deck.py
```

A recapture or browser-check rerun invalidates the corresponding existing visual
review and hashes. Inspect the new full images/screenshots and refresh the review
record before running `verify.py`.

[provenance.json](provenance.json) records 194 source hashes, clean scoped status,
toolchain and executable hash. [manifest.json](manifest.json) records the six PNG
hashes. [timing.json](timing.json) retains three cold and 90 warm samples without
a performance guarantee. PNGs, generated HTML and the binary are deliberately
ignored local artifacts; compact metadata, scripts and portable logs are tracked.
A fresh checkout must regenerate or receive the checksum-matching local bundle.

Forward range projection passes; native world input sessions and selection remain
incomplete, and world semantics remain suppressed. World promotion stays
[rejected](decision.json). Physical IME, VoiceOver and human acceptance were not
exercised. See the [experiment README](../../../examples/spatial-world-panel/README.md).
