# Composed layout workbench

This is the optional authoring and acceptance screen for retained layout. It uses
Mojo flow/grid for the adaptive panes and toolbar, a Kiwi region for the form,
a variable extent collection for the results, and viewport-fitted popups. All
strategies stage against the parent's exact allocation before one geometry
publication supplies paint, input and accessibility.

Run `pixi run layout-candidate-check`, then `pixi run layout-workbench`.
The candidate uses the locked Mojo environment, CoreText/AppKit and pinned Kiwi
for constraint solving. The check bootstraps Kiwi at its recorded commit and
builds the native demo. Flow/grid layout and retained ownership execute in Mojo;
Cargo and the experimental Taffy bridge are not build dependencies.

The toolbar toggles a summary, RTL, an anchored column menu, a deliberate required
constraint conflict, empty/100,000 rows, text scaling and a modal dialog. Below
760 points the same form and results owners stack vertically. Drag the divider
in the wide arrangement, or tab to it and use the left/right arrows. Tab also
reaches the results viewport; up/down/home/end reveal a logical row. Clicking a
cell mounts an editor in its second column. Scrolling keeps that editor's key,
mount and state, including marked composition, even offscreen. Escape dismisses
a popup and restores the previous focus.

The conflict button deliberately demands a 10,000-point editor within the form.
The diagnostic is written to the terminal and the previous publication remains
visible. Toggle the button again to recover. Source removal retires removed keys
immediately, including when a subsequent solve fails; recovery uses previously
published leaf metadata rather than tentative content.

`retained_leaf` explicitly supports labels, buttons, single-line editors and
canvas leaves. Other modes produce a diagnostic. Labels draw the identical
retained CoreText paragraph that was measured. Controls retain their existing
native implementation. Native painting opts into submission order so a later
popup covers earlier cells and chart content. A single optional custom canvas
layer is inserted at the caller-specified canvas key. The legacy host retains
its existing painting order. Native slots are bounded at 1,024; presentation
capacity is validated before publication. A moving clip host crops the native
editor without replacing its identity or resizing its logical text frame.

The contract test covers unchanged measurements/solver reuse, geometry agreement,
wide/narrow switching, summary insertion, popup anchoring, modal focus restoration,
conflict rollback, source removal, RTL, scaling and an offscreen pinned editor.
The native bitmap probe covers submission order, custom canvas layering and editor
clip-host identity, stable AX objects and a real AppKit field editor's marked range
across offscreen clipping. Native wheel scrolling uses the portable event delta;
vertical direction was verified in the live demo. Tab and Shift-Tab traverse in
both directions; modal activation is rejected for targets outside the popup.
An open modal publishes only its dialog subtree for accessibility navigation;
dismissal restores the full tree and the prior focused control. Newly appearing
focused controls emit native focus-change notifications. Addressed accessibility
text edits use their editor's semantic key, even when keyboard focus is elsewhere;
background edits are rejected while a modal is active.
If a popup transition's layout is rejected, recovery keeps the accessibility
scope and focus from the frame still being painted. Authoritative source removal
falls back to Dataset when the previously focused row no longer exists.
These automated checks do not certify VoiceOver interaction or
Japanese input-method composition; those require explicit native verification.

The native acceptance pass also exercised wide/narrow resizing, RTL, summary
insertion, divider dragging, modal dismissal and a row editor scrolled offscreen
and back with its text intact. Pasting Japanese text is not an input-method test.
Live VoiceOver, Japanese composition and horizontal wheel verification remain
unresolved; the temporary system-setting attempts were canceled or restored.

Run `pixi run layout-consumer-check` for an independently authored screen linked
against a precompiled `moxi.mojoc` with no source-tree include path. This optional
profile links the Kiwi and macOS sidecars explicitly; it does not ship
those sidecars as part of `moxi.mojoc`. The optional
[native-services package](../packages/moxi_layout_native/README.md) supplies an
installed static archive on macOS arm64. Run `pixi run layout-package-consumer`
to build a temporary local channel and verify an independent consumer against
installed Mojo modules and that archive, without checkout-native object paths.

The candidate stays out of the root public exports until the promotion gates in
[the delivery ledger](layout-delivery.md) are satisfied. Its current supported
native host is macOS; the Mojo retained engine, collection, overlay and coordinate
policies have portable contract tests.

## Manual release checks

Run `pixi run layout-candidate-check`, then `pixi run layout-workbench` on macOS.
These checks require direct keyboard/trackpad use: the automation attempts have
not established VoiceOver feedback, actual input-source switching or horizontal
wheel delivery. Record the tested commit, macOS version, input device and observed
result in the delivery ledger; an attempted check is not a pass.

1. **VoiceOver:** note the original on/off setting, temporarily enable it and
   dismiss its tutorial. Traverse the toolbar, dataset editor and results using
   VoiceOver commands. Verify spoken names, roles and values identify the controls.
   Activate Dialog, verify navigation stays within its controls, then dismiss it
   with Escape and verify focus returns to the prior control. Repeat after wide/
   narrow resizing. Restore the original VoiceOver setting.
2. **Japanese composition:** note the original input sources, active source,
   input-menu visibility and dictation languages. Temporarily add/select
   Japanese–Romaji through the menu. Type `nihongo` in the dataset editor and
   verify real marked text or conversion candidates appear before committing.
   Resize across the 760-point breakpoint during composition. Repeat in a row
   editor, wheel-scroll it offscreen and back without changing focus, then convert
   and commit with Space/Return. Verify the same editor retains the composition
   and committed text. Restore all original settings, including any dictation
   language macOS added automatically.
3. **Horizontal wheel:** narrow the window until the four result columns exceed
   the viewport width. Use a physical horizontal trackpad gesture or horizontal
   wheel in both directions. Verify the non-frozen columns move, the first column
   stays pinned, and both ends clamp without blank overscroll. Repeat with RTL
   enabled and record the observed direction. Verify vertical scrolling still
   moves rows while the frozen first row stays pinned.

Leave a failed or unavailable check open. Portable offset tests and the native
marked-range probe provide supporting evidence but cannot replace these checks.
