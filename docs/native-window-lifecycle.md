# Native window ownership and lifecycle

F02 adds explicit AppKit window instances and a two-window Moxi collection
workbench. Run `pixi run native-lifecycle` on macOS, or build with
`pixi run native-lifecycle-build` and open `dist/MoxiLifecycle.app`.
The application is compiled from `examples/native_lifecycle_workbench.mojo`;
it uses Moxi frames, native rendering, collection selection, text editing,
`MenuState`, and `DialogState`. It is not an alternative Cocoa-only demo.

## Ownership contract

`MacOSWindowInstance` in `moxi.native_instance` owns a native handle and renderer.
`open(config, x, y)` allocates a fresh session; `submit(packet)` selects it before
rendering, AX publication and presentation. Event polling, pumping, waiting,
menu and sheet operations also select the instance. `close()` disposes native
resources, and the destructor is a fallback. The caller owns the application
model, which can survive native close/reopen. Opening an already allocated
instance raises; dispose it first.

The AppKit ABI's 212 draw, event, image, editor, clip/cache, timing and AX fields
now live in `MoxiWindowState`. Each canvas, delegate and AX object has a weak
owner. Callback entry selects that owner and restores the previous context on
return, including nested callbacks. Disposal invalidates callbacks, cancels the
menu/sheet, disconnects native delegates, clears resources and removes the
handle. IDs are monotonic and retired IDs cannot select a replacement session.
Resetting input removes only that window's pending AppKit events; sibling input
and non-input events retain their queue order.

The supported profile is main-thread AppKit, at most eight explicit sessions.
Each session retains the established limits: 64 queued events, 1,024 widget
slots, 32,768 custom lines, 4,096 circles, 262,144 rectangles and 256 custom text
commands. Storage is allocated per instance rather than pooled globally; this
is intentionally a bounded profile, not a claim of unbounded windows or lower
memory use. Capacity exhaustion returns zero at the C boundary and raises in
the Mojo owner. Queue overflow counters belong to each window.

The legacy `NativeWindow` and renderer C ABI remain a selected-context transport,
with one lazily allocated compatibility session. A second live `open` in the
same session raises a native exception instead of replacing the first window.
Legacy close/reopen gets a fresh compatibility state. Multi-window callers
must use explicit owners and select before a complete submission; do not
interleave raw renderer calls from multiple sessions. The workbench uses
`MacOSWindowInstance.submit` to make that boundary explicit.

The application menu, clipboard, development task launcher and live-script
library remain process services. F02 does not promise independent hot-reload
libraries or multi-window Metal hosts. Timing files now append complete records,
so opening a sibling cannot truncate an existing trace; remove an old file
explicitly before starting a new measurement.

## Workbench behavior

A and B each own 100,000 stable row keys, a six-row viewport starting at row
50,001, selected-row text state and an edit dictionary. Only the visible rows
and selected editor are mounted. The fixture generates unique keys directly,
avoiding the generic collection reconciler's quadratic duplicate scan without
changing that API. Collection selection and reordering still use Moxi's
`CollectionSelection`.

- Select a row and edit its field. Next/Previous or scrolling leaves the page;
  returning to the key restores its edit.
- Actions opens an actual `NSMenu`. Jump to start, jump to row 50,001, or select
  the editor text. The result updates the existing portable `MenuState`.
- Reset label opens an actual window-attached `NSAlert` sheet. Apply resets only
  the selected row; Cancel retains it. `DialogState` controls application input
  while the sheet is open. Closing a window cancels its pending sheet.
- Drag a visible row onto another visible row to reorder within that window.
  Selection and edits follow stable identity. A cancelled gesture cannot move
  another window's rows. This is intra-window collection drag/drop; cross-window
  transfers, file drops and external pasteboard drag sessions are not supported.
- Close A using its title-bar close button. B remains usable. Click **Reopen
  other window** in B to create a new native A with its previous model. This is
  in-process retention, not persistence across application termination.

The fixed 560 × 640 content size keeps the evidence fixture deterministic.
The controls use the current native field editor. Automated composition paths
do not establish human IME acceptance. VoiceOver testing remains paused.

## Verification and evidence

Run `pixi run native-lifecycle-check` in a macOS graphical session. It builds
and executes two focused lanes:

1. `tests/native_window_ownership.m`: two real AppKit windows; distinct red/blue
   draw output while the other context is selected; image release; overlapping
   semantic IDs; event/AX targeting; independent overflow and gesture state;
   pending AppKit event retention during another window's input reset;
   stale callbacks after disposal; sibling survival; fresh reopen handles;
   duplicate-open rejection and explicit capacity exhaustion.
2. `tests/native_lifecycle.mojo` plus `native_lifecycle_probe.m`: real Moxi frame
   submission, native AX text mutation and button actions, deep-row retention,
   independent edits/selections in both windows, AppKit mouse drag callbacks,
   native menu targets and editor selection, sheet cancel/apply, closing
   an open sheet, and reopening with retained state. AX assertions check editor
   values, parent/row identity, selection, bounded publication, and no dropped
   events/commands.

The original executable ownership probe confirmed that opening B erased A's
queue and A's text callback subsequently wrote into B's queue. The new tests
exercise these paths against the production backend. No screen-reader session
is started by the checks.

The screenshot sequence and capture metadata are in
[the native lifecycle gallery recipe](../artifacts/demo-slideshows/native-lifecycle/README.md).
The parent added an eleven-state native content-view capture; scripted callbacks
and assertions establish those replay states, not physical input acceptance. Physical IME, VoiceOver,
other operating systems, Metal, external drag/drop, unbounded windows,
performance acceptance and a full repository test run are outside this gate.

### Local verification record — 2026-11-06

At base `0b30a60ca2c549c74b58dbed408824248b7731a6` plus the uncommitted F02
diff, on macOS 27.0.1 (26A434):

| Check | Result |
| --- | --- |
| Original ownership probe | Reproduced queue erasure and cross-window callback routing |
| `pixi run native-lifecycle-check` | Both ownership and Moxi integration lanes passed |
| `pixi run native-lifecycle-build` | Packaged `dist/MoxiLifecycle.app` successfully |
| Retained presentation, custom paint cache, rectangle equivalence, AppKit frame and wait probes | Passed |
| `native-accessibility-abi`, `native-authoring`, `native-demo-authoring`, `scripts/native_window_run_check.sh` | Passed |
| `git diff --check`; ignored binary/capture paths | Passed |
| CUA screenshot sequence | Not completed; capture errors/timeouts recorded in the recipe |

Full local logs are in `/tmp/moxi-f02`: `ownership-before.log`,
`lifecycle-check-final.log`, `workbench-build-final.log`, and
`regression-final.log` (commands in `regression.sh`). Native sources compile
with `-Wall -Wextra -Werror`. Mojo emits existing `as_c_string_slice`
deprecation warnings from imported code. The Linux-named runner exercised
local compatibility paths; no Linux desktop session was tested.

Parent replay with captures passed in `/tmp/moxi-f02-parent-check.log`. The native
sheet bitmap has incomplete material rendering and is excluded from the gallery;
Cancel/Apply behavior passes assertions and its resulting Moxi frames are shown.
