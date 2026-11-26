# V10 and I04 verification

On 2026-11-25 the standalone app opened on macOS 27.2.1 (arm64). A worktree-local Pixi environment was installed from the lockfile offline. The native accessibility replay passed in two fresh processes. The manifest identifies the tested implementation revision, fixture, capture time, viewport, action and expected observation for each PNG.

| Action | Observed result | Outcome |
| --- | --- | --- |
| Open a fresh session | Commons divides 12 plots evenly. Fern lacks two gardens, Ash lacks one grove plot and Pip's play request is met. | Pass |
| Change each owner's minimum independently | All three new thresholds appeared. Restoring Ash and Pip left Fern at five. Allocation counts stayed fixed. | Pass |
| Increase supply | Each branch gained one garden plot. | Pass |
| Move one Commons play plot to grove | Commons became 5/5/3. Orchard and Glade retained their allocations. | Pass |
| Review Commons, enter a reason and promote | Promotion was disabled before the reason. The decision displayed the reason and Pip's one-plot shortfall. | Pass |
| Restore the play plot | The live comparison now met Pip's minimum. The recorded decision still showed Pip one short. | Pass |
| Undo promotion | The decision cleared and undo became disabled. The live 5/4/4 edit remained. | Pass |

The static table's six rows conserve supply and their 18 owner outcomes agree with their thresholds. Offline Chrome 158.0.8127.37 decoded all seven full images and seven thumbnails. Arrow keys, Previous, Next and thumbnail selection passed. Open the [slideshow](index.html) for the captured states.

The linker reported a macOS 27.2 object linked against target 27.0. Execution was verified on 27.2.1 only. The repository-wide suite, other platforms, physical keyboard input, VoiceOver and participant sessions were outside this check. Negotiation benefit over the static table remains open.
