# Interrupt a recorded exhibition study

Captured 2026-11-26 UTC from the source committed as `dcee81e23b0a5ad5ccd38a64acbbe16d6878a8c2`, built by the example's run script on macOS 27.2.1 arm64. Each image shows the AppKit content view at 920 × 714 points, 2× scale. The synthetic fixture has two visitor routes, one partition and one light envelope.

Run `examples/lived-spaces/run.sh --check-performance DIRECTORY` with an existing output directory. The check clicks native buttons, sends slider actions and dispatches window keyboard equivalents. It starts on North at 7 s, moves the lighting peak earlier to 5 s and sets the ordinary checkpoint, giving the recording one pre-existing undo entry.

| Action through the window | Expected and observed result | Capture |
| --- | --- | --- |
| Record a route switch, seek to 4 s, partition −1 m, later peak and seek to 5 s. Finish recording. | Pass. The text lists five actions. Sending the same slider value again leaves the count at five. | [Authored path](01-authored.png) |
| Play on the native timer. Interrupt at step three. Undo the partition, switch visitor, seek to 9 s, move the peak earlier and the partition +1 m. | Pass. The branch shows North at 9 s, offset +1 m and peak 4 s. The textual path and step-three marker survive. | [Exploration](02-exploring.png) |
| Return from exploration. | Pass. South at 4 s, offset −1 m, peak 5 s and both original history entries match the recorded prefix. | [Restored prefix](03-returned.png) |
| Step twice. | Pass. The later peak and final seek produce the original endpoint and identical score history. South at 5 s sees a blocked sightline with 50% light. | [Resumed endpoint](04-resumed.png) |
| Undo once. | Pass. Peak 5 s gives 100% light. The partition remains at −1 m, South stays blocked and two history entries remain. | [Lighting undo](05-undo-light.png) |
| Undo again. | Pass. The partition returns to 0 m and the sightline clears. Light stays at 100% and the pre-recording history entry remains. | [Partition undo](06-undo-partition.png) |

The final assertion restored the independent manual checkpoint to the original route, time, score and history. The separate `--check DIRECTORY` run passed the original geometry, lighting, range rejection, checkpoint, preview timer and I06 formula focus/selection checks. The [historical gallery](../../demo-slideshows/lived-spaces/index.html) retains its original captures.

These runs exercise one synthetic scene on one Mac. Designer comprehension, physical lighting and visitor behavior, hardware keyboard use, VoiceOver, timing accuracy and other platforms remain untested. Recordings are session-local.
