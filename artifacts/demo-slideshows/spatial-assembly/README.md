# D07 native gallery review — November 23, 2026

The three stale clipping captions from the November 20 review are repaired.
All 14 frames were recaptured from clean source
`49ebcddb48ae490a657f160220532b908e6a9d8d` and visually reviewed. Their 156 recorded
input hashes still match review checkout `158c67a`; the checker verifies the
committed blobs at the immutable capture revision. A later unrelated source
commit does not require replacing a capture whose complete recorded inventory
is unchanged.

These are real AppKit content-view `cacheDisplay` **offscreen-render** captures
of the native AppKit/Metal application at 2400 × 1580 pixels (1200 × 790 points,
scale 2). The host was macOS 27.2 arm64, Mojo 1.1.0 (8189361e), Apple clang 21.0.0
and SDK 27.0. The generated four-object assembly uses synthetic native queued
events/text callbacks. Physical input, imported CAD, large assemblies and
independent human acceptance remain unverified. The D05 production/performance
gate remains **OPEN**.

The refreshed captions now agree with the visible control and both views:

- [Plane moved](07-plane-moved.png) explicitly says `Retain X >= 0.25`.
- [Clipping undo](08-clip-undo.png) says clipping is disabled and full geometry
  restored; the shared control shows disabled at offset 0.
- [Uncommitted translation](09-cancel-preview.png) says clipping remains disabled
  and Escape discards the preview.

Native replay assertions additionally check enabled/offset state in both views,
undo and cancellation without a new history entry. All 14 reviewed scenarios are
listed in [validation.json](validation.json), with expected and observed results,
per-frame hashes, environment, source/binary verification and limits. The review
covers linked cameras, hierarchy preview/commit, measurement, clipping/undo,
transform cancel, numeric input, stale-worker rejection and target disposal and
recreation. Pixels alone do not establish hidden history or buffer ownership.

Reproduce from the repository root:

```sh
pixi run python examples/spatial-assembly/gallery.py
python3 artifacts/demo-slideshows/check_d04_d07.py --revision HEAD
review_root=$(mktemp -d /tmp/moxi-gallery-check.XXXXXX)
ln -s "$PWD/artifacts/demo-slideshows/mindmap" "$review_root/mindmap"
ln -s "$PWD/artifacts/demo-slideshows/spatial-assembly" "$review_root/spatial-assembly"
python3 scripts/demo_slideshows.py "$review_root" --check
python3 scripts/demo_slideshows.py "$review_root"
```

The last command renders ignored HTML from retained PNGs without a native build;
the capture recipe also writes its own `index.html`. Both galleries’ current
provenance, PNG and scoped schema checks pass. All 156 D07 inputs, including
native `.inc` files, match capture Git blobs. The executable and each PNG match
recorded SHA-256 evidence. Build/replay exited 0 with deprecated string-conversion
and deployment-target warnings. Reproduction after source changes requires new
provenance checks and visual review.

The replay checks one shared 18,240-vertex / 583,680-byte geometry buffer, two
distinct targets, 60 sequential timing pairs (120 per-view samples), no mesh/UI
rebuild during camera-only changes and no idle submissions during its 0.3-second
check. [timing.json](timing.json) preserves raw measurements. D04/D07 capture
processes did not overlap, but the machine was not isolated for benchmarking.
The endpoint precedes compositor/scanout and paired phase sums exclude inter-call
overhead. No sustained frame-rate, memory-residency, energy, thermal or
input-to-photon acceptance follows from these samples.

All 14 native PNGs are deliverables beside this record, retained by a scoped
ignore exception. HTML and binaries remain generated. Full logs and contact
sheets are disposable local attachments under
`/tmp/moxi-d04-d07-158c67a-evidence/`. The [catalog audit](../CATALOG-AUDIT.md)
separately reports current source evidence and clean-clone image availability
for the other manifests.

Browser slideshow navigation, physical input/IME, VoiceOver, native choosers,
independent human acceptance, other hosts/viewports, fresh packaging,
packaged-consumer suites, sanitizers, broad repository tests and GitHub CI were
not run. This bounded gallery repair does not close broader demo acceptance
gates.
