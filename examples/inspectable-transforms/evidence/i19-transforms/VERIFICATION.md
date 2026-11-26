# Native I19 verification

Implementation: `da93a988f939b7fa45b9d599d958ce5793ff39ba`, directly on
`16a97e1`, with public base `033596ddb576b09b48234733b45a283b4c3fecae`.
Capture began 2026-11-26 04:30:17 UTC with the implementation committed and
unchanged. The scoped status contains only derived evidence changes. The
retained [provenance](provenance.json) records 176 source hashes, 67 artifact
hashes and the exact toolchain; the [manifest](manifest.json) records each
action, expectation, observation and outcome. [Open the offline deck](index.html).

The environment was macOS 27.2.1 arm64, Mojo 1.1.0 (8189361e), Apple clang 21,
and the public experimental Metal spatial renderer. Native content size was
1200 × 760 points, then 1320 × 800 after actual window resize, at 2× display
scale. All 32 PNG dimensions match the observed size and scale. Fixtures are
one synthetic canvas card or generated spatial surface, in independent
source/copy documents, with no account or service connection.

## Native scenarios

Run from the repository root:

```sh
python3 examples/inspectable-transforms/gallery.py
python3 examples/inspectable-transforms/gallery.py --render-only
node --test experiments/inspectable-interactions/test.mjs
```

Build and both normal executable mode replays passed. The original public I19
tests passed 2/2. Both normal native replays passed all 17 new mixed-route
checks each (34/34), in addition to their existing assertions. Retained source
and artifact hash verification passed with `--render-only`.
The replay uses the ordinary dispatcher, native field-editor insertion,
AppKit keyboard dispatch, pointer callbacks, public Moxi state and native
history. Cancellation fault events enter the host's normal event queue;
malformed records are tested directly at the semantic boundary.

The table shows `committed X / preview X, revision, consumer undo depth`.
Each row links its canvas and spatial native captures; matching JSON files
retain the measured state, including native undo depth and fixture reservation.

| Scenario and expected outcome | Canvas observed | Spatial observed | Result |
| --- | --- | --- | --- |
| [Initial](canvas/01-initial.png) / [spatial](spatial/01-initial.png): equal independent baselines; empty undo cannot remove fixture | Source/copy `80/80, r1, u0` | Source/copy `0/0, r2, u0` | Pass |
| [Exact entry](canvas/02-numeric-preview.png) / [spatial](spatial/02-numeric-preview.png): preview without document/history mutation | Source `80/230, r1, u0` | Source `0/700, r2, u0` | Pass |
| [Held Escape](canvas/03-held-pointer-cancel.png) / [spatial](spatial/03-held-pointer-cancel.png): cancel, then late move/release cannot revive draft | Source `80/80, r1, u0` | Source `0/0, r2, u0` | Pass |
| [Released drag](canvas/04-pointer-preview.png) / [spatial](spatial/04-pointer-preview.png): retain native preview without commit | Source `80/230, r1, u0` | Source `0/698, r2, u0` | Pass |
| [Commit](canvas/05-committed-command.png) / [spatial](spatial/05-committed-command.png): exact refinement, one native history entry, versioned world-value record | Source `230/230, r2, u1` | Source `700/700, r3, u1` | Pass |
| [Cmd-Z](canvas/06-source-undo.png) / [spatial](spatial/06-source-undo.png): restore X in one step, advance revision | Source `80/80, r3, u0` | Source `0/0, r4, u0` | Pass |
| [Changed-layout replay](canvas/07-reprojected-replay.png) / [spatial](spatial/07-reprojected-replay.png): camera/viewport changes preserve semantic baseline; resized copy accepts original record | Copy `230/230, r2, u1` | Copy `700/700, r3, u1`; perspective changed to orthographic | Pass |
| [Stale after undo](canvas/08-stale-after-undo.png) / [spatial](spatial/08-stale-after-undo.png): repeated replay rejects; undo restores X but does not revive record | Copy `80/80, r3, u0` | Copy `0/0, r4, u0` | Pass |

The mixed-route extension runs after the original scenarios, at a new
committed baseline of 100 in each source. The new JSON captures also retain
`dragging`, so held and released ownership can be distinguished.

