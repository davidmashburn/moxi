# Retained concept scenarios I01–I21

Use the numbered sections to replay each concept in its consumer. The table records which steps have captured evidence. The [implementation ledger](../../docs/deferred-implementation.json) tracks the separate criteria for each proposal.

The debugger and recorded gestures both shipped by `8caa40f`. The [debugger walkthrough](../../examples/execution-debugger/evidence/execution-debugger/index.html) covers thirteen frozen frames. The [recorded-gesture walkthrough](../v06-recorded-gesture/index.html) shows capture, editing, cancellation and replay. The revisions below identify the source of each historical capture.

## Scope and how to read the results

The audit used these fixed Git objects on 2026-11-25 Eastern / 2026-11-26 UTC:

| Name | Exact revision | Availability used in this audit |
| --- | --- | --- |
| P: supplied published baseline | `bbf8b252f8ab82dd8a03f7e506b507067cf2aeb8` | Published baseline for the evidence inventory. |
| R: received integration snapshot | `a4f7e00ef9cba00e1148fbc180f5cc4315fed968` | Frozen local `origin/main` value; includes Compose Worlds, G and A plus subsequent integration repairs. No remote refresh was performed. |
| G: delivered mode graph | `900cd4f2602ae392a38b130cc703e71a0cb7088f` | absent from P, ancestor of R. Original I09/I12 capture source. |
| A: delivered attachable probe | `235e0af6704aa65a50e1059f5a0806154b9e3cc5` | absent from P, ancestor of R. Original I05 delivery. |
| M: incoming recorded gesture | `0abf2081f4ade534b8e43b255fe93afa63c7b2de` | absent from P and R. Delivered on main in `3fcc04c`. |
| D: incoming execution debugger | `1f7ac82ce1929a7bf13165226b7a54aa65095bdc` | includes source `3885e3e` and its capture commit; absent from P and R. Delivered on main in `8caa40f`. |

Relative links refer to files at the stated revision. **G/R** and **A/R** links
are unavailable in P. Links marked **M only** or **D only** require that
dependency's checkout or subsequent integration; they are unavailable in P/R.
The audit does not infer publication from a local branch name. Launch commands run from the
repository root of the indicated checkout. Use a fresh disposable browser
profile unless a sequence explicitly requires reopening the same origin. Native
examples require macOS and their documented compiler/Pixi environment. Existing
example READMEs describe prerequisites; commands here were inspected, not run.

**Recorded sequence** means retained consumer captures plus action assertions
cover the named bounded sequence. **Partial** means a required step or specified
consumer remains unsupported by that evidence. **Missing** means no runnable
consumer for the sequence was found. **Local dependency** identifies incoming
coverage without crediting P or R. None means freshly verified behavior at P/R:
this audit inspected source, producer records and selected screenshots, and
performed static link/manifest/hash checks. It did not rerun UI, builds, model
tests, hardware input, assistive technology, participant trials or CI. No
VoiceOver was used. Confidence is high in object/link availability and moderate
in behavioral coverage inferred from retained producer checks. A failing replay
at the stated source, contrary consumer evidence, or a clarified acceptance
criterion would change the latter assessment.

| ID | Sequence status at P / R | Additional received coverage or remaining hole |
| --- | --- | --- |
| I01 | Recorded sequence | Bounded note-to-arm formalization; no arbitrary sketch recognition. |
| I02 | Recorded sequence | Numeric entries and keyboard basis moves share selection and undo. Singular and zero matrices remain editable. |
| I03 | Partial | Force-grid inverse design at P/R. The later V01 native consumer solves an editable trajectory with pinned endpoints. |
| I04 | Recorded sequence | Allocation at P; Compose Worlds adds rule promotion/undo at R. |
| I05 | P partial; R recorded sequence | Same probe transfers from plot to geometry in A/R; capture provenance remains incomplete. |
| I06 | Recorded sequence | Native formula selection/focus return; editable caret return added at R. |
| I07 | Recorded sequence | Five actions, third-step exploration and restoration. |
| I08 | Recorded sequence | Synthetic source/fit/plot provenance and invalidation. |
| I09 | Partial | Phrase desk and the investigation workbench both expose reusable controls. |
| I10 | Recorded sequence | Fit three alternative models to a named cohort and reopen its saved controls in another native process. |
| I11 | Recorded sequence | Deterministic local proposal, including stale rejection. |
| I12 | P partial; R recorded sequence | G/R supplies actual calculation build failure and last-good replacement. |
| I13 | Recorded sequence on main | The debugger exposes measured subtree builds, equivalent frames, source eviction and action-record loss. |
| I14 | Recorded sequence on main | The authored motion and gain curve can be edited while stopped and replayed. Physical timing remains open. |
| I15 | Recorded sequence | Synthetic stream plus separately captured async result and gaps. |
| I16 | Recorded sequence | Explicit insertion and standalone static essay. |
| I17 | Recorded sequence | Pointer/keyboard equivalence and accessible structure, bounded to software checks. |
| I18 | Recorded sequence | Linked IDs and exceptional mappings in two domains. |
| I19 | Bounded experiment complete | Plot cursor, native canvas and projected spatial consumers replay edits after layout changes. |
| I20 | Partial | The notebook and I10 investigation share the registered collection operation. V13 has separate trusted adapters. |
| I21 | Recorded sequence | Edit the equation or move the linkage, cancel a draft and undo across both representations. |

