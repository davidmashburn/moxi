# E04 native extension screenshot evidence

This sequence shows actual clean-installed command results and actual native
renderer outputs in T3 collaborative browser evidence pages. It is not a native
window capture or terminal emulator. VoiceOver remained paused.

Build and test with the commands in
[the experiment README](../../../experiments/python-native/README.md). The check
writes reports and exported images here; command logs are in
`/tmp/moxi-e04-*.log`. Then:

```sh
python3 experiments/python-native/evidence.py pages
python3 -m http.server 8764 --bind 127.0.0.1 \
  --directory artifacts/demo-slideshows/e04-python-native
```

In T3, call `preview_status`, then `preview_open` for
`http://127.0.0.1:8764/01-import.html`. Set a 1400×1100 CSS viewport with
`preview_resize`. For each page below, navigate, wait for images to load, and
save `preview_snapshot({save:true})`. Copy the returned screenshot bytes
unaltered into the matching PNG filename. Check the recorded image dimensions;
the captured host uses device scale 2. T3 saved 1280×1006 PNGs despite the
1400×1100 CSS viewport and device scale 2. Those returned bytes were copied
unchanged; the manifest records both browser and saved-image dimensions.

1. `01-import.html` → `01-import.png`: installed import/version/copy policy.
2. `02-render.html` → `02-render.png`: canonical native SVG and PNG result.
3. `03-comparison.html` → `03-comparison.png`: existing facade comparison.
4. `04-recovery.html` → `04-recovery.png`: malformed and repeated lifetime checks.
5. `05-packaging.html` → `05-packaging.png`: inspected dependencies, timings, gate.

```sh
python3 experiments/python-native/evidence.py finalize
python3 tests/demo_slideshows_test.py
```

Finalization uses `scripts/demo_slideshows.py` to validate the version-1 manifest
and render only this demo's self-contained `index.html`. It does not regenerate
the parent-owned root gallery. All images, exported files, evidence JSON/logs,
and generated HTML remain ignored local artifacts; the compact manifest and
this recipe are reviewable. Manifest hashes identify the actual dirty source,
compiler, object, wheel, runtimes, reports, exported artifacts and screenshots.

The production gate remains open. No screenshot establishes redistribution
permission, cross-platform/abi3 support, sanitizer coverage, screen-reader
behavior, or scientific/rendering parity with the facade.
