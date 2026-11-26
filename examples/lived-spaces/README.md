# Compose a timed exhibit reveal

Run `examples/lived-spaces/run.sh` from the repository root on macOS with the Xcode command-line tools and an active graphical session. The script compiles the local Moxi spatial core and opens a 920 × 585 pt AppKit window. No package install or network access is required.

The north and south visitors walk opposite sides of a partition on two authored 7 m paths, taking 14 s and 10 s respectively. Scrub or play elapsed time to compare them. Gray intervals mark occlusion at the visitor’s eye height. Teal intervals mark a clear view of the exhibit’s center. The preview uses Moxi’s orthographic projection and nearest triangle hit on the finite eye-to-exhibit segment. Each visibility strip samples at 0.1 s intervals. The cursor tests the exact current position.

At 7 s on North, move the partition +1 m. The north sightline turns red while the south visitor can still see the exhibit. Move the light peak later. The exhibit brightens even though North cannot see it. Undo twice to unwind timing and geometry in order. Route switches and scrubbing preserve edit history. The light envelope rises over 2 s and falls over 4 s. Playback stops at the end of the selected route.

## Reproduce the check

From a clean committed example, run `python3 examples/lived-spaces/gallery.py`. It builds and launches the same window, activates native controls, dispatches keyboard equivalents, checks model values and focus, and captures the window content. It validates the eight PNGs and builds the [offline slideshow](../../artifacts/demo-slideshows/lived-spaces/index.html) using the repository gallery renderer. The manifest records the tested source revision, host, scale, actions and expected results. To run the checks into an existing temporary directory without updating the gallery, pass `--check DIRECTORY` to the launch script.

| Scenario | Reproducible observation |
| --- | --- |
| V09 linked edits | At 7 s, changing partition offset from 0 to +1 m blocks only North. Moving the peak from 6 s to 7 s changes intensity from 75% to 100%. The first undo restores 75% with North still blocked. The second restores clear sight and empty history. |
| Failure | Restoring before setting a checkpoint reports the missing checkpoint. Moving below −2 m preserves the previous partition and history depth. |
| I07 checkpoint | Switch to South, scrub to 5 s, move the partition −1 m. Set a checkpoint after action three. Explore an earlier peak and another partition move. Restore to the saved route, time, score and undo history. The checkpoint restores state in memory. Recording an authored sequence and resuming its later actions after exploration remain open. |
| I06 semantic zoom | Command-F from the plot selects the width term. Command-D opens its definition. Command-D again returns keyboard focus and the original selection to the formula. The formula is read-only. |
| Timed preview | Play advances the shared cursor on the native run loop. Pause invalidates the timer. The check evaluates the rise, peak and fall for every allowed peak time. |

The evidence covers a synthetic exhibit and automated AppKit interaction. A designer trial remains necessary to assess whether editing both views helps someone create and explain a reveal. Physical illumination, visitor behavior, end-to-end timing accuracy, hardware keyboard use, VoiceOver and other operating systems remain unverified. There is no sensor or building-control connection.