## I01 — Progressively executable sketch

**Status: recorded sequence at P and R.** The direct consumer is Phrase Studio,
not a generic math editor test.

Run `PYTHONPATH=python python3 examples/invent-notation/app.py --port 8763` and
open `http://127.0.0.1:8763/`. In a fresh score, add Sweep and Unison to Chain;
select Sweep, use Down to select Unison, then add two Sweeps to that group.
Choose Last to first and 3 ticks per beat, then Apply revision. The selected
group stays selected while the score changes from four to six ticks. Retain the
sketch note “Reach toward the light?”, choose its arm formalization, set length
41, and focus Preview tick: Home then PageUp gives tick 0.60 and joint 70.5°.
Undo the length edit and then the formalization. The note and its original
`(70, 85)` location return, with the pre-arm document intact.

Evidence: [launch and scope](../../examples/invent-notation/README.md),
[normal-control replay](../../examples/invent-notation/replay.py),
[joint frame](v03-invent-notation/06-joint.png),
[undo frame](v03-invent-notation/07-undo.png),
[gallery](v03-invent-notation/index.html),
[manifest](v03-invent-notation/manifest.json). The capture predates subsequent
persistence guards in P/R; it does not independently prove those guards. No
arbitrary drawn-shape recognition or second-author usability is established.

## I02 — Tangible mathematics

Open the matrix instrument and edit one entry. Select the same basis vector and move it with the arrow keys. Undo traverses both edits in order. Set the columns equal to form a singular matrix, then use the numeric editor to restore the original basis. The eleven captures also show a zero matrix and recovery after a failed render. The tests exercised desktop and narrow Chrome windows. [Run instructions](../../examples/matrix-instrument/README.md) · [Matrix walkthrough](matrix-instrument/index.html)

The oscillator and probability examples demonstrate related basis and constraint behavior. [Oscillator replay](oscillator/index.html) · [Probability instrument](../../examples/probability-instrument/README.md)

## I03 — Inverse design

**Status: partial at P and R.** Folding Lamp supplies bounded force-response
inverse design, not a desired trajectory editor.

Build `PYTHONPATH=python python3 examples/spring-linkage/build.py /tmp/folding-lamp.html`
and open the file. Start with 100 mm arm / 40 mm anchor. Increase Anchor by
ArrowUp and apply: 50 mm gives RMS 0.424 N. Sweep grid evaluates 42 candidates;
select the 130/60 candidate (RMS 0.034 N), inspect the preview and Escape to
restore the original dimensions. Repeat and Apply. Choose High load 4.8 N and
sweep: infeasibility leaves geometry unchanged. Undo the target and candidate
edits.

Evidence: [launch/model limits](../../examples/spring-linkage/README.md),
[browser assertions](../../examples/spring-linkage/check.py),
[gallery](v04-spring-linkage/index.html),
[manifest](v04-spring-linkage/manifest.json). Remaining: an editable trajectory
target with a pinned geometric constraint and alternatives from that target.
The synchronous grid has no pending solve to cancel or stale response to reject;
preview cancellation is the behavior actually present. The subsequent V01 consumer supports trajectory editing. Drag a target knot, preview two candidate motion models, then apply or cancel. Edit the model during a solve to exercise stale-result rejection. [Native motion walkthrough](motion-model/index.html) · [Model and replay instructions](../../examples/motion-model/README.md).

## I04 — Possible worlds

**Status: recorded sequence at P and R.** Allocation is the baseline consumer.
Run `pixi run --locked bash examples/allocation/run.sh`. Compare all three
preference branches. Increase shared supply: all three gain a garden. Transfer
Commons' play allocation to grove: only Commons changes. Review a proposal,
retain its reason/disagreement and promote it. Further local preference edits
leave the promoted counts/preferences/disagreement frozen. Undo promotion
restores the prior decision while retaining working edits.

Evidence: [allocation review and controls](allocation/REVIEW.md),
[promotion](allocation/05-promoted.png), [undo](allocation/07-undo.png),
[gallery](allocation/index.html), [manifest](allocation/manifest.json).

**R addition:** `python3 examples/compose-worlds/build.py`, then open
`dist/compose-worlds/index.html`. Set North override 0, East override 100 and
shared midpoint 70; South inherits 70. Promote East and Run comparison: shared
100 now reaches East/South while North remains 0. Undo restores shared 70 and
the earlier overrides. Replay history out of order and repeat undo. This is the
shared-rule replacement scenario, absent from P's five-frame gallery.
[R controls](../../examples/compose-worlds/README.md),
[R replay](../../examples/compose-worlds/browser_check.py),
[R gallery/manifest](../../examples/compose-worlds/evidence/compose-worlds/manifest.json)
contains eleven frames captured at `77edeb0`; the addition is present in R.
Neither example establishes multi-person negotiation benefit or durable history
beyond its documented lifetime.

## I05 — Attachable instruments

**Status: partial at P; recorded sequence at A/R with a provenance hole.**
P's probability plot alone cannot prove a transfer to geometry.