| Scenario and expected outcome | Canvas observed | Spatial observed | Result |
| --- | --- | --- | --- |
| [Grab numeric draft](canvas/09-numeric-grab.png) / [spatial](spatial/09-numeric-grab.png): miss preserves preview; visible grab starts without jumping | `100/300, r6, u1`, held | `100/700, r136, u0`, held | Pass |
| [Move then release](canvas/10-numeric-grab-moved.png) / [spatial](spatial/10-numeric-grab-moved.png): movement refines the same pending edit | `100/320, r6, u1`, released | `100/917, r136, u0`, released | Pass |
| [Released draft](canvas/11-before-regrab.png) / [spatial](spatial/11-before-regrab.png): first drag remains visible and pending | `100/300, r8, u1` | `100/698, r138, u0` | Pass |
| [Re-grab and move](canvas/12-regrab-moved.png) / [spatial](spatial/12-regrab-moved.png): second grab retains displayed X and original baseline | `100/310, r8, u1` | `100/807, r138, u0` | Pass |
| [Held Right](canvas/13-held-arrow.png) / [spatial](spatial/13-held-arrow.png): arrow adds a step while pointer ownership stays live | `100/310, r10, u1`, held | `100/748, r140, u0`, held | Pass |
| [Move after Right](canvas/14-held-arrow-moved.png) / [spatial](spatial/14-held-arrow-moved.png): pointer keeps moving and retains arrow step | `100/330, r10, u1`, held | `100/965, r140, u0`, held | Pass |
| [Held commit](canvas/15-held-mixed-commit.png) / [spatial](spatial/15-held-mixed-commit.png): Enter adds exactly one undo unit and ends pointer ownership; late motion/release and repeated Enter do nothing | `330/330, r11, u2`, no draft | `965/965, r141, u1`, no draft | Pass |
| [Undo and cancellation](canvas/16-mixed-cancel.png) / [spatial](spatial/16-mixed-cancel.png): one undo returns to baseline; a fresh held mixed edit cancels and late events cannot revive it | `100/100, r12, u1`, no draft | `100/100, r142, u0`, no draft | Pass |

The assertions also verify each mixed command retains the original committed
before-value and revision. The spatial movement check compares against a
separately sampled native pointer move plus the arrow step, avoiding a test
that merely accepts any changed value.

The regression was run before the repair: canvas failed 12 of 17 mixed checks;
spatial failed 6 of its first 7 checks and then aborted because the original
miss path deselected the handle. Thus spatial's fail-first run did not execute
all 17 checks. Logs and captures remain outside tracked source in
`/tmp/moxi-i19-repair-failfirst/`.
The independent review probe then passed 10/10 checks for each consumer,
including visible numeric grabs, released re-grabs, held-arrow motion and
one-step undo. Its local logs are in `/tmp/moxi-i19-repair-independent/`.

Spatial drag preview is 698 milliworld units at the sampled native handle grab;
exact entry refines it to 700 before commit. Replay records the semantic value,
independently of that screen-space sampling.

Independent literal wire fixtures passed. Additional native assertions passed
for stale rejection with an existing
preview; wrong operation/target and original X; invalid JSON shapes, versions,
types, revisions and ranges; empty edits; invalid/fractional numeric entry;
both drag bounds and returning from a bound; exact endpoints; Enter commit;
replay at later matched revisions; held-pointer focus/capture/resize
cancellation; and spatial history rollover with fixture reservation retirement.
These assertions establish transaction behavior beyond the screenshots.

Build output contains a linker warning that a Mojo archive targets macOS 27.2
while the executable links for 27.0. Build and both replays succeeded on 27.2.1;
compatibility with 27.0 was not checked.

## Deck inspection

Final-deck browser inspection ran at 2026-11-26 04:36 UTC in isolated headless
Chrome 158.0.8127.37 at a 1200 × 831 viewport and scale 1, through a temporary
loopback server on `http://127.0.0.1:61008/index.html`. The user's Chrome access
host was unavailable, so cached local Playwright launched installed Chrome in
an isolated temporary profile. No installation or account connection was used.

Observed: all 64 main/thumbnail images loaded from embedded PNG data, with no
external asset requests. Next and left/right arrow navigation updated the
32-slide counter. Contact-sheet selection opened canvas slide 14 and spatial
slide 30, showing pointer movement after a held arrow step. Both browser frames
and the corresponding 2640 × 1600 native captures were visually inspected.

Navigation to slides 31 and 32 and all loaded images still worked after
stopping the server. Direct `file://` opening also loaded all 64 images, and
Left wrapped from slide 1 to 32. No script exception or failed HTTP response
was observed. Browser captures, the reproduction script and measured output
remain local in `/tmp/moxi-i19-repair-browser/`; no server remains running.

Native build/replay logs: `/tmp/moxi-i19-build.log`,
`/tmp/moxi-i19-canvas.log`, `/tmp/moxi-i19-spatial.log`.
Gallery/hash checks: `/tmp/moxi-i19-repair-gallery.log`,
`/tmp/moxi-i19-repair-render-only.log`.
Original regression output: `/tmp/moxi-i19-repair-node.log`.

## Limits

Confidence is high for these bounded native transaction flows. Physical
keyboard/mouse input, human usability, accessibility and VoiceOver, IME,
other platforms, performance, multi-object behavior and persistence/reload
were not tested. VoiceOver remained paused. Repository-wide checks were
skipped. Failures in those untested environments or input paths would narrow
the conclusion; this record makes no broader acceptance claim.
