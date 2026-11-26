# I02 matrix instrument verification

The bounded I02 experiment is implemented in
[`examples/matrix-instrument`](../../../examples/matrix-instrument/README.md).
The numeric editor and keyboard basis controls share one matrix, selection and
undo/redo history. Entries accept three decimal places in [−3, 3]. Singular and
zero matrices remain editable; recovery does not require an inverse.

Open the [11-capture navigable deck](index.html). These are real screenshots of
the served consumer, using the repository's `moxi.PlotSpec` / `moxi.plot` Python
reference renderer. The deck is an offline record, not the running editor.

## Tested environment

- Public base: `033596ddb576b09b48234733b45a283b4c3fecae`, verified against
  `origin/main` before implementation. No private math-branch ancestry.
- Tested source commit: `60ee5659c56bf29deae9d8624012185b0a4ec29c`. The source
  was committed and clean during the retained capture run. The eight tested
  source files and Moxi renderer have exact hashes in [manifest.json](manifest.json).
  The ninth source-directory file is the consumer README.
- Capture time: `2026-11-26T03:54:10.868071+00:00`.
- Python 3.13.11; installed Chrome 158.0.8127.37 through Playwright on
  macOS 27.2.1 arm64. Desktop viewport 1366×1100; narrow viewport 390×844.
- Normal HTTP UI at `http://127.0.0.1:65220/`, served from this checkout by the
  consumer's own handler. Test fixtures use synthetic matrices, no login or
  external accounts. The server was closed after the run.
- VoiceOver stayed paused. No assistive-technology checks were performed.

## Acceptance and observations

The scope follows `ideas/i02-tangible-mathematics.md` on public
`project-planning` at `ea6f70dc538923970485b7ef4e729d03b3295ebf`, its deferred
implementation row, and the I02 crosswalk in
`d1da7c0:artifacts/demo-slideshows/concept-scenarios.md`. That crosswalk identified
direct matrix edits, keyboard movement, selection and shared undo as missing
from the earlier oscillator demonstration.

| Scenario and steps | Expected and directly observed result | Outcome / capture |
| --- | --- | --- |
| Apply row-major entries 1.25, 0.5, 0.25, 2 | Entries, basis and unit square agree; determinant 2.375; last edited column v selected | Pass · [numeric](02-numeric.png) |
| Click plotted u; press Right and Shift+Up | u becomes (1.35, 0.26), determinant 2.57; focus and selection stay on u | Pass · [keyboard](03-keyboard.png) |
| Undo both movements and the numeric edit; redo | One history restores entries, geometry and selected column; three redo steps available after undo | Pass · [shared undo](04-shared-undo.png) |
| Apply u=(2,2), v=(1,1); focus v and press Up | Determinant zero and explanatory collapsed frame; movement recovers to determinant 0.2 | Pass · [singular](05-singular.png), [recovered](06-recover.png) |
| Apply zero and near-singular matrices | Separate controls remain reachable at coincident endpoints; exact entries preserved; rank explanation changes without snapping | Pass · [zero](07-zero.png), [near singular](08-near-singular.png) |
| Enter invalid drafts; try movement; Escape; hit bounds | No partial commit or drift; draft blocks movement/history; discard and valid edits recover | Pass · browser assertions in manifest |
| Block a render; retry; release an older response after a newer edit | Stale geometry/metrics hidden; values/history retained; retry recovers; newest matrix wins | Pass · [failed render](09-network.png), browser assertions |
| Repeat singular recovery and undo at 390×844 | Stacked controls fit without horizontal overflow; selection, keyboard changes and undo agree | Pass · [narrow singular](10-narrow-singular.png), [narrow recovery](11-narrow-recovery.png) |

The complete suite passed **15 tests**: 10 Chrome UI scenarios and five model,
projection and HTTP checks, in 14.976 seconds. It also checks 100 exact fine
steps, redo branching, orientation reversal, keyboard-only entry/Tab flow,
rejected mismatched responses, and the documented reload reset to 2I. No
uncaught page errors were recorded. Aborted superseded render requests and the
deliberately blocked request are retained in the manifest as expected failures.

The final desktop keyboard, desktop singular, failed-render and narrow recovery
captures received visual inspection for layout, legibility, focus/selection and
state agreement. The browser tests assert behavior independently of screenshots.
JavaScript syntax, Python compilation and Git whitespace checks also passed.

The deck was separately exercised offline at 1366×900 and 390×844: all 11 images
loaded, each numbered link selected exactly one slide, Previous/Next and arrow
navigation worked, reload restored the hash, and neither viewport overflowed
horizontally. No page errors or external HTTP requests occurred. See
[deck-check.json](deck-check.json) for deck/manifest hashes and outcomes.

## Reproduce and limits

Run the editor and tests using the [consumer instructions](../../../examples/matrix-instrument/README.md).
`capture.py` reruns all 15 checks and rebuilds the deck/manifest; a regeneration
requires refreshing the separate deck check and this retained record as needed.
The capture suite log is at `/tmp/moxi-i02-capture-04l9fl7v/checks.log`;
deck verification and other bounded logs are under `/tmp/moxi-i02-evidence/`.

Confidence is high for this bounded Chromium consumer, based on the exact
projection checks and live flows above. A failing geometry/history regression
or contrary behavior in another browser would change that assessment. This does
not establish learner outcomes or a general mathematics workspace. Constraint
solving, drag manipulation, 3D, persistence and inverse editing remain outside
the requested bounded experiment.

CI, the full Mojo/native-host suite, other browser engines, physical keyboard
hardware and assistive technologies were not tested. T3's preview snapshot timed
out twice; installed Chrome via Playwright provided the retained UI evidence.
There was no delegated or independent review, per the task's no-delegation scope.

Only the standalone consumer and this evidence folder changed. V01, V07, V08,
global ledgers/indexes and the private primary checkout were untouched. No
external communications, pushes or live external writes were performed.
