# Native acceptance follow-up

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

## Unverified native acceptance

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

## Next native probes

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
during this retry. Neither native acceptance item is a pass, and the automation
failure does not establish an application defect.

- With a confirmed active Japanese input method, compose and cancel text in
  the path and threshold controls, then commit and replace a selected range.
  Observe both candidate display and committed model value.
- Traverse all workbench controls with VoiceOver, checking labels, order,
  activation, selection announcements, and duplicate editable elements.
- Exercise composition around emoji and selected ranges in a dedicated canvas
  text-input harness. Workbench uses AppKit `NSTextField` overlays, so it does
  not validate the canvas marked-text callback path.

Source inspection found risks requiring native tests: `controlTextDidChange:`
for the overlay forwards the field's entire value, while canvas `setMarkedText`
ignores `replacementRange`, `markedRange` uses model selection, and empty
`unmarkText` emits no composition-end event. These are inspection findings,
not demonstrated workbench failures. Existing headless composition tests and
the accessibility ABI test do not establish native IME or screen-reader
acceptance. No new tests were added for this manual acceptance record.
