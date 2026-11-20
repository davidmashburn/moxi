# E04 native extension screenshot evidence

This sequence shows actual clean-installed command results and native renderer
outputs in browser evidence pages. The wheel runs in a fresh venv on the build
host; this is not a fresh-host install or native-window capture. VoiceOver remains
unexercised. See [the dated scenario review](REVIEW.md) for outcomes, the comparison
with the previous manifest and the evidence limits.

From the repository root at `d7fa3ed`, use
[the experiment's build prerequisites and contract](../../../experiments/python-native/README.md):

```sh
# Optional: export MOXI_E04_MANIFEST=/path/to/an/already-installed/pixi.toml
bash experiments/python-native/build.sh > /tmp/moxi-e04-build.log 2>&1
bash experiments/python-native/check.sh > /tmp/moxi-e04-clean-check.log 2>&1
python3 experiments/python-native/evidence.py pages
python3 -m http.server 8764 --bind 127.0.0.1 \
  --directory artifacts/demo-slideshows/e04-python-native
```

In T3, call `preview_status`, then `preview_open` for
`http://127.0.0.1:8764/01-import.html`. Set a 1400×1100 CSS viewport with
`preview_resize`. For each page below, navigate, wait for images to load, and
save `preview_snapshot({save:true})`. Copy the returned screenshot bytes unaltered
into the matching PNG filename. Read viewport, device scale, user agent, document
height and image-load state with `preview_evaluate`; inspect snapshot diagnostics.
Increase the viewport height and recapture if any content is cut off. Do not reuse
the previous manifest's device scale or saved-image dimensions.

1. `01-import.html` → `01-import.png`: installed import/version/copy policy.
2. `02-render.html` → `02-render.png`: canonical native SVG and PNG result.
3. `03-comparison.html` → `03-comparison.png`: existing facade comparison.
4. `04-recovery.html` → `04-recovery.png`: malformed and repeated lifetime checks.
5. `05-packaging.html` → `05-packaging.png`: inspected dependencies, timings, gate.

If T3 snapshot capture is unavailable, use a connected Playwright browser in an
isolated context. The reviewed run used this fallback after two T3 snapshot
timeouts and an unavailable Chrome browser access host. Its screenshots use CSS
scale at an actual 1400×1100 viewport and DPR 1, producing 1400×1100 PNGs. Through
`browser_run_code_unsafe`, set `page.setViewportSize({width:1400,height:1100})`
and run the following for each stem (set `gallery` to the absolute gallery path):

```js
await page.goto(`http://127.0.0.1:8764/${stem}.html`, {waitUntil:'load'});
await page.evaluate(async () => {
  await document.fonts.ready;
  await Promise.all([...document.images].map(image => image.decode()));
});
// Record actual viewport/DPR, page errors, image states and content bounds.
// Increase height and recapture all frames if content extends below the viewport.
await page.screenshot({path:`${gallery}/${stem}.png`, scale:'css', fullPage:false});
```

Visually inspect all five saved PNGs. Retain the actual capture metadata in ignored
`capture.json`, using this shape (repeat the frame entry for all five stems):

```json
{
  "captured_at": "<UTC ISO timestamp>",
  "browser": "<navigator.userAgent>",
  "viewport_css": [1400, 1100],
  "device_pixel_ratio": 1,
  "note": "<actual screenshot scaling/copy method>",
  "frames": {
    "01-import": {
      "sha256": "<saved PNG SHA-256>",
      "page_sha256": "<HTML SHA-256 at capture>",
      "page_errors": [],
      "images": [],
      "scenario_outcome": "pass",
      "visual_outcome": "pass",
      "visual_observation": "<what was seen and any limits>"
    }
  }
}
```

For pages with images, each `images` entry records `complete` and `natural_width`
from the loaded image element. Keep per-frame viewport, document height, resource
URLs/statuses and capture timestamp as additional fields. Outcomes are `pass`,
`partial` or `blocked`; record scenario limits even when the capture itself passes.
Hash with `shasum -a 256 <file>` or Python `hashlib.sha256`.

```sh
python3 experiments/python-native/evidence.py finalize
python3 experiments/python-native/evidence.py verify
python3 tests/demo_slideshows_test.py
python3 experiments/python-native/test_build_notices.py
```

Finalization uses `scripts/demo_slideshows.py` to validate the version-1 manifest
and render only this demo's self-contained `index.html`. It does not regenerate
the parent-owned root gallery. All images, exported files, evidence JSON/logs,
and generated HTML remain ignored local artifacts; the compact manifest and
this recipe and the scenario review are reviewable. `verify` checks all recorded
build inputs against the checkout and revision, the object/wheel and installed
binary hashes, facade source/wheel/install bytes, all eight exports, proof sources,
report hashes and every referenced frame/page. Keep the build and retained clean
consumer venv in place for this local check. Capture-tool changes are distinct from
the verified native/facade inputs. Regenerating pages invalidates their captures;
do not finalize until the corresponding screenshots have been recaptured/reviewed.

The self-contained [local slideshow](index.html) embeds all five PNGs. The HTML,
PNGs, JSON/log reports and export files are ignored, local integration artifacts;
they must be copied along with the tracked manifest if another checkout needs the
images. No common gallery index or handoff is regenerated by this recipe.

The production gate remains open. No screenshot establishes redistribution
permission, cross-platform/abi3 support, sanitizer coverage, screen-reader
behavior, or scientific/rendering parity with the facade.
