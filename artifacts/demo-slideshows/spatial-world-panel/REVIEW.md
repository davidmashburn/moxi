# D08 gallery review — published d7fa3ed

The six frames were regenerated from `d7fa3ed563948860f4baf18bcc9f3eb279197135`
and individually visually inspected on November 20, 2026. Scenario outcomes are
**4 pass, 2 partial, 0 blocked**. All six bounded replay scenarios completed their
assertions; “partial” records the remaining text/IME/semantic acceptance limits,
including the intentional rejection of native world editing. It does not mean a
missing frame or a failed replay. See [review.json](review.json) for per-frame hashes,
steps, expectations, observations, limits and review time.

This follows section 2 of `origin/project-planning:PROJECT-PLANNING.md`, observed at
planning commit `2e46d93667166d077e47311277689c54d35942dc`. Read that exact plan with
`git show 2e46d93667166d077e47311277689c54d35942dc:PROJECT-PLANNING.md`.
Only this gallery's evidence and supporting tooling changed. Application code,
the common handoff, master index, and other galleries were not edited.

## Scenario review

All image links refer to the retained, ignored, full-resolution local PNGs.
The assertions are in the published [replay](../../../examples/spatial-world-panel/main.mojo)
and [native contract helpers](../../../examples/spatial-world-panel/host.m).
All three full replay logs linked below contain the required PASS markers.

| Scenario / frame | Outcome | Steps and expected result | Visual observation and executable evidence |
| --- | --- | --- | --- |
| [01-oblique](01-oblique.png) | pass | Launch the ordinary-controls probe on an oblique plane. Expect text, button and slider on the same perspective texture. | Oblique panel, “Spatial ordinary controls”, Apply 0 and shared level 40 are legible. Text is visibly rasterized/softer than the screen editor. Real Metal draw and snapshot succeeded; this is bounded transform evidence, not native world text usability. |
| [02-capture-outside](02-capture-outside.png) | pass | Emulate slider drag from local x=100 to x=500 on a 400-point panel; retain capture until release. | Shared level 100 and slider at its right endpoint. Replay asserts active drag/value 100 before this frame and released drag afterward. The still image alone cannot prove capture. |
| [03-text-focus-failure](03-text-focus-failure.png) | partial | Click button and text, retain field identity/focus, compare the source caret with its world projection. | Apply 1 / shared level 100; explicit WORLD FAILED message. Focus ID 1 and field identity are asserted. Source caret (26,58) requires projected (388.6212295,259.6678345), so IME geometry fails. World semantic children/focus are suppressed, not transformed. Geometry rejection is verified; native world text/IME/AX acceptance remains unsupported. |
| [04-hidden-click](04-hidden-click.png) | pass | Clip the left half and place real foreground geometry over the right; probe both hidden targets. | Left side is cut off; red foreground object visibly occludes the controls. Both direct route calls assert HIDDEN. This verifies replay/picking policy, not a physical pointer or accessibility hit test. |
| [05-screen-editor](05-screen-editor.png) | partial | Switch the same model to the projected screen editor; exercise text protocols, selection, clipboard, Tab/Enter/arrows. | Axis-aligned, crisp controls show “Spatial ordinary controls · native”, Apply 2 and shared level 99. Native text/button/slider roles and owner-local frames pass; caret (398.0930176,273.0361328) is inside the screen field. Named AppKit clipboard/selection/marked-text/insertion and ordinary App keyboard/clipboard checks pass. Physical IME candidates, keyboard layouts and AT usability remain untested. |
| [06-cancel-recovery](06-cancel-recovery.png) | pass | Return to world mode, provisionally drag, then Escape. Expect level 99 restored, no active drag, and rejection retained. | Same edited text, Apply 2 and shared level 99 are visible on the plane. Replay asserts restored value/no drag; final NOT PROMOTED message is fully legible. This establishes in-memory mode/cancel state, not persistence across restart. |

No blank, missing or unexpectedly clipped frame was found. Frame 04's clipping is
intentional. The geometry assertions, rather than the captions alone, establish
the corresponding interaction outcomes. See [replay-0](review-logs/replay-0.log),
[replay-1](review-logs/replay-1.log) and [replay-2](review-logs/replay-2.log).

## Geometry and promotion decision

Confidence is **high** that world panels must remain rejected. The actual source
caret differs materially from its projected destination; native roles/rectangles
are axis-aligned owner coordinates, and world accessibility children are explicitly
suppressed on both owners. No transformed semantic target is supplied. The screen
alternative uses the same ordinary `App[Controls]`, focus IDs and model; native
screen roles/frames and caret containment pass. These checks do not establish a
working native world field editor. The replay exercises synthetic source-owner
composition callbacks and screen protocols; physical world typing and candidate
placement were not tested. The world text-event rejection branch is source-inspected,
not separately driven by the recorded replay.

A coherent native transformed IME/semantic geometry contract, followed by physical
IME, human and assistive-technology validation, would change that assessment.
[decision.json](decision.json) is retained unchanged. D05's production renderer
decision remains unselected/OPEN; no production renderer or accessibility support
is promoted by this evidence.

## Provenance, comparison and verification