In **A/R**, run `PYTHONPATH=python python3 examples/probability-instrument/instrument.py`
and open the printed loopback URL. Pin the mean, select outcome 1 and enter 0.2
on the plot: preview `(0.4, 0.2, 0.4)`, reading 0.2, reference 0.5 and change
−0.3. Choose the triangle attachment: the selected outcome, pin, pending input,
dimensionless units, reading and reference persist. Enter commits and advances
the reference to 0.2. Select outcome 2; press halfway up the triangle, hold,
Escape, move and release: the cancelled preview stays cancelled. Repeat and
commit `(0.5, 0, 0.5)`, then enter infeasible 0.8. Switch attachments: the rejected
input remains visible and Apply stays disabled while the committed reading stays
intact.

At R, also reload, leave the mean free, select outcome 2 and enter
`0.3333333333333333`. Transfer plot → triangle and Apply. At 390 CSS pixels the
fractional committed/preview table and controls must stay within the viewport.

Evidence **A/R**: [action record and captures](../../examples/probability-instrument/evidence/attachments/README.md),
[browser check](../../examples/probability-instrument/check_browser.py),
[geometry transform source](../../examples/probability-instrument/triangle.mojo).
Remaining: the six original PNGs at A and nine at R have valid PNG headers and
dimensions, but no capture manifest or source/image hashes. The README names
base `3995b082` for the original capture and records a later integrated narrow
layout replay without a precise source SHA. This audit did not rerun it.
Do not substitute the [older manifest](../../examples/probability-instrument/evidence/v08-probability/manifest.json)
for attachment provenance. No physical instrument or physical touch was tested.

## I06 — Semantic zoom

**Status: recorded selection/focus sequence at P/R; editable caret coverage at R.**
Run `examples/lived-spaces/run.sh` on macOS. From the cue plot press Command-F:
the formula's `width` term becomes selected. Command-D opens the definition;
Command-D again returns to the formula with its original selection and keyboard
focus. The native check asserts the first responder and exact range `(32, 5)`.
The formula is read-only, so this proves selection return rather than editing.

Evidence: [controls](../../examples/lived-spaces/README.md),
[native assertions](../../examples/lived-spaces/window.mm),
[definition](lived-spaces/07-definition.png),
[returned selection](lived-spaces/08-selection.png),
[manifest](lived-spaces/manifest.json).

In R's Compose Worlds, focus the grazing chart and press Enter to select the
midpoint in `knots(0, 50, 100)`. Type a draft; place a caret or forward/backward
selection. Tab past Apply formula to the Knot definition link and open it with
Enter. Return/Escape restores that exact draft, selection direction and focus;
Apply then affects the branch run. [R browser assertions](../../examples/compose-worlds/browser_check.py)
and [R eleven-frame gallery](../../examples/compose-worlds/evidence/compose-worlds/index.html)
cover these states. The oscillator test named `formula_return` restores a
selection in its observation note, not an editable formula; it is not used as
formula-caret evidence. General symbolic navigation is unestablished.

## I07 — Performed explanations

**Status: recorded sequence at P and R.** Build
`PYTHONPATH=python python3 examples/executable-argument/build.py /tmp/shuttle.html`
and open it. Tab to Next action and press Enter three times: action three shows
30 riders / $120 dispatch and a $180 tie with source details expanded. Explore
29 riders / $160 dispatch and write “Test a quieter departure.” Restore step
three: 30 / 120, the empty note and the explanation position return. Two more
Next actions finish the five-action explanation, with the voucher/shuttle
comparisons updated in order.

Evidence: [scenario record](v05-executable-argument/EVIDENCE.md),
[third action](v05-executable-argument/action-three.png),
[restoration](v05-executable-argument/restored-comparison.png),
[capture assertions](../../examples/executable-argument/capture.py),
[manifest](v05-executable-argument/manifest.json).
The oscillator also has a five-step player with third-step exploration and
restoration in its [eight recovery scenarios](oscillator/recovery/scenarios.json).
Their eight source hashes match P/R. Its original nine screenshot captions
predate that repaired player and are not proof of the five-step flow. Neither
record establishes learner comprehension or an arbitrary recording system.

## I08 — Reasoning debugger

**Status: recorded sequence at P and R.** Open the I07 Shuttle article. Expand
Trace cost rates to inspect observations, the through-zero unit-rate fit and
the derived savings plot. Explore 29 riders / $160 dispatch, add the quieter
departure note and Save alternative. Withdraw the demand premise: the conclusion
becomes unavailable and Save/Insert are disabled. Reopen the alternative: both
premises, the note, and the $44 voucher advantage return, with fixture T1 and the
fit/assumed-dispatch distinction available for inspection.

Evidence: [expected/observed record](v05-executable-argument/EVIDENCE.md),
[saved alternative](v05-executable-argument/saved-alternative.png),
[invalid premise](v05-executable-argument/withdrawn-premise.png),
[gallery](v05-executable-argument/index.html),
[manifest](v05-executable-argument/manifest.json).
The source is synthetic and alternatives last for the page session. This is
explicit local provenance, not an empirical cost estimate, arbitrary dependency
debugger or durable research workspace.

## I09 — Curated instrument panels

