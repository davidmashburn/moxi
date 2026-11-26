# Synthetic room-temperature replay (V14)

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
