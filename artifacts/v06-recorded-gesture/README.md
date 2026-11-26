# V06 recorded-gesture verification

The normal author can record a bounded height gesture, make a stopped point edit,
commit it, and repeatedly replay the same curve as flight motion and sound gain.
This extends the entire ancestral public feature through `4c486de`, brought into
the isolated `t3/record-replay-gestures` checkout with `git merge --no-edit 4c486de`
(a clean fast-forward). No planning ledger, shared gallery index, or existing
gallery evidence was edited. No push or external write was performed.

## Tested environment and provenance

Captured 2026-11-26T03:10:18.558951+00:00 in **Darwin 27.2.0 · Chrome 158.0.8127.37 · Playwright**.
The Python SVG builder made a portable file from this checkout, and Playwright
opened `file://<temporary directory>/index.html#measure` in installed Chrome.
The role was a local author with synthetic input and no account. Viewports were
1280 × 800 and 390 × 844 at device scale 1. The narrow run used desktop Chrome
with a narrow viewport, not a physical touch device.

[Machine-readable evidence](evidence.json) records base HEAD `4c486deb2556a4b064f827f2f7fb63321c556c13`,
the dirty source state at capture, SHA-256 hashes of all five builder/UI/model/browser
regression files, the actual recorded heights, PCM hashes, frame measurements,
and screenshot names. Capture preceded the local commit. The hashes were checked
against the final source before committing; the code under test matches the source
in that commit. Only documentation and evidence were added after capture. Each
width creates its own take through ordinary controls; different takes need not
have identical PCM across widths. Repeatability is checked within the same take.

## Scenarios

All rows passed. Screenshots establish appearance; script assertions establish
curve identity, source stop calls, repeated audio samples, and recovery.

| Scenario and steps | Expected result | Observed result and evidence |
| --- | --- | --- |
| Record: set Height to 0.2, start, drag to about 0.85 after 250 ms of score time, then Home + 12 Right Arrows after 750 ms | Authored revision remains zero; own bounded curve controls both media; capture ends at 2 s | 201 samples, heights 0–1, endpoints zero, matching flight/gain heights. [Desktop recording](1280-recording.png), [narrow recording](390-recording.png) |
| Stopped edit: seek to 750 ms, set Height to 0.73, apply, commit | Change exactly one sample, then commit the entire curve once | Other 200 samples unchanged; revision one, no dirty draft. [Desktop committed](1280-edited-committed.png), [narrow committed](390-edited-committed.png) |
| Inspect at 0/350/750/1250/2000 ms twice | Identical stopped poses; endpoints cannot be edited away from silence | Exact repeated marker coordinates at all five times; endpoint edit button disabled |
| Replay twice at each width | Markers follow the authored curve using the audio clock and reach the same endpoint | Four performances, at least ten observed frames each; largest marker error 0.000414 SVG units, largest observed clock difference 5.333406 ms. These are browser/software observations |
| Render the UI-created curve twice at 44.1 and 48 kHz using the production gain scheduler | Identical PCM for repeat; plotted height × 0.25 agrees with audio; silence before and after | All 99,225 / 108,000 samples identical within each repeated pair; largest gain error 2.23e-08; pre-start and post-stop samples zero. [Per-take metrics and hashes](evidence.json) |
| Cancel a replacement by button, Escape while dragging with subsequent movement, injected pointercancel, and injected window blur with subsequent movement | Stop the source, restore previous curve, inspection and height; no late callback overwrites the restored take | Complete state and control value restored; source receives a stop; state remains restored past the old capture duration. [Desktop cancellation](1280-cancelled-replacement.png), [narrow cancellation](390-cancelled-replacement.png) |
| Stop replay; cancel replacement over an uncommitted point edit; retry a complete replacement and discard it | Restore the precise stopped state, preserve the unsaved point edit, and retain the authored take on discard | Passed at both widths, including a successful recording after cancellation |
| Save authored gesture at 750 ms; commit flight alternative; restore checkpoint | Restore full gesture and inspection time | Revision three, exact restored curve, 750 ms pose. [Desktop recovery](1280-checkpoint-restored.png), [narrow recovery](390-checkpoint-restored.png) |
| Reject audio resume; hold resume pending, cancel, resolve stale promise, retry; inject hidden-page transition | Preserve prior uncommitted draft on failure/cancel, prevent stale voice, allow retry and cancel hidden performance | Passed in separate narrow pages with injected API/event boundaries; no page errors. [Pending audio](390-pending-audio.png), [unavailable audio](390-audio-unavailable.png) |
| Reload; inspect both layouts | Fresh session; controls fit and remain usable | Original flight/revision zero restored; no horizontal overflow, page errors, or clipped controls. [Desktop ready](1280-ready.png), [narrow ready](390-ready.png) |

The test waits for displayed audio-clock score time before changing Height, rather
than treating wall time as score time. The grid uses a 20 ms future scheduling
lead rounded to 10 ms; that is implementation behavior, not a physical latency
measurement. Capture, replay, and stopped inspection use one score. No independent
motion/audio timelines are authored.

## Commands and results

From the repository root, reproduce with the temporary environment used for verification:

```sh
uv venv /tmp/moxi-v06-gesture-venv
uv pip install --python /tmp/moxi-v06-gesture-venv/bin/python playwright pytest numpy
node --test examples/motion-envelope/test_gesture.mjs
PYTHONPATH=python /tmp/moxi-v06-gesture-venv/bin/python -m pytest -q -rs tests/python
PYTHONPATH=python /tmp/moxi-v06-gesture-venv/bin/python examples/motion-envelope/check_gesture_browser.py --out /tmp/moxi-v06-gesture-evidence-final
PYTHONPATH=python /tmp/moxi-v06-gesture-venv/bin/python examples/motion-envelope/check_browser.py --out /tmp/moxi-v06-final-compatibility/motion-envelope
git diff --check
```

- [Five model tests passed](model-tests.txt): bounds, future-prefix preservation,
  stopped edits, equivalent automation across absolute starts, original flight.
- [All 253 Python facade tests passed](python-tests.txt). The initial environment
  lacked optional NumPy; the complete result above followed its installation.
- [The new browser regression passed](gesture-browser-check.txt) all scenarios above.
- [The original browser regression passed](compatibility-check.txt): desktop/narrow
  apex controls, input equivalence, five-action checkpoint lesson, four live
  performances, offline gallery navigation and 2 × 40 scheduled peaks at each rate.

The shared preview opened this page on localhost, but two snapshots failed with
`Preview automation snapshot timed out after 15000ms.` The successful verification
used the example's installed-Chrome/Playwright workflow, and its captures were
visually inspected. The preview tab was closed.

## Coverage left open

Confidence is **high** for this bounded, session-local authoring flow in the tested
Chrome build, based on ordinary-control browser checks, full repeated PCM, and
focused model tests. A failure to preserve a take or disagreement between the
recorded score and audio on another supported browser would lower that confidence.

Outside-application speaker/display/input physical timing and artist trials remain
open. There is no claim of expressive benefit, timed comparison with independently
authored curves, or successful real performance. Screen-reader operation, physical
touch-device behavior, other browsers and cross-session persistence were not
verified. Reload deliberately starts a new session. Native Mojo/build tests were
skipped because this change is limited to the Python SVG builder/browser adapter;
no native runtime code changed.