**Status: partial overall; extraction/save/reopen recorded at G and integrated in R.**
P's Phrase desk edits a predefined mapping; choosing Length there is not
evidence of extracting a source control.

In **G/R**, run `PYTHONPATH=python python3 examples/personal-instrument/app.py`
and open `http://127.0.0.1:8182/`. Open Phrase controls, select step 2, use the
real Length slider's Home/Right and Extract Length. The score's step-2 length
becomes 1; extraction edits only the draft panel. Set Accent midpoint 75 with
Next Length / Keep step, and Length midpoint 37 with Next Accent / Advance.
Build preview, then Save and reload at the same origin. The graph, custom
responses and score reopen. Select step 3, set Input to 68, Next/Apply/Next/Apply:
step 3 length becomes 60 and step 4 accent 84; unrelated notes/fields stay intact.

Evidence **G/R**: [normal actions, expected/observed values](../../examples/personal-instrument/evidence/mode-graph/verification.md),
[reopened panel](../../examples/personal-instrument/evidence/mode-graph/reopened-graph.png),
[results](../../examples/personal-instrument/evidence/mode-graph/results.json),
[hash manifest](../../examples/personal-instrument/evidence/mode-graph/manifest.json).
The [investigation workbench](../../examples/investigation-tools/README.md) also saves the refit and coefficient controls for its specific cohort.
The evidence covers the fixed Accent/Length vocabulary, not arbitrary control
extraction. Reload intentionally resets selection/input while preserving the
saved panel and composition.

## I10 — Investigations become tools

Build with `bash examples/investigation-tools/build.sh` and launch `dist/investigation-tools/investigation` on macOS. Enter a name, collect the six sensor readings at or above 70, and fit a linear model. Compare mean, linear and quadratic alternatives on those same observations. For the quadratic fit, changing the constant from 68 to 69 gives six signed residuals of −1 and a sum of squared errors of 6.

Save the fixed panel, close the app, and reopen the panel in a fresh process. The cohort IDs, fitted model and edited coefficient survive. Refit from the saved panel to recover the original coefficients. The replay also exercises an incompatible saved version and a failed write. [Native walkthrough](investigation-tools/index.html) · [Reproduction and checks](../../examples/investigation-tools/README.md)

## I11 — Visible agent work

**Status: recorded sequence at P and R.** Run
`pixi run --locked bash examples/visible-proposals/run.sh`. Request a fit:
the fake worker proposes gain 1 → 3 and offset 0 → 4. Inspect and Reject; live
values/revision do not change. Request again, increase live gain to 2 (revision
1), then Apply the old revision-0 proposal: stale rejection preserves `(2, 0)`.
Request a fresh proposal and Apply: both values publish together at revision 2.

Evidence: [launch and six-step record](../../examples/visible-proposals/README.md),
[gallery](visible-proposals/index.html), [manifest](visible-proposals/manifest.json).
The worker is deliberately deterministic and local. The producer used AppKit
accessibility presses, not a live LLM or physical input. No broader agent
authority or out-of-process security boundary is established.

## I12 — Live tool authoring

**Status: partial at P; recorded sequence at G, integrated in R.**
V03's structural revision retains selection and document data. Its capacity
rejection is schema validation; V12's denied storage write is not a failed
calculation build. Neither alone closes this row.

In **G/R**'s Phrase desk, author the I09 graph, select Length, set its midpoint to
41 and press Ctrl+Enter. The versioned calculation builds and replaces the
active panel while retaining score and the focused editor/pad nodes. Enter
`not-a-number` in that field and press Ctrl+Enter: the real `/build` request
returns HTTP 400; the active/stored 41% calculation, score and focused input
remain intact. Reload to confirm the last good panel persists.

Evidence **G/R**: [normal failed-build scenario](../../examples/personal-instrument/evidence/mode-graph/verification.md),
[failed-build capture](../../examples/personal-instrument/evidence/mode-graph/failed-build.png),
[source/artifact hash manifest](../../examples/personal-instrument/evidence/mode-graph/manifest.json),
[regression check](../../examples/personal-instrument/graph-check.cjs).
Remaining: the exact G capture source differs from R's later startup-recovery
repair; no refreshed hash/capture record accompanies that repair. Its injected
HTTP 500/storage faults are separate resilience checks, not ordinary UI gestures.
This is a bounded calculation definition, not arbitrary source compilation,
plugins or general hot replacement.

## I13 — Visual execution debugger

**Recorded on main.**
In D run `pixi run execution-debugger` and open `http://127.0.0.1:8173/`.
With an already activated repository Pixi environment, the equivalent
`python3 examples/execution-debugger/app.py --port 18173` uses the same entry.
Every launch compiles the real Moxi runner with Mojo 1.1.

Click Open I15 episode. Select the first sample: tick 12 changes the reading
from unavailable to 25, with subtree build deltas `[1, 0]` and an actual SVG
frame. Select action 13, the async result: peak unavailable → 84, reading
unchanged and deltas `[0, 1]`; its source completion time remains unknown.
Click Compare broad rebuild: final state and selected frame match, but total
builds including mount are localized `[13, 2]` versus broad `[14, 14]`. Repeat
localized replay: a second run matches state, frames and work. Set Trace
capacity to 5: only ordinals 9–13 remain and trace loss reads 8/13, independently
of the 12 evicted source samples. Reopen the I15 missing fixture with Reopen
JSON: tick 13 and the async result remain unavailable. Try malformed JSON;
the last good frames must remain inspectable.

