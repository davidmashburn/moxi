# Compose a timed exhibit reveal

Run `examples/lived-spaces/run.sh` from the repository root on macOS with the Xcode command-line tools and an active graphical session. The script compiles the local Moxi spatial core and opens a 1260 × 714 pt AppKit window. No package install or network access is required.

The north and south visitors walk opposite sides of a partition on two authored 7 m paths, taking 14 s and 10 s respectively. Scrub or play elapsed time to compare them. Gray intervals mark occlusion at the visitor’s eye height. Teal intervals mark a clear view of the exhibit’s center. The floor view uses Moxi’s orthographic projection; visibility uses the nearest triangle hit on the finite eye-to-exhibit segment. Each visibility strip samples at 0.1 s intervals. The cursor tests the exact current position.

The two **Visitor-eye preview** images show both routes at the shared cursor time, beside the floor and score. Each perspective camera sits at the existing route eye, 1 m above the floor, and aims at the exhibit center with a 50° vertical field of view. The teal border identifies the selected route. Switching routes changes selection and the time slider’s range while keeping the shared score and edit history. If North’s time exceeds South’s 10 s duration, South’s camera stays at its endpoint and is labeled **ended**; its cue still uses the shared time.

These are **stylized** views, as labeled in the UI. Rays use the same partition triangles and nearest-hit routine as the sightline test, with the floor beneath the visitor. A small sphere is a display marker for the exhibit point. The open reticle and clear/occluded label refer to that point’s center, not the visibility of an entire object. The light envelope shades only the marker: there is no photometric lighting, shadow, glare, material or exposure simulation. Camera aim is fixed toward the exhibit rather than along the walking direction.

At 7 s on North, move the partition +1 m. The north sightline turns red while the south visitor can still see the exhibit. Move the light peak later. The exhibit brightens even though North cannot see it. Undo twice to unwind timing and geometry in order. Route switches and scrubbing preserve edit history. The light envelope rises over 2 s and falls over 4 s. Playback stops at the end of the selected route.

## Perform an explanation

Choose **Record new** (⌘1) to start from the current visitor, elapsed time, score and undo history. Switch route, scrub to 4 s, move the partition −1 m, move the peak later, then scrub to 5 s. Choose **Finish** (⌘1). The selectable text lists the five accepted actions. A slider drag contributes one destination on release. Undo is itself recordable. Starting a new recording replaces the previous one. Recordings last for the current window session.

**Step** (⌘2) starts at the recorded origin and performs one action per press. **Play steps** (⌘3) performs a step immediately and advances once per second until paused or finished. The arrow marks the last performed step. At step three choose **Explore** (⌘4) and try a different route, time or score edit. **Return** (⌘4) restores the third step with its undo history. Press ⌘2 twice to finish. Undo first reverses the lighting edit, then the partition edit. The ordinary route preview and manual checkpoint remain available in the studio.

## Reproduce the checks

Run `examples/lived-spaces/run.sh --check-model` for the headless perspective/visibility check. Run `examples/lived-spaces/run.sh --check DIRECTORY` using an existing output directory for V09 and I06, and `--check-performance DIRECTORY` for recording, branch, return and ordered undo through native controls. After committing the tested sources, `python3 examples/lived-spaces/gallery.py` runs all three checks and refreshes this example’s [slideshow and verification record](../../artifacts/demo-slideshows/lived-spaces/README.md). Its manifest identifies the exact source revision and hashes.

| Scenario | Reproducible observation |
| --- | --- |
| V09 linked edits | At 7 s, changing partition offset from 0 to +1 m blocks only North. Moving the peak from 6 s to 7 s changes intensity from 75% to 100%. The first undo restores 75% with North still blocked. The second restores clear sight and empty history. |
| Visitor-eye comparison | The partition hides North’s marker while South’s marker remains visible and brightens with the cue. Switch to South at 7 s, then undo timing and geometry successively without losing history. At shared 12 s, South is labeled ended at its 10 s endpoint. |
| Perspective geometry | Across 1,410 route/time/partition cases, the preview’s center surface agrees with an independent finite-segment/partition-plane test and the existing sightline model. Off-center wall, floor orientation, cue color and endpoint checks cover the stylized rendering. A zero-distance wall hit preserves the existing core behavior when an eye lies on the partition. |
| Failure | Restoring before setting a checkpoint reports the missing checkpoint. Moving below −2 m preserves the previous partition and history depth. |
| Manual checkpoint | Switching to South, scrubbing to 5 s and moving the partition −1 m sets up a checkpoint. Restoring after exploration recovers the saved route, time, score and undo history. |
| I06 semantic zoom | Command-F from the plot selects the width term. Command-D opens its definition. Command-D again returns keyboard focus and the original selection to the formula. The formula is read-only. |
| Timed preview | Play advances the shared cursor on the native run loop. Pause invalidates the timer. The check evaluates the rise, peak and fall for every allowed peak time. |

The evidence covers a synthetic exhibit, automated AppKit interaction and visible control checks in the normally launched app. Independent designer assessment and photometric validation remain open. Physical illumination, visitor behavior, end-to-end timing accuracy, sustained playback performance, smaller displays, hardware keyboard use, VoiceOver and other operating systems remain unverified. There is no sensor or building-control connection.
