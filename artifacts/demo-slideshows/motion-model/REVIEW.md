# V01 — Motion from a sketch

Source revision: `0b96d2c906e99e927e8d4ad584df4516427ac598`.
The implementation and its test sources are preserved in local commits. This
folder contains compact evidence records; generated PNGs, HTML, build products
and command logs stay local and ignored. No shared ledger or gallery index was
changed. No external write, delegation or VoiceOver session was performed.

The initial worktree was clean. Relevant local branches, registered worktrees,
files and history were checked for reusable V01 work. The consumer reuses Moxi's
existing `App`, `Component`, `Scene` and Cocoa backend, and the mounted-control
replay pattern used by `examples/visible-proposals`. It introduces no framework
or dependency changes.

## Run and reproduce

From the repository root on macOS with Pixi:

```sh
python3 examples/motion-model/run.py
python3 examples/motion-model/reproduce.py
open artifacts/demo-slideshows/motion-model/index.html
```

To reuse an installed environment from another checkout, set
`MOXI_PIXI_MANIFEST=/path/to/checkout/pixi.toml`. The runner requires an identical
`pixi.lock` and compiles source/includes from this checkout. It creates an ordinary
`dist/motion-model/Motion Model.app`; `run.py --build-only` builds without running.

The optional offline viewer test requires Python Playwright and Chrome:

```sh
python3 examples/motion-model/check_slideshow.py
python3 tests/demo_slideshows_test.py
```

## Acceptance evidence

The [slideshow](index.html) contains seventeen distinct captures from the actual
mounted consumer. [verification.json](verification.json) records steps,
expectations, assertion outcomes, source/PNG hashes, capture times, viewports,
backend and fixture. [manifest.json](manifest.json) supports regenerating the
portable viewer. [slideshow-check.json](slideshow-check.json) records the separate
Chrome viewer check, including its version and HTML hash.

| Requirement | Observed outcome | Evidence |
| --- | --- | --- |
| I01 local formalization | Only the arm/pivot becomes executable; length editing and undo preserve the unfinished note and its document position | [Formalized](02-formalized.png), [sketch restored](15-sketch-undo.png) |
| Two coordinated motion states | TRACK/RETURN expressions drive the arm, state highlight, scrub cursor and executable response | [Parameter edit](03-parameters.png), model check |
| Ownership and draft boundary | Parameters preserve desired knots; pointer and keyboard drafts preserve parameters and committed target until accepted | [Pointer draft](04-target-draft.png), [keyboard draft](11-keyboard-draft.png) |
| I03 bounded alternatives | 117 discrete pairs; best three within six degrees knot RMS; preview stays separate; apply commits the pair as one undoable edit | [Alternatives](06-alternatives.png), [applied](07-applied.png) |
| Cancel, pins and stale results | Pending/ready cancellation, Escape then pointer release, draft undo, pinned endpoints and revision invalidation preserve committed state after later ticks | [Cancelled](09-cancelled.png), [pinned](11-pinned.png), [stale](14-stale.png) |
| Failed fit and recovery | An unsupported target remains visible, with best grid error; executable model retained; undo restores the target | [Unsatisfied](12-infeasible.png), [undo](13-failure-undo.png) |
| Layout | All controls remain inside the 960×760 content bounds | [Minimum window](16-minimum-window.png) |

The model check passed all 117 parameter pairs and 23,517 sampled bounds, with
independent analytic midpoint values, endpoint/transition checks and transaction
lifecycle assertions. The normal entry point's native replay passed all scenario
assertions without dropped events or command overflow. It uses native pointer,
keyboard and accessibility-press callbacks, regular `App.dispatch`, the normal
render path and deterministic frame ticks; it does not mutate the model directly.

The Chrome check decoded every full-size image and passed next/previous wrap,
arrow navigation, contact-sheet toggle/jump, reload and 390px viewport navigation
without page errors. The four existing slideshow validator tests passed. Captures
were visually inspected for alternatives, drafts, failure and minimum layout;
the candidate and minimum captures were inspected again after clean reproduction.

## Limits and review status

Captures are AppKit rasterizations of the actual mounted window's **content
view**, explicitly tagged `offscreen-render`. They include neither titlebar nor
desktop compositor. Normal app launch created an on-screen native window, as
confirmed by the system window list, but the computer-use tool returned
`cgWindowNotFound`; direct window capture also failed with `could not create
image from window`. No permission settings were changed.

Physical keyboard/mouse input, VoiceOver (explicitly excluded), wall-clock
responsiveness, other backends/OS versions, a display-scale matrix and independent
human understanding were not tested. The full repository test suite was skipped;
this change adds a consumer without editing framework code. Review here is local
source inspection and verification; independent parent review remains pending.

This is a fixed two-state model and nine authored target samples. Endpoints and
the 80-degree execution cap are fixed constraints. The search reports
infeasibility only within its finite parameter grid, not for arbitrary programs
or continuous optimization; RMS is evaluated at the nine knots. There is no
save/load, arbitrary graph editing, obstacle solver or general language editor.
Undo retains the last 64 document edits. No human efficacy claim is made.

Confidence is high for the bounded behaviors exercised here. A reproducible
failure through physical native input, a viewport/display discrepancy, or a
counterexample to the ownership/revision assertions would change that assessment.