Evidence **D only**: [consumer and limits](../../examples/execution-debugger/README.md),
[gallery](../../examples/execution-debugger/evidence/execution-debugger/index.html),
[nine-frame manifest](../../examples/execution-debugger/evidence/execution-debugger/manifest.json),
[steps, observed results and source hashes](../../examples/execution-debugger/evidence/execution-debugger/verification.json),
[actual subtree runner](../../examples/execution-debugger/runner.mojo).
The producer record covers thirteen application scenarios, a gallery check and five backend tests. File
upload used the real file input with a supplied on-disk fixture; the OS file
picker was attempted but not verified. The integrated browser replay passed all thirteen action scenarios at desktop and narrow widths. The comparison is a localized/broad policy change over existing
synthetic I15 input, not arbitrary changed-code replay or a general profiler.
Missing historical inputs cannot be reconstructed. Single-run timings do not
establish tracing overhead or a performance benchmark. P/R's episode viewer
alone provides none of these execution-debugger claims.

## I14 — Mathematics and motion studio

**Recorded on main.** Build
`PYTHONPATH=python python3 examples/motion-envelope/build.py /tmp/motion-phrase.html`
and open it. Drag Time to apex to 1800 ms: the moving point and sound envelope
preview the same timing; inspect 750 ms. Escape restores the prior timing.
Focus the timing slider, use End and commit. Play twice to replay the same
authored three-knot motion/envelope. For the stopped-edit comparison, commit
1370 ms, seek to 500 ms and Set checkpoint. Explore 200 ms at 1900 ms, then
Restore checkpoint. Inspect 500/1370/1750 ms against an uninterrupted copy at
1370 ms. This is a manual checkpoint, not a three-action lesson player.

Evidence: [controls](../../examples/motion-envelope/README.md),
[browser assertions](../../examples/motion-envelope/check_browser.py),
[timing and checkpoint observations](motion-envelope/timing.json),
[gallery](motion-envelope/index.html), [manifest](motion-envelope/manifest.json).
That authored apex/checkpoint sequence alone does not establish recording.

In **M**, build and open the same normal entry. Set Height to 0.2 and click
Record gesture. As the displayed score clock passes 250 ms, drag Height to
about 0.85; after 750 ms use Home then 12 Right Arrows on Height. Capture ends
at 2 seconds with 201 samples on a 10 ms grid and silent endpoints. Seek to
750 ms, set Height to 0.73, click Set height at inspection time, then Commit
edit. Only that sample changes; the other 200 stay intact. Set checkpoint.
Inspect 0/350/750/1250/2000 ms twice and Play phrase twice: stopped poses repeat
exactly and both media follow the same authored take. Start a replacement and
cancel by button, or Escape while dragging then move/release: the prior take
and inspection state survive. Commit a flight alternative and Restore
checkpoint: the saved recorded curve and 750 ms inspection return.

Evidence **M only**: [normal actions, captures and limits](../v06-recorded-gesture/README.md),
[committed stopped edit](../v06-recorded-gesture/1280-edited-committed.png),
[source hashes and per-take measurements](../v06-recorded-gesture/evidence.json),
[browser check](../../examples/motion-envelope/check_gesture_browser.py).
The retained producer checks compare repeated live software frames and repeated
offline PCM from the UI-authored take at 44.1/48 kHz. Injected audio rejection,
pointer cancellation, blur and hidden-page events are separate failure checks,
not ordinary author gestures. On the published build, reload intentionally
starts a fresh session, so there is no cross-session gesture persistence.
Physical input/audio/display timing, audibility, real touch, artist benefit and
assistive-technology operation remain unverified.

## I15 — Experiment flight recorder

**Status: recorded sequence at P and R.** Run
`PYTHONPATH=python python3 examples/flight-recorder/app.py` and open
`http://127.0.0.1:8175/`. Capture episode and inspect ticks with the slider/arrows.
The seeded stream emits 24 readings, retains zero-based ticks 12–23, and records 12
evictions. Its worker request at tick 16 refers to an immutable snapshot of
readings 5–16; the result is captured separately. Save the JSON, reload and
reopen it: inspection uses the saved episode without rerunning the generator.
Repeat with Omit async result selected: its request identity remains and the
viewer reports the missing result. Remove one sample from a saved copy using
a text editor and reopen it to see a missing-tick gap.

Evidence: [launch/schema/observations](../../examples/flight-recorder/README.md),
[complete reopen fixture](../../examples/flight-recorder/evidence/episode.json),
[missing-result fixture](../../examples/flight-recorder/evidence/missing.json),
[gallery](../../examples/flight-recorder/evidence/flight-recorder/index.html),
[manifest](../../examples/flight-recorder/evidence/flight-recorder/manifest.json).
The README's “13–24” label disagrees with the actual zero-based fixture/code;
this sequence follows the captured data. The source and clock are synthetic,
capacity/input size are bounded and no physical instrument is connected.
Episode capture alone does not establish I13; D's separate consumer does.

