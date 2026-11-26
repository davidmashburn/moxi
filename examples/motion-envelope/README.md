# Motion phrase

A two-second flight shares its apex with a 220 Hz voice. The model has three knots. Between knots, horizontal position and height interpolate linearly. Height runs from zero to one and maps to oscillator gain as `0.25 × height`. Moving the apex later lengthens the climb and attack together while keeping the landing fixed at two seconds.

From the repository root, build a portable page and open it in Chrome.

```sh
PYTHONPATH=python python3 examples/motion-envelope/build.py /tmp/motion-phrase.html
open /tmp/motion-phrase.html
```

The build uses the checkout’s public Moxi `PlotSpec.add_line` and `Figure.to_svg` for both plots. The editor reads the plotted knots in SVG coordinates. A single Web Audio schedule sets the gain ramps and oscillator lifetime. Animation samples the audio context’s clock on every frame. The stopped inspection slider samples the same trajectory at a chosen score time.

Drag **Time to apex** or focus it and use the arrow keys in 10 ms steps. **Play phrase** auditions the draft, **Commit edit** writes one revision, and Escape discards the draft. **Set checkpoint** saves the authored apex and inspection time for the current page session. **Restore checkpoint** reinstates both. Reload starts a fresh session.

## Reproduce the individual checks

Use Python with Playwright installed and a local Google Chrome installation. The replay builds the page in a temporary directory and opens it directly. To keep the checked-in evidence, choose a fresh output directory ending in `motion-envelope`.

```sh
PYTHONPATH=python python3 examples/motion-envelope/check_browser.py --out /tmp/v06-check/motion-envelope
```

[Open the six-frame offline slideshow](../../artifacts/demo-slideshows/motion-envelope/index.html) or inspect the [individual timing results](../../artifacts/demo-slideshows/motion-envelope/timing.json). The manifest identifies the tested UI revision and host. The playback capture shows a live frame, so its exact marker position varies between runs.

| Scenario | Exercise and observed result |
| --- | --- |
| V06 timing edit and recovery | At 750 ms, drag the apex from 1000 to 1800 ms. Both markers descend while the authored revision stays zero. Escape during the drag restores the original geometry even after another move and release. Commit advances one revision. |
| I07 checkpoint | Perform a timing edit, commit, and set a checkpoint. Explore a 200 ms apex and commit it. Restore the checkpoint. Revision three recovers both 1800 ms and the 750 ms inspection position. |
| I14 stopped edit and replay | Play the stretched phrase twice. In each performance, both visible markers follow the piecewise-linear score at every sampled frame to within 0.001 SVG units. Both reach the same endpoint. Restore the checkpoint and the stopped markers return to their original edited coordinates. |
| I17 equivalent input | Drag to the upper bound, cancel, step one increment with Right Arrow, then press End. Keyboard and pointer previews produce identical marker coordinates. Both widths expose a named range control with milliseconds as its accessible value. |
| Browser and gallery | At 1280 × 800 and 390 × 844, the page fits horizontally and the interaction completes without a page error. With the browser context offline, the gallery accepts arrow keys, previous and thumbnail navigation, and decodes the narrow PNG. |

The five-action explanation has a separate uninterrupted control. Place the apex at 1370 ms, commit it, seek to 500 ms, seek to the apex, then seek to 1750 ms. In the second run, checkpoint immediately after action three, explore a committed 200 ms apex at 1900 ms, and restore before continuing. The recorded coordinates of both markers match the control exactly at all three inspection times. This covers stopped curve editing and replay. Recording a freehand coefficient gesture remains open for I14.

The checkout’s Python facade suite passed all 253 tests with `PYTHONPATH=python python3 -m pytest -q tests/python`. The native Mojo suite was skipped because this experiment uses the Python SVG exporter and browser audio adapter.

## Timing evidence

The reproducible audio probe uses the editor’s scheduler with a constant unit signal. This makes the gain envelope directly observable in the rendered audio samples. At each rate it schedules 40 phrases 2.125 seconds apart with five alternating apex times, then renders the full sequence a second time. The check finds the maximum sample in each phrase, compares its index with the score, and checks peak amplitude and silence at landing.

| Sample rate | Largest absolute peak error | Final peak error | Repeat |
| --- | ---: | ---: | --- |
| 44,100 Hz | 0.5 sample (11.34 µs) | 0 samples | All 40 peak records identical |
| 48,000 Hz | Under 0.000001 sample | 0 samples | All 40 peak records identical |

A separate probe observes the live oscillator start time and decodes elapsed time from the rendered gain marker. In four 48 kHz performances, the first frame crossing the apex landed 0.67–11.34 ms past it. The largest observed difference between SVG score time and the audio context clock at the observation callback was 5.34 ms (rounded up). The JSON retains each performance separately. These software-clock observations exclude speaker, display and physical input latency.

The synchronized edit has a concrete single-step effect. Stretching this fixture’s motion apex alone from 1000 to 1800 ms would leave an independently authored gain peak 800 ms early until a second edit corrected it. This arithmetic comparison leaves the timed manual-edit comparison and artist assessment of expressive usefulness open. Physical output synchronization, screen-reader operation and checkpoint persistence across sessions were outside the run. The parent maintains the global gallery and planning ledger.
