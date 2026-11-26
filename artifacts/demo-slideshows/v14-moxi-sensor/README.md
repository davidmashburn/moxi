# Moxi synthetic sensor replay evidence

This deck supplements the unchanged `v14-room-temperature` evidence. The normal
Moxi `App[ReplayApp]` lays out real canvases; `PlotSpec` / `Plot` constructs both
traces and forecast target intervals; `SvgSceneRenderer` exports the frames.
The browser performs playback of those exports. It does not implement plotting
geometry or execute Mojo/Wasm.

`manifest.json` names the tested source revision, capture environment, actions,
expected states and seven screenshots. `verification.json` records browser
observations, source hashes, the Moxi source digest, compiler, viewport and
skipped checks. `evaluation.json` preserves the paired synthetic results.
All nine recorded browser scenarios passed at source revision `688bef1` in
Chrome 158.0.8127.37. The seven captures were visually inspected, including
the target interval bounds, original miss, shifted failure and recovery.

The deterministic proxy is an indoor CO2 analogue in arbitrary units, not a
measurement or calibrated ppm. T1–T3 fit one residual coefficient; A1–A2 set
error radii; B–D are held out. Both arms share the same temperature forecast and
eligible origins. The proxy lowers MAE in B and C but raises it in reversed
coupling session D. No real chemical performance or significance is inferred.

The original timestamp/alignment check, synthetic split/leakage/ablation check,
84-frame build and native geometry/boundary check were run separately and all
passed. Native checks include real sensor-geometry consumption,
two-bound intervals and seven invalid-input boundaries. Browser
verification covers original playback and cooling miss, all three comparisons,
missing-frame failure and recovery, keyboard input, a narrow reload and offline
deck navigation. The capture runner uses a fresh Chrome context with networking
disabled and checks for script errors, failed requests and remote requests.

Reproduce from the repository root with Pixi, Node, Python 3, Playwright and
local Chrome available:

```sh
node examples/temperature-replay/check.cjs
node examples/temperature-replay/sensor-check.cjs
node examples/temperature-replay/build.cjs
node examples/temperature-replay/native-check.cjs
node examples/temperature-replay/capture-moxi.cjs
```

The capture runner requires committed, unchanged example sources and a matching
build revision. It writes only this evidence directory; shared catalogs remain
untouched. The HTTP preview cannot open file URLs, so the offline checks use
local Chrome directly.

Native-window interaction, VoiceOver/screen-reader testing and the repository-wide
test suite were not run. True real-world chemical prediction, instrument
calibration and field/robot/device gates remain open. There are no real
biological data, live instruments, or autonomous controls.
