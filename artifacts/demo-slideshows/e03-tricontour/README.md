# E03 tricontour: retained historical gallery and new status capture

Open [the relative six-frame deck](index.html). Every active frame is committed beside it, so a clean checkout can display and navigate the deck without rebuilding Moxi or obtaining local historical output.

Frame 2 is a **new capture from 2026-11-26**, generated from a clean checkout of the original dataviz revision `3fd5a7e7c622d6130c99a290b88c4fee039deab2`. The producer inspected the paths and contents of all 56 tracked `dataviz/**/*.mojo` files. A case-insensitive `tricontour` search found zero matches. The page records that unavailable reference; it is not an upstream chart or a parity result. The inventory digest, per-file hashes, lockfile hash, producer source hashes and generation time are in [reference-status-provenance.json](reference-status-provenance.json). The actual browser version, capture time, dimensions and image hash are in [reference-status-capture.json](reference-status-capture.json).

The other five PNG files and slide records are unchanged. The manifest's top-level revision `d7fa3ed563948860f4baf18bcc9f3eb279197135`, dirty source inventory, host, backend and runtime hash still describe their historical batch. They do not describe the new status page. Its producer ran from base `1f67c39` with the modified producer files explicitly identified by hash. The original batch's [reproduction notes](../plot-wave-b-c-review/REPRODUCE.md) remain historical too.

The original `02-reference.png` is withheld because it contains a private filesystem path. It is deliberately absent; neither it nor the historical embedded deck was used to make this replacement. The complete original slide record, including its browser metrics and SHA-256 `d4a281aa5be0d516ffc96e028d5b459a12aecdd969637a6a38288a46e28931d1`, remains in `manifest.json` under `historical_audit.missing_reference_capture`. That hash identifies the missing original, not the newly captured frame. The original manifest digest and its original scenario/reproduction text are also retained in `historical_audit`.

The separate [contour follow-up](../plot-contour-followup/README.md) uses the later dataviz revision `377b519e07f017d4a120b7fc3551f972a0b3fe16` and has a [real tricontour comparison](../plot-contour-followup/results.json). It does not supply a reference for this original-pin gallery.

## Validate or rebuild the delivered deck

From the repository root, use the existing strict manifest/PNG and delivered-deck validators. This is scoped to this gallery and does not regenerate the master catalog or other decks.

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=scripts python3 - <<'PY'
from pathlib import Path
from demo_gallery import Gallery, GalleryFormat, validate, validate_deck
p = Path('artifacts/demo-slideshows/e03-tricontour/manifest.json').resolve()
entry = Gallery(p.parent, GalleryFormat.STANDARD, p)
_, frames = validate(entry)
validate_deck(entry, frames)
print('Six frame hashes, PNG structures, manifest and relative deck: PASS')
PY
```

To regenerate only the relative HTML from the delivered manifest and PNGs:

```sh
PYTHONPATH=scripts python3 - <<'PY'
from pathlib import Path
from demo_slideshows import load_manifest, render
p = Path('artifacts/demo-slideshows/e03-tricontour/manifest.json')
(p.parent / 'index.html').write_text(render(load_manifest(p), relative_images=True))
PY
```

## Reproduce a new inventory-status capture

Set `E03_UPSTREAM_CHECKOUT` to a clean upstream checkout at the exact original pin. This mode checks that revision, the recorded Canvas dependency pin, a nonempty tracked Mojo inventory, and the absence of `tricontour` before writing a page. A dirty checkout, wrong revision, changed Canvas dependency or a matching symbol fails rather than producing a missing-reference claim.

```sh
python3 scripts/wave_c/upstream.py "$E03_UPSTREAM_CHECKOUT" \
  artifacts/demo-slideshows/e03-tricontour --reference-status-only
python3 -m http.server 8799 --bind 127.0.0.1 --directory artifacts/demo-slideshows
```

In another terminal with Python Playwright installed and local Chrome available:

```sh
python3 scripts/capture_plot_gallery_evidence.py --base-url http://127.0.0.1:8799/ \
  --plan artifacts/demo-slideshows/e03-tricontour/reference-status-capture-plan.json \
  --record artifacts/demo-slideshows/e03-tricontour/reference-status-capture.json
```

This plan captures only the new status page. A rerun creates a new generation timestamp and image hash; update only its active manifest record and associated provenance hashes, retain `historical_audit`, then rebuild and validate the relative deck. Do not run the full historical evidence batch to repair this one frame.

## Verification and limits

The new page was captured in local headless Chrome at 1280 × 800, DPR 1, with no page errors or failed requests. Its appearance was inspected for complete text and private paths. Browser navigation and clean-checkout validation are recorded in [verification.json](verification.json). Focused producer tests cover the inspected hashes and rejection of wrong pins, dirty source, changed Canvas dependency, a tricontour symbol and an empty inventory.

This repair does not rerun the five historical rendering/event-replay scenarios, compile Mojo, establish upstream parity, exercise physical input or run VoiceOver. The withheld screenshot and embedded historical deck were not inspected, modified or republished.