## I16 — Executable essay

**Status: recorded sequence at P and R.** Open the I07 Shuttle article. Read its
narrative, cost formula and savings plot at 40 riders / $120 dispatch. Explore
a copy at 29 / 160, add “Test a quieter departure.” and choose Insert finding.
Restore the authored 40 / 120 state: the explicitly inserted alternative remains
separate. Export static essay, open the downloaded HTML and reload it. It retains
the authored $40 shuttle saving, inserted $44 voucher saving, derived plot,
fixture T1, fit formula and stated wait-time/access limitation without scripts
or editing controls.

Evidence: [scenario record](v05-executable-argument/EVIDENCE.md),
[static capture](v05-executable-argument/static-essay.png),
[standalone essay](v05-executable-argument/argument.html),
[gallery](v05-executable-argument/index.html),
[manifest](v05-executable-argument/manifest.json).
The oscillator's [source-matched report checks](oscillator/recovery/scenarios.json)
also distinguish unplotted saved parameters from the plotted curve and checkpoint
versus exploration provenance. Neither example proves arbitrary notebook export
or empirical support for the synthetic argument.

## I17 — One instrument, many bodies

**Status: recorded software equivalence at P and R.** Run Phrase desk as in I09
using P/R. Click a note, adjust Input and Apply to step. In an independently
reset fixture, Tab to Keyboard pad, use Up/Down to the same input, Space to apply
and Right to advance: the operation and score match the pointer route. Step
names, selection and pad focus are exposed by native browser controls. In the
motion example, pointer preview at 1800 ms and keyboard End reach the same path
and envelope state; Escape cancels both.

Evidence: [Phrase desk controls and limits](../../examples/personal-instrument/README.md),
[interaction assertions](../../examples/personal-instrument/check.cjs),
[gallery](../../examples/personal-instrument/evidence/personal-instrument/index.html),
[manifest](../../examples/personal-instrument/evidence/personal-instrument/manifest.json),
[motion assertions](../../examples/motion-envelope/check_browser.py).
**G/R** adds [full-score byte equivalence after authored graph transitions](../../examples/personal-instrument/evidence/mode-graph/verification.md)
and reload. No VoiceOver, switch device, physical comfort or broad accessibility
certification is claimed. Accessible names/roles plus software keyboard checks
establish only the recorded structure and equivalence.

## I18 — Coordinated representations

**Status: recorded sequence at P and R.** Run
`PYTHONPATH=python python3 examples/coordinated-representations/app.py --port 8118`
and open `http://127.0.0.1:8118/`. Select table observation S-14 and Enter: its
identity is shared by the table, plot and canvas. Set intensity minimum to 50:
selection remains explicitly filtered; clear the filter to restore it. Group
means and select the first mean: it maps to S-14 + S-38 and refuses single-row
deletion. Clear grouping, select S-38 on the canvas and Delete: all views retain
the deleted identity/tombstone. Reload the URL to inspect the retained state.
Switch to the transit fixture, select plot T-19 and inspect Coastal; select its
mean to map back to T-02 + T-19.

Evidence: [controls/limitations](../../examples/coordinated-representations/README.md),
[replay assertions](../../examples/coordinated-representations/replay.py),
[gallery](i18-coordinated-representations/index.html),
[manifest](i18-coordinated-representations/manifest.json).
The original capture precedes repaired app/replay/view tests in P/R. Two
synthetic domains are demonstrated, not arbitrary aggregate inversion or an
extracted general library. Overlapping projected anchors remain a documented
selection limitation; unrelated plot selection tests do not expand this claim.

## I19 — Inspectable interactions

**The plot cursor, native canvas and spatial examples exercise the bounded transaction contract.**
Build `python3 experiments/inspectable-interactions/build.py /tmp/signal-cursor`
and serve it with
`python3 -m http.server 0 --bind 127.0.0.1 --directory /tmp/signal-cursor`.
Open the printed loopback address. Enter Sample 70: preview changes from 25;
Escape returns to 25. Drag to sample 47 and release: the preview remains until
Commit move. Commit adds one undo entry; Undo returns to 25 at revision 2.
Open the compact replay copy: its narrower layout starts at 25. Replay command
moves it to 47 at revision 1; replay again rejects the stale target, preserving
47 and undo depth 1. Enter 101 to see range rejection and disabled commit.

Evidence: [controls and further checks](../../experiments/inspectable-interactions/README.md),
[browser assertions](../../experiments/inspectable-interactions/check_ui.py),
[stale capture](i19-inspectable-interactions/09-stale.png),
[gallery](i19-inspectable-interactions/index.html),
[manifest](i19-inspectable-interactions/manifest.json).

In either native example, preview an edit, cancel it with Escape, then commit a second edit and undo once. Resize or change the projection and replay the recorded command. A second replay shows the stale rejection and preserves the model. [Native commands](../../examples/inspectable-transforms/README.md) · [32 captured states](../../examples/inspectable-transforms/evidence/i19-transforms/index.html)

## I20 — Reusable application operations

