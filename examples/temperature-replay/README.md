# Moxi synthetic environmental replay (V14)

The Moxi consumer is an offline build of the normal `App[ReplayApp]` component
in `replay_app.mojo`. It builds and reconciles Canvas nodes, passes their actual
layout bounds to `PlotSpec` / `Plot`, and exports the resulting `Scene` with
`SvgSceneRenderer`. Both the temperature trace and artificial indoor CO2 proxy
are plotted by the real library from this checkout. The browser replays these
84 exported frames; it does not implement plot geometry or run Mojo/Wasm.
No shared application, plotting, task catalog or gallery files are modified.

From the repository root, with Pixi, Node and Python 3 installed:

```sh
node examples/temperature-replay/check.cjs
node examples/temperature-replay/sensor-check.cjs
node examples/temperature-replay/build.cjs
node examples/temperature-replay/native-check.cjs
python3 -m http.server 8859 --bind 127.0.0.1
```

Open `http://localhost:8859/dist/temperature-replay/`, or open
`dist/temperature-replay/index.html` directly after building. Serving is optional;
all application assets are local. The build records source hashes, the Moxi core
source digest, compiler version and Git revision in `build-manifest.json`, plus
the paired evaluation in `evaluation.json`. Build outputs are ignored. No new
dependencies, network services or credentials are needed at runtime.

The original temperature session is the initial view. Select Proxy B, C or D
to see the additional predictor and ablation. Slider, Play/Pause, automatic stop,
play from the end, Inspect and Restart retain the original timing behavior.
The full traces are visible for retrospective inspection; future samples do
not enter either forecast. A missing generated frame shows an explicit error
and removes the stale plot.
Vertical interval marks at each forecast target show the corresponding
calibration bounds; they are not filled areas extending to zero.

## Artificial predictor experiment

The target remains synthetic temperature 30 seconds ahead. The no-input arm is
the unchanged ten-second temperature trend. The candidate arm adds only
`beta * ((proxy_at_origin - 650) / 180)`. The proxy is a constructed indoor CO2
analogue in arbitrary units, **not measured or calibrated ppm**. Its construction
intentionally anticipates future temperature curvature. A single residual
coefficient is fit by least squares on training sessions T1–T3 (63 origins),
then frozen. Separate sessions A1–A2 (42 origins) set each arm's nearest-rank
p90 absolute-residual band. Entire sessions B–D (63 origins) are held out from
both operations. All sessions contain 25 ten-second samples over 240 seconds.

The comparison uses the same eligible timestamps and temperature history in
both arms. A missing proxy makes the candidate unavailable and excludes that
origin from both arms' paired metrics; it never silently becomes a zero input.
Timestamp joins drop a missing previous/target sample. Tests poison future
values to verify that forecasts do not consume them. No coefficient, threshold
or band is tuned on test outcomes.

| Held-out session | Without proxy MAE (°C) | With proxy MAE (°C) | Δ (with − without) | Band hits (without / with) |
| --- | ---: | ---: | ---: | --- |
| B, constructed coupling | 0.04693 | 0.01308 | −0.03385 | 20/21 / 18/21 |
| C, constructed coupling | 0.04944 | 0.01267 | −0.03676 | 19/21 / 19/21 |
| D, reversed coupling | 0.04475 | 0.08600 | +0.04124 | 18/21 / 4/21 |

The proxy helps under the designed coupling and hurts under reversed coupling.
This is an implementation/ablation exercise, not evidence for real-world
chemical prediction. Overlapping windows are not independent trials; three
synthetic test sessions do not establish statistical significance or deployment
readiness. The residual bands have no real-world coverage guarantee.
True real-world chemical prediction, instrument calibration, independent field
evaluation, and robot/device integration gates remain explicitly **open**.
There are no real biological data, live instruments, or autonomous controls.

## New consumer verification

The fresh [Moxi sensor evidence](../../artifacts/demo-slideshows/v14-moxi-sensor/index.html)
records the tested source hashes, browser, viewport, steps, expected/observed
results, and captures separately from the original V14 evidence. The browser
check source is `browser-check.js`: execute it in the built page, then call
`await checkMoxiReplay()`. It checks the original drift miss, playback lifecycle,
all held-out sessions, aggregate scores, and missing-frame recovery. Captures
also cover a narrow viewport and reload. VoiceOver/screen-reader trials, native
window interaction and all real instrument/field/device gates remain unverified.
To regenerate the new captures with Playwright and local Chrome available, run
`node examples/temperature-replay/capture-moxi.cjs` after committing the example
sources and rebuilding. The runner requires matching source hashes and revision,
uses an offline context, checks the resulting deck, and writes only its own
`v14-moxi-sensor` evidence directory.

## Original standalone temperature replay and evidence

The original `index.html`, model, playback, checks, capture runner, and four-slide
evidence below are retained unchanged from `3689e17`.

Open `index.html` directly in a browser. The prototype runs offline. Use the
range control's arrow keys to step ten seconds, Play to advance, Inspect
reversal to jump to the cooling transition, and Restart to return to 10 s.

Each generated session spans 240 seconds. At each eligible origin, the model
extrapolates the last ten seconds of temperature change by thirty seconds.
Persistence holds the origin temperature constant. The shaded interval links
the origin and target to distances along a fictional straight transect at
0.2 m/s. The full trace is visible for retrospective inspection. Only the
previous and current samples enter the forecast.

Session A sets a symmetric error band using nearest-rank p90 of its 21 absolute
forecast errors. Session B has a different initial temperature and oscillation
phase and introduces cooling after 120 s. Its 21 overlapping forecast windows
are held out from calibration. The band describes synthetic residuals and has
no real-world coverage guarantee. No real timestamped sensor/outcome or route
recordings, hardware calibration, chemical-input comparison, independent field
evaluation or robot control are provided.

Run `node examples/temperature-replay/check.cjs` from the repository root for
the timing, missing-sample, baseline, held-out evaluation and drift checks.

## Offline UI evidence

Open the [four-slide deck](../../artifacts/demo-slideshows/v14-room-temperature/index.html)
or inspect the [capture manifest](../../artifacts/demo-slideshows/v14-room-temperature/manifest.json)
for individual PNGs, expected states and the captured source revision. The
2026-11-26 UTC run used a fresh offline Chrome context on a local file URL with
a 960 × 900 viewport at 1× scale. The four frames passed their visible-state
checks. The runner also verified timed playback, automatic stop, restart from
the end, the drift miss after reloading at 390 × 844, and slideshow navigation
and image decoding offline. Physical keyboard, screen-reader and independent
human usability trials remain open.

To recapture, make a local copy of Playwright and its playwright-core dependency
available via Node's module search path, with Chrome and Python 3 installed.
From the repository root run `node examples/temperature-replay/capture.cjs`.
It validates the manifest and regenerates only this example's deck.
