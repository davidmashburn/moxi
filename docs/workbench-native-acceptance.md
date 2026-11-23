# Native acceptance follow-up

## Packaged workflow and plot layout, November 23, 2026

The signed app built from clean `045f9a5` ran on macOS 27.2.1 arm64. The
following actions used the window's accessibility controls and a writable copy
of [the 12-row sample](../examples/data/workbench-tail.csv). Capture time was
06:51 UTC. The workbench release gate also passed its data, paint cache,
accessibility ABI, package build, signature and benchmark checks. The benchmark
records measurements without a presentation-latency threshold.

| Action | Expected and observed result |
| --- | --- |
| Import the sample and filter on `value > 10` | The table retained keys 6, 7 and 10 out of 12 rows. |
| Select all three rows and export CSV and scatter SVG | The app wrote both files. Reading the CSV returned values 18, 21 and 28 and weights 3, 2 and 4 in key order. The 572 × 252 SVG parsed with 14 text elements and a plot clip. |
| Reopen the exported CSV | Three rows loaded with the original keys and values. |
| Import from an empty path and a missing file | The last valid table and selection survived both failures. |
| Quit the app | The original packaged process exited on Command-Q. |

This run exposed an overlap between horizontal tick labels and the series legend.
The renderer now reserves a separate legend row and draws the numeric labels
outside the data clip. The [AppKit capture](benchmarks/workbench-acceptance-2026-11-23/plot-layout.png)
shows both rows on the scatter and histogram at 1180 × 820 points. It was taken
at 07:12 UTC with the production workbench render function and default 48-row
dataset from clean `37f4f0d`, using the native test snapshot hook at 2× scale.

The rebuilt signed app passed bundle validation. The desktop automation bridge
reported `cgWindowNotFound` on relaunch, including from an isolated copy.
The post-fix image verifies the native content view. A second interactive pass
on the revised bundle, physical IME cases, sustained presentation timing and an
independent developer's authoring exercise remain open. VoiceOver remains paused.

## Acceptance status reviewed 2026-11-06

H2 remains partially verified. The [hardening replay](data-workbench-hardening.md)
and dated observations below establish native AX actions, a focused path-field
zoom/restore sequence, basic Japanese conversion and commit, and audible
VoiceOver controls. They do not establish the complete
keyboard/VoiceOver workflow: labels and navigation order, filter changes, row
selection announcements and plot purpose, import/export activation, duplicate
editable elements, and focus recovery after scrolling and resizing still need
a recorded end-to-end verdict. The remaining IME cases include cancellation,
selected-range replacement, mixed-script paths, and numeric-filter rejection
while preserving a usable active edit.

This is a source and historical-evidence audit at `fa42b6f`, not a new native
session. No GUI or settings were changed, and no physical input was simulated.
VoiceOver testing remains paused at the user's request. Headless regressions
cannot replace these native acceptance observations or establish that the older
manual results still hold on the current build. H6's independent human authoring
exercise is a separate open gate; see the
[supplementary agent exercise](workbench-authoring-exercise.md).

## Interactive follow-up, 2026-09-23

The user activated Japanese–Romaji/Hiragana and used the physical keyboard in
the CSV path field. Typing `nihon` and converting produced underlined `日本`,
visible in the captured application view; the user also observed the candidate
menu and Japanese description. The user confirmed the original sequence worked
after pressing Return twice. Basic native Japanese conversion and commit are
confirmed for this field, with high confidence from the visible composition and
the user's direct observation. An initial Escape result was clarified as an
uncommitted composition, not an established application defect.

Automation-generated key events continued to insert Latin text and did not
reliably exercise the active input method. The accessibility snapshot did not
independently establish the final committed model value. Threshold composition,
selected-range replacement, cancellation after a separately verified commit,
and canvas/emoji cases were not independently completed. This result is scoped
to the basic CSV-field flow, not full IME acceptance.

The user also confirmed hearing VoiceOver speak workbench controls. Further
VoiceOver traversal and selection-announcement testing was paused at the user's
request. VoiceOver was restored off. The temporary Japanese source was removed,
and U.S.-only input, a hidden input menu, the globe-key emoji action, and
English-only dictation were verified restored. No application code changed and
no automated suite was rerun for this manual test record.

