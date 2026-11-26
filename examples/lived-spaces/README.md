# Compose a timed exhibit reveal

Run `examples/lived-spaces/run.sh` from the repository root on macOS with the Xcode command-line tools and an active graphical session. The script compiles the local Moxi spatial core and opens a 920 × 714 pt AppKit window. No package install or network access is required.

The north and south visitors walk opposite sides of a partition on two authored 7 m paths, taking 14 s and 10 s respectively. Scrub or play elapsed time to compare them. Gray intervals mark occlusion at the visitor’s eye height. Teal intervals mark a clear view of the exhibit’s center. The preview uses Moxi’s orthographic projection and nearest triangle hit on the finite eye-to-exhibit segment. Each visibility strip samples at 0.1 s intervals. The cursor tests the exact current position.

At 7 s on North, move the partition +1 m. The north sightline turns red while the south visitor can still see the exhibit. Move the light peak later. The exhibit brightens even though North cannot see it. Undo twice to unwind timing and geometry in order. Route switches and scrubbing preserve edit history. The light envelope rises over 2 s and falls over 4 s. Playback stops at the end of the selected route.

## Perform an explanation

Choose **Record new** (⌘1) to start from the current visitor, elapsed time, score and undo history. Switch route, scrub to 4 s, move the partition −1 m, move the peak later, then scrub to 5 s. Choose **Finish** (⌘1). The selectable text lists the five accepted actions. A slider drag contributes one destination on release. Undo is itself recordable. Starting a new recording replaces the previous one. Recordings last for the current window session.

**Step** (⌘2) starts at the recorded origin and performs one action per press. **Play steps** (⌘3) performs a step immediately and advances once per second until paused or finished. The arrow marks the last performed step. At step three choose **Explore** (⌘4) and try a different route, time or score edit. **Return** (⌘4) restores the third step with its undo history. Press ⌘2 twice to finish. Undo first reverses the lighting edit, then the partition edit. The ordinary route preview and manual checkpoint remain available in the studio.

## Reproduce the checks

Run `examples/lived-spaces/run.sh --check-performance DIRECTORY` using an existing output directory to verify the recording, branch, return and ordered undo through the native controls. Use `--check DIRECTORY` for the earlier V09 and I06 scenarios. The [original eight-frame slideshow](../../artifacts/demo-slideshows/lived-spaces/index.html) documents the pre-recording app at `ff5530d`.

| Scenario | Reproducible observation |
| --- | --- |
| V09 linked edits | At 7 s, changing partition offset from 0 to +1 m blocks only North. Moving the peak from 6 s to 7 s changes intensity from 75% to 100%. The first undo restores 75% with North still blocked. The second restores clear sight and empty history. |
| Failure | Restoring before setting a checkpoint reports the missing checkpoint. Moving below −2 m preserves the previous partition and history depth. |
| Manual checkpoint | Switching to South, scrubbing to 5 s and moving the partition −1 m sets up a checkpoint. Restoring after exploration recovers the saved route, time, score and undo history. |
| I06 semantic zoom | Command-F from the plot selects the width term. Command-D opens its definition. Command-D again returns keyboard focus and the original selection to the formula. The formula is read-only. |
| Timed preview | Play advances the shared cursor on the native run loop. Pause invalidates the timer. The check evaluates the rise, peak and fall for every allowed peak time. |

The evidence covers a synthetic exhibit and automated AppKit interaction. A designer trial remains necessary to assess whether editing both views helps someone create and explain a reveal. Physical illumination, visitor behavior, end-to-end timing accuracy, hardware keyboard use, VoiceOver and other operating systems remain unverified. There is no sensor or building-control connection.
