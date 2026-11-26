# Lived spaces verification

V09 now has paired visitor-eye previews in the existing native studio. Open [the slideshow](index.html) directly from disk for 17 replay captures, or inspect the five [normal UI captures](visible-ui/captures.json). Both sets show the same synthetic scene, shared score and cursor. The preview is explicitly labeled **Stylized · fixed aim at exhibit center** and **Cue shades marker only · not photometric**.

## Tested environment and provenance

The source revision is `2852b7d23c729acd51819537688b2062ca903302`, based on public `aedd058d1ac9605d25a4b0660c93c9220901362f`. Before implementation, `git ls-remote origin refs/heads/main` returned that base SHA and the clean isolated branch advanced with `git merge --ff-only aedd058`. Planning was read, without changes, from `project-planning` at `59e0be2`: `DEFERRED-IMPLEMENTATION-MASTER.md`, `PROJECT-PLANNING.md` and `ideas/v09-compose-lived-spaces.md`. This evidence closes the documented preview gap only.

The final checks ran on November 25, 2026 local time (November 26 UTC), macOS 27.2.1 arm64, Apple Clang 21.0.0, with `-Wall -Wextra -Werror -O2`. The AppKit content area was 1260 × 714 pt at 2× in dark appearance. No browser, remote account or external fixture was involved in the native checks. The [manifest](manifest.json) records capture time, source hashes and each frame's steps and expected state. [Check results](checks.json) retain commands, exit codes and complete stdout/stderr.

The visible UI was separately launched from the same built executable and exercised through actual controls using computer-use UI automation. A temporary `.app` wrapper under ignored `dist/lived-spaces` let the automation select the native app; nothing was installed on the system. These five captures include the title bar (2520 × 1492 px), while replay PNGs capture the content (2520 × 1428 px). Visible captures preceded the source commit; the wrapper's executable SHA-256 exactly matched the executable rebuilt by the final committed-source checks: `4433926276ad127d72636fc6b518ef048462ba217576bcdfefa3663995c000e7`. There is no known source mismatch. [Capture metadata](visible-ui/captures.json) records individual timestamps and hashes. The JPEG bytes returned by the capture tool are preserved under `.jpg` filenames.

## Commands

From the repository root, with an active macOS graphical session:

```sh
examples/lived-spaces/run.sh --check-model
examples/lived-spaces/run.sh --check artifacts/demo-slideshows/lived-spaces
examples/lived-spaces/run.sh --check-performance artifacts/demo-slideshows/lived-spaces/performance
```

`python3 examples/lived-spaces/gallery.py` runs those three commands and rebuilds this example's manifest and offline slideshow. It requires clean committed sources and creates its output directories. `examples/lived-spaces/run.sh` opens the ordinary app. No package installation is needed. Reproduce the visible sequence by clicking Partition +1 m, Peak later, Switch route, Undo edit, Undo edit after launch at 7 s.

## Results

All three commands exited 0. All 17 replay frames were visually inspected together, and the five normal UI captures were inspected at capture time. Image decoding and manifest/source hashes passed. Behavioral results below combine direct native state assertions with the linked visible evidence; screenshots alone do not establish history or focus state.

| Scenario and steps | Expected result | Observed result and evidence | Outcome |
| --- | --- | --- | --- |
| Initial North, shared 7 s | Both centers visible, cue 75%, no edits | Both markers visible; score 75%; empty history. [Normal launch](visible-ui/01-baseline.jpg), [replay](01-routes.png). | Pass |
| Partition +1 m, then peak later | North hidden; South visible; cue 100%; two edits | Wall hides North's center; South's marker brightens. Native score/history assertions agree. [Partition](02-partition.png), [cue](03-peak.png), [visible UI](visible-ui/02-partition-cue.jpg). | Pass |
| Switch to South at 7 s | Selected border changes; time, score and two edits retained | South selected, North occluded, cue 100%, two edits retained. [Replay](09-south.png), [visible UI](visible-ui/03-south.jpg). | Pass |
| First undo on South | Timing restored; North remains hidden; one edit | Peak 6 s, cue 75%, history 1; South selection/time retained. [Replay](10-undo-light.png), [visible UI](visible-ui/04-undo-light.jpg). | Pass |
| Second undo on South | Geometry restored; North revealed; history empty | Partition 0 m, North marker visible again, history 0; South retained. [Replay](04-undo.png), [visible UI](visible-ui/05-undo-partition.jpg). | Pass |
| North cursor at 12 s | South eye remains at its 10 s endpoint; shared cue uses 12 s | South is labeled ended at 10 s; both previews show the shared 0% cue. Model checks verify actual positions. [Ended route](11-ended.png). | Pass |
| Perspective model across both routes, five partition offsets and 141 times | Center depth agrees with independent finite-segment geometry and existing sightline model | 1,410 cases passed, including zero-distance wall hits. Off-center wall, floor orientation, cue color and clamped endpoint checks also passed. [Model output](checks.json). | Pass |
| Invalid edit and manual checkpoint | Range rejection preserves accepted history; restore recovers route/time/score/history | Rejection at −2 m retained three edits; restore returned South 5 s, partition −1 m, peak 6 s, one edit. Missing-checkpoint failure was also asserted. [Rejected](05-rejected.png), [restored](06-restored.png). | Pass |
| I06 Command-F, Command-D, Command-D via native key events | Define width, then restore formula focus and selected term | Definition displayed; original width selection and first responder restored. [Definition](07-definition.png), [selection](08-selection.png). | Pass |
| I07 record five actions; replay to third, explore, return, step twice | Authored sequence persists; third-step route/time/score/history restored; endpoint recovered | Native equality assertions passed; previews followed authored, explored and restored states. [Authored](performance/01-authored.png), [exploring](performance/02-exploring.png), [returned](performance/03-returned.png), [resumed](performance/04-resumed.png). | Pass |
| I07 successive undos after replay | Cue undo returns third-step score/history; geometry undo preserves pre-recording history | Both snapshots recovered; South marker revealed after geometry undo; manual checkpoint still restored the origin. [Cue undo](performance/05-undo-light.png), [partition undo](performance/06-undo-partition.png). | Pass |
| Scrub, play and pause; allowed cue peaks | Shared cursor advances, timer stops, rise/peak/fall values remain correct | Native run-loop advancement and timer invalidation passed; all allowed peaks' envelope landmarks passed. [Check output](checks.json). | Pass |

## Remaining gates and limits

Confidence is high that this bounded example's preview gap is closed: independent geometry checks, native interaction assertions and normal UI captures agree. A disagreement between the preview center and existing sightline model, or a route switch/undo that changes shared history, would overturn that conclusion.

Independent designer assessment and photometric validation remain **open**. The camera is fixed toward the exhibit point; the sphere is a display marker, not a full exhibit visibility model. The cue changes marker color only. Physical lighting, glare, materials, exposure, visitor behavior and physical timing were not validated. No sensor or building-control connection was added.

The repository-wide suite, other operating systems, smaller displays, hardware keyboard input, VoiceOver, sustained playback performance and end-to-end timing accuracy were not checked. I06 keyboard coverage used native synthesized key events. The offline slideshow's browser navigation was not re-exercised in this pass. No remote writes, shared ledger updates, system installations or external assessments were performed. All changes and evidence are confined to this example and its own artifact directory.
