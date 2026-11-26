# Synthetic pose stroke study · Moxi consumer

Build and start the local consumer from the repository root, then open
`http://127.0.0.1:8765` in Chrome:

```sh
mkdir -p dist
pixi run mojo build -I src examples/pose-stroke/scene.mojo -o dist/moxi-pose-scene
python3 -B examples/pose-stroke/serve.py
```

The pinned Mojo environment is required for the build. This replaces the former file-only demo;
opening `index.html` directly cannot render brushes. There is no fallback renderer.
The host binds only to loopback, serves three named assets, and accepts two bounded
widths at `/scene`. No camera, tracker, device, external account, or remote service
is used. The eleven numeric samples in `model.js` are authored synthetic inputs.

Advance samples with the button or Tab/Enter. “Hold clutch open” overrides the
recorded clutch until toggled again. Restart returns to sample one using the
applied calibration. Both brushes start at 12 px and apply changes in mapped width,
bounded to 4–28 px. Releasing the clutch or dropping below 0.70 confidence clears
the previous target. The first valid engaged sample anchors at the held width;
subsequent movement changes width again.

## Moxi boundary and mapping authoring

The same replay drives direct curl control and pose interpolation. Default
zero-spread relaxed/curled widths are 4/28 px; full-spread widths are 16/12 px.
The interpolation blends these pairs with spread. Curl is raised to an editable
response exponent (default 1) before either mapping uses it. This is a fixed
two-feature calibration grid, not learned poses or a hand tracker.

Edit the four corner widths and curl response, then choose **Apply calibration**.
Both widths stay fixed and control re-anchors at the current sample. **Revert
draft** or Escape restores the applied fields. **Save applied mapping** stores
one versioned calibration in browser localStorage; unapplied draft edits are not
saved. Reload starts the default replay; **Reopen saved mapping** explicitly
restores the saved calibration without a width jump. Storage belongs to that
browser profile and origin: keep the same host and port. Nothing is saved to the
repository or server. Unsupported or malformed saved mappings are rejected.
Every control supports Tab/Enter; Cmd/Ctrl+S saves, Cmd/Ctrl+O reopens.

For each operation, `replay.js` previews the controller state and POSTs the two
widths. `serve.py` invokes the compiled `scene.mojo`, which constructs each brush
with Moxi `ScenePath` and `Scene.append_typed_path`, then calls
`SvgSceneRenderer.render_scene`. The browser mounts those returned SVGs and only
then commits the operation. It does not author path geometry or set stroke widths.
CSS preserves round caps and non-scaling pixel widths across viewports. A failed
render retains the previous frame and strokes; retry repeats that operation.
If Moxi fails at startup, the brushes stay empty and Restart retries.

This uses the repository's real Moxi scene and SVG APIs in a native Mojo process;
it does not run Mojo in the browser or claim native window-host integration.
Domain mapping, replay, local storage and transport remain example-owned glue.
No shared framework API, dependency, or runtime was added.

## Reproduce checks and evidence

After the build:

```sh
node examples/pose-stroke/check.cjs
python3 -B examples/pose-stroke/test_consumer.py
python3 -B tests/demo_slideshows_test.py
```

The model check retains the original 100 exact replays per mode and seed-15
±0.01 perturbations: direct RMS/max 0.2271/0.8518 px; interpolated
0.1521/0.5915 px (1,100 widths per mode). It also checks calibration validation,
versioned save/reopen, edited response curves and no-jump recalibration. The four
consumer tests exercise actual HTTP → Mojo → Moxi SVG, compare endpoint bytes to
direct binary output, reject invalid requests/widths, and prove that a missing
renderer produces a failure rather than substitute brushes.

Use installed local Chrome and Python with Playwright for the browser regression
and [offline deck](../../artifacts/demo-slideshows/v15-pose-stroke/index.html):

```sh
uv venv --offline --python 3.12 .pixi/v15-verify
uv pip install --offline --python .pixi/v15-verify/bin/python playwright==1.65.2
# Trial with dirty source; output records the source hashes and dirty paths:
.pixi/v15-verify/bin/python -B examples/pose-stroke/gallery.py --output /tmp/v15-pose-trial
# Refresh checked-in evidence only after committing the example:
.pixi/v15-verify/bin/python -B examples/pose-stroke/gallery.py
```

The runner starts its own loopback host on an available port and uses a temporary
Chrome context. It blocks external page requests, compares all eleven states and
SVG widths to an independent table, verifies the Moxi binary hash and returned
markup, checks keyboard/focus and 390 px layout, applies and rejects calibration
edits, saves/reopens after reload and in a second tab, and exercises render failure
and retry. Eleven full-page PNGs cover replay, recovery, keyboard and authoring.
The resulting deck is verified offline. The linked
[browser record](../../artifacts/demo-slideshows/v15-pose-stroke/browser-record.json)
records source/binary hashes, revision, environment, viewports, scenario steps,
expected/observed outcomes and skipped checks.

## Acceptance limits

This closes the missing Moxi consumer for the bounded synthetic brush task.
It does not establish live-camera suitability, model/licensing choice, human
repeatability, live end-to-end latency, accidental activation, comfort,
multi-parameter fluency, or comparison with human slider performance. Full
Mojo/native suites, CI, other browsers and screen-reader use were not verified.
Saved mappings were checked across reload and a new tab, not an OS/browser restart.
The shared index and ledger are intentionally untouched for the parent task to
reconcile; this slice does not mark full V15 acceptance complete.
