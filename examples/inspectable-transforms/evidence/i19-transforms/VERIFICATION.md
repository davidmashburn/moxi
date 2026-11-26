# Native I19 verification

Implementation: `0eb2dbed189a357a6331efbd0aee017fb8927710`, on public
base `033596ddb576b09b48234733b45a283b4c3fecae`. Capture began
2026-11-26 04:07:15 UTC with the implementation committed and unchanged.
Only the scoped evidence directory was untracked. The retained
[provenance](provenance.json) records source/artifact hashes and the exact
toolchain; the [manifest](manifest.json) records each action, expectation,
observation and outcome. [Open the offline deck](index.html).

The environment was macOS 27.2.1 arm64, Mojo 1.1.0 (8189361e), Apple clang 21,
and the public experimental Metal spatial renderer. Native content size was
1200 × 760 points, then 1320 × 800 after actual window resize, at 2× display
scale. All 16 PNG dimensions match the observed size and scale. Fixtures are
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
tests passed 2/2. Retained source and artifact hash verification passed.
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

Final-deck browser inspection ran at about 04:08 UTC in managed Chromium 158
at a 1200 × 831 viewport, through a temporary loopback server on
`http://127.0.0.1:8951/index.html`. The user's Chrome host was unavailable;
the browser tool also blocks direct `file://` navigation.

Observed: all 32 main/thumbnail images loaded from embedded PNG data; no
external asset references; Next and left/right arrow navigation updated the
slide counter; selecting spatial replay displayed slide 15 with its
2640 × 1600 native image. The contact sheet and representative native frames
were visually inspected. Navigation from slide 15 to 16 and all loaded images
still worked after stopping the server. The only browser console error was an
automatic loopback `favicon.ico` 404; no script exception was observed.

Direct browser opening of the file remains unverified because of the tool's
protocol restriction. The deck embeds its images, script and styles; its
offline portability is supported by content inspection and the stopped-server
check. Browser captures and console/snapshot logs remain local in
`/tmp/moxi-i19-browser/`; no server remains running.

Native build/replay logs: `/tmp/moxi-i19-build.log`,
`/tmp/moxi-i19-canvas.log`, `/tmp/moxi-i19-spatial.log`.
Gallery/hash checks: `/tmp/moxi-i19-gallery.log`,
`/tmp/moxi-i19-retained-evidence.log`.
Original regression output: `/tmp/moxi-i19-original-tests.log`.

## Limits

Confidence is high for these bounded native transaction flows. Physical
keyboard/mouse input, human usability, accessibility and VoiceOver, IME,
other platforms, performance, multi-object behavior and persistence/reload
were not tested. VoiceOver remained paused. Repository-wide checks were
skipped. Failures in those untested environments or input paths would narrow
the conclusion; this record makes no broader acceptance claim.
