# D07 reviewed-source gallery — November 20, 2026

Regenerated from clean implementation `d7fa3ed563948860f4baf18bcc9f3eb279197135`:
**14/14 frames resolved, hash-checked and visually inspected**, at 2400 × 1580
pixels (1200 × 790 points, scale 2). The host was macOS 27.2 arm64 with
Mojo 1.1.0 (8189361e), Apple clang 21.0.0 and SDK 27.0. The native build and
replay exited 0, with deprecation/deployment-target warnings. Application source
and capture recipes were not changed.

These are actual AppKit `cacheDisplay` content-view **offscreen-render** captures
of the native AppKit/Metal application. The four-object assembly uses generated
synthetic surfaces. Events are supplied through the synthetic native queue and
text callback. This establishes neither physical input nor compositor/scanout
behavior, imported CAD support, large-assembly scaling or independent human
acceptance. The D05 production/performance gate remains **OPEN**.

The original checkout's candidate was inspected read-only and remains unchanged.
It referenced `bb4eaf944c7aa3bcac2cc61ee37ed99b1e4f2487`, had 24 source-hash
mismatches against reviewed main, and lacked all 14 PNGs. Its old validation
record was not adopted. The regenerated `manifest.json`, `provenance.json` and
`timing.json` belong to this checkout's reviewed source.

[validation.json](validation.json) records each action, expected result, observed
result, outcome and limits, along with environment/capture times and local
log/contact-sheet paths. The recipe records 153 source hashes and the aggregate
fingerprint in `provenance.json`; the shared [checker](../check_d04_d07.py)
supplements two native `.inc` files omitted by the recipe's suffix filter.
**155 source files match reviewed Git blobs**. Supplemental includes were
snapshotted before capture and unchanged afterward. The executable and every PNG
also have SHA-256 evidence.

Reproduce from the repository root:

```sh
python3 examples/spatial-assembly/gallery.py
pixi run d04-mindmap-replay
python3 artifacts/demo-slideshows/check_d04_d07.py --revision d7fa3ed
review_root=$(mktemp -d /tmp/moxi-gallery-check.XXXXXX)
ln -s "$PWD/artifacts/demo-slideshows/mindmap" "$review_root/mindmap"
ln -s "$PWD/artifacts/demo-slideshows/spatial-assembly" "$review_root/spatial-assembly"
python3 scripts/demo_slideshows.py "$review_root" --check
```

The recipe invokes the existing schema-v1 gallery validator/renderer and writes
its own ignored `index.html`. The scoped command validates only these two demos;
the master gallery and other candidates are outside this review. The extra
checker verifies capture provenance and PNG bytes, not visual acceptance.

All 14 outcomes were inspected: initial linked views; camera independence;
hierarchy preview and commit; surface measurement; clipping/plane movement/undo;
transform cancellation; numeric input; stale-worker rejection; right-view
disposal and recreation. Replay assertions substantiate hidden history, camera,
worker and geometry-sharing claims beyond the pixels. The screenshot of a
status message alone is not treated as proof of those internals.

Three frames have partial visual outcomes: in `07-plane-moved.png`,
`08-clip-undo.png` and `09-cancel-preview.png`, the explanatory status remains
“Retain X >= 0” after the offset moves to 0.25 or clipping is disabled. Offset
and enabled labels, rendered geometry and the undo assertion establish the
actual state. The stale explanatory text remains an application follow-up;
these are reviewed captures with a recorded visual issue, not a blanket UI pass.

The replay checks one shared 18,240-vertex / 583,680-byte geometry buffer, two
distinct targets, 60 sequential timing pairs (120 per-view samples), no mesh/UI
rebuilds during camera-only changes, and no idle submissions during its 0.3 s
check. `timing.json` retains the raw measurements and their limits. D04 capture
overlapped this run; timing was not isolated. The endpoint precedes AppKit
end-frame/composition/scanout, and paired phase sums exclude inter-call overhead.
These samples do not establish sustained frame rate, total memory residency,
energy, thermal or input-to-photon performance.

All frames were inspected directly as PNGs using labeled contact sheets.
Browser slideshow navigation, physical input/IME, VoiceOver, native chooser
flows, human acceptance, other viewports/hosts, fresh packaging, clean packaged
consumer suites, sanitizers, broad repository tests and GitHub CI were not run.
E02/E03/E04, D08 and the remaining manifest audit are still outstanding.
Replaying or changing sources requires a fresh visual review and validation
record; this dated review must not be reused for new captures.

Only metadata, this README and the shared evidence checker are deliverables.
PNG/HTML and builds remain ignored. Full logs, audit/check output and contact
sheets are local disposable attachments under
`/tmp/moxi-d04-d07-d7fa3ed-evidence/`. No commits, pushes or external writes were
performed.
