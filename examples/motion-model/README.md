# Motion from a sketch

A native Moxi consumer for V01, including the mapped I01 sketch and I03 inverse
design behaviors. It mounts `MotionEditor(Component)` in `App`, draws the linked
arm, state graph and response through `Scene`, and uses the normal Cocoa backend.
There is no browser facsimile or separate test view.

From the repository root on macOS with the locked Pixi toolchain:

```sh
python3 examples/motion-model/run.py
python3 examples/motion-model/run.py --model-check
python3 examples/motion-model/reproduce.py
open artifacts/demo-slideshows/motion-model/index.html
```

`run.py` builds this checkout's source and native backend. To reuse another
checkout's already installed **locked toolchain**, set `MOXI_PIXI_MANIFEST` to its
`pixi.toml`; source and include paths still point to the checkout running the
command. No package is published or installed globally. Build products stay in
`dist/motion-model`.
The build also creates `dist/motion-model/Motion Model.app`, which can be opened
normally after `run.py --build-only`.

Start with **Formalize arm**. Only the arm and pivot become executable; the
unfinished note keeps its content and document position. Length changes the arm
geometry. Peak and turn change the executable response. Undo all document edits
to return to the original informal sketch, including its note.

The two states are TRACK and RETURN. With peak angle `A`, turn time `u` and
duration two seconds, TRACK evaluates `A sin(pi*t/(2*u))`; RETURN evaluates
`A cos(pi*(t-u)/(2*(2-u)))`. They join at the peak with zero angular velocity.
Playback resets after two seconds. Scrub, active state, arm angle, plotted curve
and displayed equations use this same model.

Orange handles edit **desired** angle samples at nine quarter-second knots.
Dragging shows a draft; release commits one edit, Escape cancels it. These edits
do not change executable parameters. The first and last knots are pinned to zero.
Tab through the controls and press Space to select/nudge knots, preview candidates
or control playback. Target +/− starts the same cancellable draft as dragging;
**Commit target** accepts it. Arrow keys retain Moxi's focus navigation. Cmd+Z undoes;
Cmd+Shift+Z redoes. Undo during a drag cancels just the uncommitted draft.

**Find alternatives** cooperatively checks 117 discrete peak/turn pairs, three
per frame. Peak is 20–80 degrees in five-degree increments; turn is 0.5–1.5 seconds
in eighth-second increments. Every candidate respects the endpoint pins and
80-degree angular cap. Up to three candidates with knot RMS error at most six
degrees are offered in deterministic error order. Green is a preview; blue stays
the committed implementation. **Apply preview** commits the selected parameter
pair as one undoable edit. The target remains intact.

Cancel works while searching and while previewing. Editing or undoing the
document invalidates any pending or ready result by revision. An impossible
target reports the best error within this grid and retains the implementation
and target. It does not claim global infeasibility. There is no arbitrary program
rewriting, continuous inverse optimizer, rigid-body simulator or obstacle solver.
The note is deliberately not a dependency. History retains 64 document edits.
This small session has no save/load feature; relaunch starts the documented
synthetic fixture.

`model_check.mojo` checks independent analytic values, all 117 model pairs and
23,517 sampled bounds, transaction ownership, proposal lifecycle and recovery.
The normal executable's `--replay DIRECTORY` option exercises its mounted
controls through native accessibility press callbacks, native pointer/key
callbacks and the same frame updates as interactive operation. It asserts
outcomes before capturing seventeen states, including pointer and keyboard
drafts, failed, cancelled, stale and minimum-window states. It never changes the
model directly.
It also checks that pointer down/move/up on either pinned endpoint preserves an
existing keyboard draft, then exercises commit, cancel, undo and redo. Four
supplementary `mixed-pin-*.png` captures show the retained drafts and commits.

`reproduce.py` builds and runs both checks, validates capture dimensions, hashes
source and PNG bytes, writes a per-scenario verification record, and renders
only this demo's offline slideshow. It leaves the shared gallery index and
implementation ledger alone. The published gallery includes its 17 PNG captures and generated HTML. The
manifest records the tested source revision and the verification record identifies each capture by its hash.
With Python Playwright and Chrome installed, the following additionally verifies
offline image loading, navigation, reload and a narrow viewport. This optional
dependency is not required to run the native consumer.

```sh
python3 examples/motion-model/check_slideshow.py
```

Capture limitation: the replay rasterizes the **actual mounted window's content
view** with AppKit `cacheDisplayInRect`, after rendering and displaying it. These
are real application pixels, tagged `offscreen-render` to distinguish them from
desktop-compositor window screenshots. Native event callbacks and synthetic
frame ticks are reproducible integration tests, not physical input, timing or
human usability tests. No VoiceOver, physical keyboard/mouse, other OS/backend,
HiDPI matrix, or independent human comprehension study is claimed.
