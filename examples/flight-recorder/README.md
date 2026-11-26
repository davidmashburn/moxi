# Experiment flight recorder (I15)

Run from the repository root with Python 3.9+ and the Moxi Python reference renderer.

```sh
PYTHONPATH=python python3 examples/flight-recorder/app.py
PYTHONPATH=python python3 -m unittest discover -v -s examples/flight-recorder
```

Open http://127.0.0.1:8175/ and choose **Capture episode**. Inspect ticks with the slider and arrow keys. Save the JSON, reload the page, and reopen the downloaded file. Repeat with **Omit async result** selected. Edit a copy of a file to remove one sample and reopen it to see the missing tick. The server processes episodes in memory and never writes uploaded files.

## Episode contract

The version-1 synthetic probe runs 24 steps of a seeded integer generator. The deque retains the latest 12 observations. Tick 16 submits an immutable snapshot of readings 5–16 to a separate worker for a peak calculation. The recorder continues sampling and joins the worker before sealing the episode. The omission fixture drops the returned value during capture. Its request identity survives.

An episode identifies the schema, instrument, seed, logical clock, retention capacity, emitted and evicted counts. Each sample is a [tick, reading] pair. A result refers to its request by ID. Missing sample ticks inside the retained interval and a null or absent result are displayed as gaps. A consumer such as I13 can import inspect_episode or read the JSON independently. The v1 reader accepts this fixed instrument configuration and caps input at 8192 bytes.

Reopen renders stored readings through Moxi PlotSpec and Figure. It never invokes the generator or the peak worker. The probe records logical sample times, not thread scheduling or wall-clock completion times. Historical readings lost to eviction, physical sensor state and alternative experiment outcomes are outside replay coverage.

## Verification record

The [capture manifest](evidence/flight-recorder/manifest.json) records the source revision, browser, fixture, actions and expected observations. All four scenarios passed in the collaborative browser on November 26, 2026 UTC. The [slideshow](evidence/flight-recorder/index.html) includes the observed states. The two JSON files under evidence are reusable reopen fixtures. Human usability, assistive technology, physical input and other browser/OS combinations have not been exercised. The source is synthetic and has no physical instrument integration.

To validate the PNG dimensions and regenerate the individual offline slideshow from the repository root:

```sh
PYTHONPATH=scripts python3 - <<'PY'
from pathlib import Path
from demo_slideshows import load_manifest, render
path = Path("examples/flight-recorder/evidence/flight-recorder/manifest.json")
path.with_name("index.html").write_text(render(load_manifest(path)))
PY
```