Capture began at `2026-11-20T22:49:57Z`. Host: macOS 27.2 arm64; Mojo
`1.1.0 (8189361e)`, Apple clang `21.0.0 (clang-2100.3.34.2)`, SDK 27.0.
No user account/data fixture is used. The ordinary synthetic model starts at text
“Spatial ordinary controls”, count 0, level 40. Canvas: 1000×710 points;
captures: 2000×1420 pixels (2 pixels/point). Source owner: 400×240; copied-image
depth target: 940×420 at scale 1. Fixed camera: yaw 0.55, pitch 0.22, distance 6;
plane origin (-2,1.2,0), edges (4,0,0) and (0,-2.4,0).

The 189-file source fingerprint before and after build/replay is
`3a5c2de74340be52b381b84f7e5f8802a7325adb513797be706b6129a722667a`.
Scoped source status was clean. [verify.py](verify.py) independently compares every
file hash with the Git bytes at the captured revision, checks the current scoped
file set, binary hash/size, wrapper hash, six PNG hashes/dimensions, every referenced
HTML frame, retained logs and all timing samples/quantiles. The captured
[source-before record](review-logs/source-before.json) and [provenance](provenance.json)
agree. New artifact files are outside the capture's source scopes; no application
or original gallery source was modified to obtain a match.

The baseline is the gallery metadata tracked in `d7fa3ed`, recording an uncommitted
`bd3cccdb96f9136fda303ee4ca7517116e9e885a` tree captured November 6. Its source
fingerprint is `f6093658eb10a518d2e93b585bce59d0d59195424f76309a811a01fcdf2099f2`:
186 files versus 189 now; 18 changed, 3 added, none removed. The D08 example files
are unchanged. All six scenario IDs/actions/expected results and image dimensions
are unchanged; **all six PNG hashes differ**. [review.json](review.json) records
both hashes for every frame and the complete source-file delta. Original PNG bytes
were absent from both this checkout and the main implementation checkout, so a
pixel-difference or before/after visual comparison was **not possible**. Changed
hashes establish different bytes, not a diagnosed rendering regression. The baseline
host was macOS 27.0.1; compiler, SDK and lock hash match. Timing observations are
not a controlled performance comparison across source, host and concurrent load.

The original capture command exceeded its 240-second build bound:
[attempt log](review-logs/attempt-01-gallery.log), [build log](review-logs/attempt-01-build.log).
[capture.py](capture.py) retains the published replay/assertions, raises the per-command
bound to 900 seconds, and copies/normalizes log links. The successful build took
196.47 seconds; its [build log](review-logs/build.log) retains compiler deprecation
warnings. Three process runs overwrite the same six image names; only run index 2's
frames are retained. All three runs' logs and 3 cold / 90 warm samples are retained.
Idle checks assert 100 mappings without submission per process; 30 warm draws
retain targets/geometry with no scene upload (panel snapshots/uploads still occur).

The focused check command exited 0: **13/13 checks passed** (3 portable C++ tests,
3 native tests, 4 source-free Mojo consumers, 3 packaged application replays).
Reported assertion counts include 1,832 spatial contract, 2,522 assembly,
143 spatial native and 140 assembly native checks. Full outputs and compiler
logs are retained alongside [checks.log](review-logs/checks.log); [review.json](review.json)
records all 29 log hashes and each check's PASS marker. D06/D07 packaged replay
images are assertion-checked regressions, not visually certified galleries here.

## Reproduction and limits

Run from repository root on a macOS host with AppKit/Metal, Xcode tools and Pixi:

```sh
# Verify the retained reviewed set (local PNGs, HTML, logs and binary required).
python3 artifacts/demo-slideshows/spatial-world-panel/verify.py

# Regenerate a raw set; this invalidates the visual review and recorded log hashes.
pixi install --locked
python3 artifacts/demo-slideshows/spatial-world-panel/capture.py
bash examples/spatial-world-panel/check.sh --skip-build

# Inspect the original metadata for comparison without changing the checkout.
git show d7fa3ed:artifacts/demo-slideshows/spatial-world-panel/manifest.json
git show d7fa3ed:artifacts/demo-slideshows/spatial-world-panel/provenance.json
```

After recapture, inspect each frame and refresh `review.json` before treating it as
reviewed evidence. The verifier invokes the repository slideshow loader/render
directly for this gallery. `scripts/demo_slideshows.py --check` over the common root
would inspect other galleries; passing this gallery directory to that CLI would
validate zero manifests because it searches child directories. Neither is used as
a substitute for the focused check. The common HTML index is not regenerated.

These are real native AppKit offscreen `cacheDisplay` renders with an experimental
Metal copied-image depth pass; emulation applies to injected pointer/keyboard events
and text protocol calls. No browser mockup, software renderer or Xvfb display is
substituted. Offscreen rendering does **not** prove compositor/window visibility,
scanout, input-to-photon latency, physical capture-loss behavior, multi-DPI visual
quality or actual IME candidate placement. VoiceOver stays paused; no AT session or
physical input device exercise occurred. No user general clipboard is used (the
native test uses a unique named pasteboard). No human usability, sustained/thermal,
memory-pressure, distribution/fresh-host installation or production acceptance was
tested. No full repository suite or GitHub CI was run. The C++ scale checks do not
replace multi-DPI native visual acceptance.

Tracked files refreshed: README, manifest, provenance and timing. `decision.json`
stays tracked and unchanged. The capture/verification scripts, review files and
`review-logs/` are new, untracked integration candidates. Six PNGs and `index.html`
remain ignored under the existing policy; the executable and build outputs are
ignored under `dist/`. All remain available locally. No files were staged,
committed, pushed or written to an external service.

Published logs use placeholders for machine-local paths. For normalized logs,
`review.json` records hashes for both the original and published bytes.