**Status: partial overall; bounded notebook sequence recorded at P/R, downstream consumers open.**
Run `bash examples/application-operations/build.sh`, then
`dist/application-operations/notebook`. Click its collect button: the cohort
is `[104, 318]`. Reopen a fresh notebook and press F2 for the same result. Run
`dist/application-operations/notebook --script`: it prints those IDs and exits
0. Run `dist/application-operations/notebook --agent`: the read-only caller is
rejected with exit 1. The native check also rejects this caller after a cohort
already exists, preserving members/write count, and clicks a replacement button
with a different view ID. All routes invoke `observations.collect_high.v1`.

Evidence: [launch/operation boundary](../../examples/application-operations/README.md),
[UI/CLI/policy assertions](../../examples/application-operations/check.py),
[gallery](../../examples/application-operations/i20-application-operations/index.html),
[manifest](../../examples/application-operations/i20-application-operations/manifest.json).
Script and agent are documented invocation paths, not hidden browser APIs.
Caller assignment is trusted in-process policy, not authentication. I10 reuses the registered collection operation through its button and F2 routes. [Native investigation replay](investigation-tools/REVIEW.md)

## I21 — Living linkage sketch

Open the equation editor, enter a length with trailing zeros and switch to structured layout. Change the angle, preview a pose with the arrow keys or by dragging the endpoint, then cancel. Undo and redo traverse applied text, layout and geometry edits while preserving exact source spelling. The offline Chrome replay covered all fifteen scenarios, including invalid input and narrow layout. Its four equations describe a single planar arm. [Run instructions](../../examples/equation-linkage/README.md) · [Equation walkthrough](i21-equation-linkage/index.html)

Build/open Folding Lamp as in I03. Use pointer
and keyboard Pose controls (Right to 50°, Left to 45°) to inspect the same arm
tip and trace. Edit its length/anchor, preview/cancel, apply and undo in the
shared history. Enter invalid arm length 85 and Escape: committed dimensions
and geometry remain intact.

The complementary Accordion sequence is
`examples/foldable-motif/build.sh /tmp/accordion.html`, then open that file.
Pick a panel in either view and select panel 3 with the keyboard; preview tilt
75° and Escape. Enter pitch 24.5 / tilt 60 and Enter: sheet length 147 mm, span
73.5 mm and rise 21.2 mm agree across views. Reject tilt 90; Undo restores exact
numeric values `(20, 30)` and the original flat/folded SVG point strings. Measure
crease 3 to see its endpoint sweep and live height; undo restores the original
question at its original location.

Evidence: [Folding Lamp assertions](../../examples/spring-linkage/check.py),
[Folding Lamp gallery/manifest](v04-spring-linkage/manifest.json),
[Accordion controls and explicit limits](../../examples/foldable-motif/README.md),
[exact numeric/geometry assertions](../../examples/foldable-motif/check.cjs),
[Accordion gallery](v11-foldable-motif/index.html),
[manifest](v11-foldable-motif/manifest.json).

## Evidence integrity across P and received revisions

The following inventories were read from Git objects, not from whichever files
happened to be present in the audit worktree. Common links exist at P and R;
G/A additions exist at R and their delivery commits, but not P. M/D-only links
exist in their exact delivery commits and are absent from P/R. The linked
consumer directories changed between P/R only for Compose Worlds, Phrase desk
and Probability instrument. This establishes availability, not a new behavioral
run. Capture revisions below identify historical producer evidence; they are
not automatically the whole current source tree. These fixed objects bound the
audit even if branch refs advance afterward. Directory equality alone does not
establish dependency or running-binary identity.

All **93 unique relative links** resolve in their stated Git objects: 76 at P,
84 at R, and nine available only through M/D. Eight links added since P resolve
in both R and their A/G delivery. Paths were normalized relative to this file
and checked as Git objects; they were not treated as present merely because a
different branch or the audit worktree contained them.

| Manifest / gallery family | Frames P / R | Recorded capture revision | Integrity result |
| --- | --- | --- | --- |
| [Phrase Studio](v03-invent-notation/manifest.json) | 7 / 7 | `fb387fe` | Shared v1; later persistence guards are outside original captures. |
| [Folding Lamp](v04-spring-linkage/manifest.json) | 6 / 6 | `73c260f` | Shared v1; subsequent check changes are not new runtime captures. |
| [Shuttle argument](v05-executable-argument/manifest.json) | 6 / 6 | `4c0e52f` | Shared v1; consumer source unchanged from capture revision. |
| [Oscillator](oscillator/manifest.json) | 9 / 9 | No revision field | Custom tuple manifest; historical source hashes only. |
| [Motion/envelope](motion-envelope/manifest.json) | 6 / 6 | `c4fa6d5` | Shared v1; later uninterrupted/checkpoint comparison is supplemental. |
| [Lived spaces](lived-spaces/manifest.json) | 8 / 8 | `ff5530d` | Shared v1; later authored recording is not in these frames. |
| [Allocation](allocation/manifest.json) | 7 / 7 | `38fed34` | Shared v1; consumer source unchanged from capture revision. |
| [Accordion](v11-foldable-motif/manifest.json) | 6 / 6 | `8040f9e` | Shared v1; later draft/picking checks are not original captures. |
| [I18](i18-coordinated-representations/manifest.json) | 15 / 15 | `b5fe1f4` | Shared v1; later app/replay/view-test repairs exist in P/R. |
| [I19](i19-inspectable-interactions/manifest.json) | 10 / 10 | `854e38e` | Shared v1; later transaction/replay repairs exist in P/R. |
| [Visible proposals](visible-proposals/manifest.json) | 6 / 6 | `0208803` | Shared v1; app source agrees with producer's documented `23f899f`. |
| [I20](../../examples/application-operations/i20-application-operations/manifest.json) | 6 / 6 | `f1a6b76` | Shared v1; consumer source unchanged from capture revision. |
| [Compose Worlds](../../examples/compose-worlds/evidence/compose-worlds/manifest.json) | 5 / 11 | P `5fb7d85`; R `77edeb0` | Shared v1; only R has promotion/undo and editable-caret captures. |
| [Flight recorder](../../examples/flight-recorder/evidence/flight-recorder/manifest.json) | 4 / 4 | `b6f0f3b` | Shared v1; consumer source unchanged from capture revision. |
| [Phrase desk baseline](../../examples/personal-instrument/evidence/personal-instrument/manifest.json) | 4 / 4 | `03360a1` | Shared v1; R's extraction graph/build-failure evidence is a separate set. |
| [Probability baseline](../../examples/probability-instrument/evidence/v08-probability/manifest.json) | 4 / 4 | `6c4d1a0` | Shared v1; R's attachments are a separate set. |