The bundle inspected during this follow-up had executable SHA-256
`665f06d9197a19c43606feadba82745e26d5a3c63787314a5bda7faf4edd0ee6`;
its build manifest records revision `15ffce2` with a dirty worktree and linker
output SHA-256
`e51cc206124eaefc77510cb4c2b786319152d13e98df1e9ef2ce944ff18b87eb`.

## Earlier checks

Tested on macOS arm64 on 2026-09-18 using the signed isolated bundle at
`dist/workbench-launch/replay-drzjd9oj/Moxi Data Workbench.app`, PID 7690.
Its executable SHA-256 is
`9f9f419dab5ea5bc7085cf01e64f5b4e88d81004e23f98c5c41782cbde37c477`.
The hardening checkpoint is `99b1ba7`.

## Confirmed

With the default 48-row fixture, keyboard Tab navigation focused the CSV path.
Typing `/tmp/focus-`, using the native window's zoom action, typing `large`,
restoring the window, and typing `-restored` produced
`/tmp/focus-large-restored` without refocusing. Focus and caret survived this
enlarge/restore sequence. Confidence is high for this sequence; arbitrary
interactive resize gestures and other focused controls were not checked.

## September 18 verification limits

VoiceOver was enabled through System Settings and its welcome dialog.
The process was running, and its existing caption-panel preference was on.
The automation interface could not inspect the VoiceOver process (timeout),
and Control-Option navigation did not expose observable cursor or spoken-output
evidence in the application snapshot. This is not a VoiceOver pass or a proven
application defect. VoiceOver was restored to its original off setting.

A temporary Japanese Romaji input source was added. Individual `n i h o n`
keypresses after attempting input-source switching produced literal `nihon`,
so marked-text conversion, commit, and cancellation were not exercised.
The source was removed afterward. The original U.S.-only source list, hidden
input menu, globe-key emoji action, and English-only dictation language list
were verified restored. Automatic keyboard brightness was restored on after
an unintended UI toggle during settings navigation.

## September 18 retry and remaining probes

A subsequent retry on 2026-09-18 used the default signed bundle with the plot
cache changes (executable SHA-256
`13226b444885304faa150fdd3277bd39d02f306306b01d6251b4f0a058b0814e`).
The workbench opened and exposed its controls, but the Japanese Romaji probe
again produced literal `nihon ` without an observable candidate window.
Activation of the input method was not established. The temporary Japanese
source was removed; both the settings source list and a read-only preference
check confirmed U.S. as the remaining keyboard layout.

Automation then returned `cgWindowNotFound` for System Settings, VoiceOver
Utility, and the workbench, including after resetting the automation session.
This blocked further VoiceOver testing. Desktop access later recovered, and
the hidden input menu, globe-key emoji action, and U.S.-only source list were
confirmed. Japanese was removed from dictation and the English-only language
list was verified. Settings cleanup is complete. VoiceOver was not enabled
during this retry. Neither native acceptance item passed in that retry, and the
automation failure does not establish an application defect.

- With a confirmed active Japanese input method, compose and cancel text in
  the path and threshold controls, then commit and replace a selected range.
  Observe both candidate display and committed model value.
- Traverse all workbench controls with VoiceOver, checking labels, order,
  activation, selection announcements, and duplicate editable elements.
- Exercise composition around emoji and selected ranges in a dedicated canvas
  text-input harness. Workbench uses AppKit `NSTextField` overlays, so it does
  not validate the canvas marked-text callback path.

Source inspection at `fa42b6f` confirms risks requiring native tests:
`controlTextDidChange:` for the overlay forwards the field's entire value,
while canvas `setMarkedText` ignores `replacementRange` and `markedRange` uses
model selection. The earlier claim about empty `unmarkText` was too broad:
it emits a composition-end event whenever marked-text storage is non-nil,
including an empty marked string, and returns without an event only when that
storage is nil. These are source observations, not demonstrated workbench
failures. Existing headless composition tests and
the accessibility ABI test do not establish native IME or screen-reader
acceptance. No new tests were added for this manual acceptance record.
