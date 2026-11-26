# Restored original gallery captures

This recovery restores 379 original PNGs referenced by 52 existing gallery
manifests at revision `e378c63`. The image bytes are unchanged: these are historical
captures, not new screenshots or evidence that the current applications pass.
Publication review excluded an additional original; some catalog entries still
lack complete publishable inputs.

Provenance has two strengths:

- **320 originals match recorded historical checksums:** 311 in their gallery
  manifests and nine in the [linked-notebook evidence sidecar](../artifacts/demo-slideshows/linked-notebook/evidence.json).
- **59 originals have retained-deck corroboration:** their exact bytes appeared
  in retained recorded decks and matched the selected manifests' paths and
  dimensions, but no independent historical PNG checksum was recorded. A hash
  computed during recovery establishes copy integrity, not capture-time identity.

The second group comprises these manifests:

| Gallery | Restored originals |
| --- | ---: |
| [Browser FDG](../artifacts/demo-slideshows/browser-fdg/manifest.json) | 8 |
| [Math backends](../artifacts/demo-slideshows/d01-math-backends/manifest.json) | 27 |
| [Native lifecycle](../artifacts/demo-slideshows/native-lifecycle/manifest.json) | 11 |
| [Not implemented pattern](../artifacts/demo-slideshows/not-implemented/manifest.json) | 7 |
| [Text laboratory](../artifacts/demo-slideshows/text-laboratory/manifest.json) | 6 |

From the repository root, regenerate the recorded decks and master catalog with:

```sh
python3 scripts/demo_slideshows.py
```

The [master gallery](../artifacts/demo-slideshows/index.html) opens directly in a
clean checkout. The 56 new decks link to adjacent original PNGs and can travel
with their gallery directories. To generate a new deck in that format, pass
`--relative-images`. The default builder embeds the images. Use `--index-only`
to refresh the catalog from already delivered decks.

Run `python3 scripts/audit_demo_manifests.py` for capture and source status.
The repository-wide `python3 scripts/demo_slideshows.py --check` requires valid
capture evidence for every catalog entry and can fail for unavailable galleries.
Recorded image hashes and retained decks do not establish current source,
dependency or binary identity. See [the gallery guide](demo-slideshows.md) for
capture reproduction and validation limits.
