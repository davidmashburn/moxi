# Moxi execution debugger (I13)

From the repository root:

```sh
pixi run execution-debugger
```

Open <http://127.0.0.1:8173/>. **Open I15 episode** reads the existing
`examples/flight-recorder/evidence/episode.json`. **Reopen JSON** accepts the
same I15 v1 format, including its incomplete fixture. No generator, sensor or
async worker is invoked. Uploaded files stay in memory.

The normal entry point is `app.py`: in an already activated repository pixi
environment, `python3 examples/execution-debugger/app.py --port 18173` runs the
same application on another port. Every launch compiles `runner.mojo` against
this checkout's `src`, using Mojo 1.1 and the existing monotonic clock helper.
There is no screenshot-only renderer or alternate test UI.

Select an action to inspect its input, before/after state, logical source tick,
affected scope, work counters and frozen Moxi frame. The two `ValuePanel`
components run in real `TypedSubtreeExecutor`s; counters come from
`ExecutionWorkCounters`. The frame follows ColumnView → ColumnRuntime →
PaintCommands → Scene → SvgSceneRenderer. The browser hosts controls and the
resulting SVG; it does not simulate Moxi execution.

**Compare broad rebuild** reruns the same observations with an explicit extra
invalidation of the unrelated subtree after every action. It exercises a second
execution policy, not an arbitrary code hot-reload system or the App root-fallback
path. **Repeat localized replay** compares two independent executions of the
localized policy. The selected action and final state are compared; the tests
also check every retained frame. With the complete fixture, build totals
including mount are `[13, 2]` for localized and `[14, 14]` for broad. Both produce
reading 32 and peak 84 with identical frames.

Trace capacity is 1–32 records; a Mojo buffer evicts the oldest complete record
and frame when full. At capacity 5, 8 of the 13 replay action records are dropped.
This is independent of I15's 12 evicted source samples. Missing retained ticks
and absent async results are separate limitations. The incomplete I15 fixture
has no tick 13 or async result: it produces 11 sample actions and no peak action.

## Verification and reproduction

```sh
pixi run python3 -m unittest discover -v -s examples/execution-debugger
```

For UI tests, start the normal app, open a fresh page, then run in its browser
console:

```js
await (await import('/ui-tests.js')).runAll()
```

This exercises real controls, HTTP replay requests, file-input change events,
action selection, both comparison policies, capacity changes, incomplete and
malformed uploads, last-good recovery, empty captures and request limits. It
throws on failure and returns per-scenario results on success. The file-input
tests use a browser `File` and `DataTransfer`; native picker interaction is a
separate manual check. Reload before repeating the full sequence. Individual
scenarios are exported as `run(name)` for reproducible screenshot capture.

The [capture manifest](evidence/execution-debugger/manifest.json) gives the exact
viewport, source revision, screenshot actions and observations. The
[offline slideshow](evidence/execution-debugger/index.html) contains real browser
screenshots. [Verification](evidence/execution-debugger/verification.json)
retains scenario outcomes and environment information independently of the deck.
To rebuild the deck from the captured PNGs:

```sh
PYTHONPATH=scripts python3 - <<'PY'
from pathlib import Path
from demo_slideshows import load_manifest, render
path = Path('examples/execution-debugger/evidence/execution-debugger/manifest.json')
path.with_name('index.html').write_text(render(load_manifest(path)))
PY
```

## Limits

This closes the master's bounded I13 experiment. It is not a complete causal
profiler, task/dependency graph, allocation tracer, native debugger or arbitrary
application recorder. I15's source ticks are logical timestamps (10 ms/tick).
Async completion time and scheduling were not captured: the recorded result is
applied after retained samples with its source timestamp explicitly unknown.
Missing observations and results cannot be regenerated from a recording.

The UI reports a single monotonic measurement of dispatch/rebuild work and a
separate capture/SVG/serialization cost, plus trace-disabled control dispatch
time. The control must produce the same state and build totals. Frame capture
adds appreciable work; these measurements are diagnostic, not a stable tracing
overhead, throughput or latency benchmark. Paint counters include commands
accounted during rebuild and explicit frame capture. Initial mounts are excluded
from per-action deltas and included in total builds.

Browser verification covers the local browser and synthetic fixtures named in
the evidence. VoiceOver, physical instruments, other browser/OS combinations,
production workloads and broad performance benchmarks are outside this run.