Static checks passed for all **109 PNG references at P** and **115 at R**:
committed blob presence, PNG signature and declared dimensions. Fifteen
manifests per tree passed the shared v1 loader in
[demo_slideshows.py](../../scripts/demo_slideshows.py). Oscillator's custom
tuple manifest lacks v1 action/expected/phase fields and was inspected separately;
it was not counted as shared-schema compliant. Thirteen galleries embed their
referenced PNG bytes unchanged; I18, I19 and oscillator use valid adjacent PNG
links instead. None of these sixteen manifests records image checksums, so
these results are object/format checks, not verification against producer image
hashes. Selected screenshots were visually inspected; no batch image decoding
or browser slideshow replay was run by this audit.

The original oscillator inventory matches only 3/7 current source hashes
(`capture.py`, `serve.py`, `style.css`). Its changed `index.html`, `lesson.js`,
`lesson.py` and `test_lesson.py` explain why those nine frames must stay historical.
The [recovery record](oscillator/recovery/scenarios.json) matches **8/8 source
hashes at P and R**, records eight passed scenarios and no page errors, and is
the evidence used for the repaired checkpoint/report behavior. Hash matching
establishes tested-source identity, not a new run by this auditor.

**G/R:** the [mode-graph manifest](../../examples/personal-instrument/evidence/mode-graph/manifest.json)
matches **4/4 source SHA-256 values** and **14/14 artifact hashes** at `900cd4f`,
including the eight retained PNGs, results and verification record. Its capture
ran on uncommitted changes above base `5768f2b`; those exact hashed sources are
now in G. At R all 14 artifact hashes still match, but only **2/4 source hashes**
do: `index.html` and `graph-check.cjs` changed for saved-graph recovery. These
historical captures do not verify that later repair. Do not attribute the
original authored graph behavior to the unchanged capture-base commit.

**A/R:** six original attachment PNGs at `235e0af` and nine at R passed PNG
header/dimension checks. The later [fractional-width record](../../examples/probability-instrument/evidence/attachments/README.md)
describes an integrated desktop/narrow rerun, with regenerated narrow captures
and three additional fractional-result states. CSS viewports are 1280 × 800
and 390 × 844; full-page PNG heights vary with content. No manifest, image
checksum or exact tested-source hash is retained for either set.

A fresh replay on the public implementation recorded the exact source and image hashes for both consumers. It covers transferring a fractional probability preview at 390 px and recovering the saved two-mode graph after a failed rebuild. [Probability walkthrough](../../examples/probability-instrument/evidence/attachments/v08-current-2026-11-26/index.html) · [Phrase desk walkthrough](../../examples/personal-instrument/evidence/mode-graph/v12-current-2026-11-26/index.html)

**M only:** [recorded-gesture evidence](../v06-recorded-gesture/evidence.json)
matches **5/5 source hashes** at `0abf208`; all 12 committed PNGs have valid
headers/dimensions, including the ten named normal-flow captures and two audio
failure captures. Its capture ran dirty above `4c486de`; the hashed tested
sources match the final delivery. It records two viewport runs without page
errors and repeated PCM hashes. Those PCM hashes are not PNG checksums. This
is the original evidence record. The [published gallery manifest](../v06-recorded-gesture/manifest.json) identifies the seven walkthrough captures.

**D only:** the [debugger manifest](../../examples/execution-debugger/evidence/execution-debugger/manifest.json)
passes the shared v1 loader; **9/9 PNG hashes**, declared dimensions and gallery
embedded bytes match at `1f7ac82`. The [verification record](../../examples/execution-debugger/evidence/execution-debugger/verification.json)
matches **10/10 source hashes** and the entire `src` tree object. Capture source
`3885e3e` is an ancestor of the evidence-only delivery commit. It records five
passing backend tests and includes the gallery check alongside the thirteen application scenarios at desktop and narrow sizes;
these are inspected producer results, not tests rerun by this auditor.
