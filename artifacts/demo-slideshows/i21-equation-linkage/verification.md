# I21 equation linkage verification

Implementation: `cf696cbf77f50b939c1c76b6f7032af8f9557aea`, based directly on
verified public `origin/main` `033596ddb576b09b48234733b45a283b4c3fecae`.
The isolated implementation checkout was clean at capture. Only the new
`examples/equation-linkage` consumer and these scoped artifacts are changed.

The source contract is project-planning's `ideas/i21-living-linkage-sketch.md`
and the I21 row in `DEFERRED-IMPLEMENTATION-MASTER.md`, read on November 25,
2026: a single planar linkage, one degree of freedom, an editable length,
endpoint trace, pointer/keyboard edits, exact text/layout round trips, cancel
and shared undo. The broader speculative mind-map, alternatives and instrument
panel are outside this bounded experiment. Existing V01/V07 work is untouched.

## Direct checks

| Check | Expected | Observed |
| --- | --- | --- |
| Fail-first model | Missing feature fails | Exit 1: expected `parse` function, observed `undefined` on the public baseline. |
| Fail-first browser | Existing V11 lacks equation source | Exit 1: expected one source editor, observed zero. [Baseline screenshot](00-public-baseline.png), [record](fail-first.json). |
| Model suite | Exact source/spans, malformed retention, domain rejection, minimal replacement, cancellation and history | Exit 0; 9 tests. Includes CRLF and 273 allowed length/angle combinations. |
| Browser replay | Normal text, layout, mouse, slider and keyboard editing, shared history and rejection | Exit 0; all 15 scenarios passed in isolated offline desktop Chrome. Seven screenshots. |
| Geometry correction | Equal x/y scales; all 91 Moxi-projected trace samples match the analytic circle | First draft failed the scale assertion by 90.578 SVG pixels; repaired before capture. Final replay passed equal-scale and <0.02 SVG-pixel trace assertions. |
| Fractional angle | Clicking an unchanged endpoint must retain precise text | `+045.1250` remained exact and created no applied history entry. |
| Narrow layout | Operable at 390×844, no document overflow | Text edit, apply and undo restored the exact layout value; no horizontal page overflow. |
| Offline reload | Intentionally session-only | Starter restored; zero uncaught errors and zero failed requests. |

[Open the seven-slide navigable deck](index.html). Its Previous/Next buttons,
arrow keys, thumbnails and verification link were exercised in offline Chrome;
all fourteen image references loaded and there were no browser errors.
The [manifest](manifest.json) records steps, expected and observed results,
outcomes, screenshots, source hashes, HTML hash, browser version, viewport and
UTC timestamps. Browser cancellation and window-blur events are synthetic;
text entry, clicking, dragging, range keys and arm keys use normal browser input.
Screenshots were inspected for wide layout, pointer-preview appearance and
the narrow stacked layout.

## Environment and reproducibility

Chrome 158.0.8127.37; temporary isolated browser context, offline, device scale
factor 1, synthetic fixture without an account. Wide viewport 1280×900 CSS
pixels; narrow viewport 390×844. Capture time and exact source revision are in
the manifest. The running page was rebuilt from the intended checkout through
the local public Moxi Python package; its source hashes match the committed
implementation. No mismatch between tested code and implementation is known.

Reproduction commands are in the [consumer README](../../../examples/equation-linkage/README.md).
Raw model, build, fail-first, browser and deck-check logs were kept under
`/tmp/moxi-i21-linkage`; they are local evidence, not tracked product files.
The shared preview browser timed out on screenshot capture twice; the
recorded screenshots and normal interaction replay therefore use local Chrome
through Playwright.

## Limits and confidence

Confidence is high for the documented finite four-equation grammar and the
tested interaction routes. A reproducible source-preservation or geometry/history
failure using this grammar would change that conclusion. This does not establish
a general symbolic math editor: only length and angle are editable structural
leaves; the two endpoint relations remain fixed. Precise source text is retained;
derived geometry uses floating point and its displayed readouts are rounded.
Textarea entry follows browser newline normalization; CRLF preservation is
verified directly at the model boundary.

The full repository suite, native host, other browser engines, real touch input,
physical mechanism/material behavior and independent usability were not checked.
The shared `origin/main` ref advanced to `6611891` during this run; these checks
cover the explicitly pinned public `033596d` baseline, not those later changes.
There is no saved-document persistence; reload intentionally resets the fixture.
VoiceOver remains paused; keyboard checks do not establish screen-reader acceptance.
No pushes, external communication, global ledger/index edits, production writes,
private primary-checkout edits or delegation were performed.
