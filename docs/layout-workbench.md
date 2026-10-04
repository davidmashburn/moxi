# Composed layout workbench

This is the optional authoring and acceptance screen for retained layout. It uses
Mojo flow/grid for the adaptive panes and toolbar, a Kiwi region for the form,
a variable extent collection for the results, and viewport-fitted popups. All
strategies stage against the parent's exact allocation before one geometry
publication supplies paint, input and accessibility.

On macOS, run `pixi run layout-candidate-check`, then
`pixi run layout-workbench`. That candidate uses the locked Mojo environment,
CoreText/AppKit and pinned Kiwi for constraint solving. The check bootstraps Kiwi
at its recorded commit and builds the native demo. Flow/grid layout and retained
ownership execute in Mojo; Cargo and the experimental Taffy bridge are not build
dependencies.

The Linux retained presenter uses GTK 4.14+ for the native window/input service,
Cairo for paint and retained Pango paragraphs for text. It runs the same Mojo
workbench and pinned Kiwi model. On Ubuntu 24.04, install the host dependencies,
then build/check from the locked environment:

```sh
sudo apt-get update
sudo apt-get install --yes --no-install-recommends build-essential pkg-config libgtk-4-dev fonts-dejavu-core fonts-noto-cjk
pixi install --locked
pixi run --locked linux-layout-check
pixi run --locked linux-layout-workbench
```

`linux-layout-check` runs the Pango and Cairo/event C contracts, Mojo retained
engine/box/retained layout checks, the Kiwi bridge and 1,000 staged rebuilds,
and the composed workbench contracts before compiling `dist/layout-workbench-linux`.
It does not launch a window. `linux-layout-workbench` builds and launches the app;
run it from an X11 or Wayland desktop session. In the existing VM's Xfce session,
an SSH shell can select the graphical display with `DISPLAY=:1`. Wayland has not
been exercised. The Linux VM native contracts, app compilation and synthetic X11
interaction checks passed on stable Mojo 1.1.0 after the latest rebase; see the
evidence below.

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
retained paragraph that was measured: CoreText on macOS and Pango on Linux.
AppKit controls retain their existing native implementation; Linux paints the
retained controls on its GTK canvas and routes input/composition through GTK's
input-method context to the Mojo editor. Linux accessibility remains unavailable:
the semantic keys used for editor input do not constitute an AT-SPI tree. Legacy
widget parity, desktop clipboard integration, rich text, GPU acceleration and
incremental rendering are also outside this Linux slice. Copy/cut/paste currently
uses each Mojo editor's in-memory clipboard. Native painting opts into submission
order so a later popup covers earlier cells and chart content. A single optional custom canvas
layer is inserted at the caller-specified canvas key. The legacy host retains
its existing painting order. Native slots are bounded at 1,024; presentation
capacity is validated before publication. On macOS, a moving clip host crops the
native editor without replacing its identity or resizing its logical text frame.

The contract test covers unchanged measurements/solver reuse, geometry agreement,
wide/narrow switching, summary insertion, popup anchoring, modal focus restoration,
conflict rollback, source removal, RTL, scaling and an offscreen pinned editor.
The macOS native bitmap probe covers submission order, custom canvas layering and editor
clip-host identity, stable AX objects and a real AppKit field editor's marked range
across offscreen clipping. Native wheel scrolling uses the portable event delta;
vertical direction was verified in the live demo. Tab and Shift-Tab traverse in
both directions; modal activation is rejected for targets outside the popup.
On macOS, an open modal publishes only its dialog subtree for accessibility
navigation; dismissal restores the full tree and the prior focused control. Newly appearing
focused controls emit native focus-change notifications. Addressed accessibility
text edits use their editor's semantic key, even when keyboard focus is elsewhere;
background edits are rejected while a modal is active.
If a popup transition's layout is rejected, recovery keeps the accessibility
scope and focus from the frame still being painted. Authoritative source removal
falls back to Dataset when the previously focused row no longer exists.
These automated checks do not certify VoiceOver interaction or
Japanese input-method composition; those require explicit native verification.

The macOS native acceptance pass also exercised wide/narrow resizing, RTL, summary
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
native host is macOS, with a provisional Linux retained presenter now implemented.
The Mojo retained engine, collection, overlay and coordinate policies have portable
contract tests. Linux native paragraph measurement/drawing, Cairo submission
order/clipping, paragraph ownership and bounded Unicode event transport also have
guest contract evidence. Injected events or synthetic Unicode input do not certify
real input-method composition or physical horizontal scrolling.

## Linux GUI evidence

The actual compiled workbench passed 15 checks in the Ubuntu 24.04 x86-64 VM's
Xfce/X11 desktop: visible drawing, summary reflow, RTL pane order, Tab focus,
rapid Tab/Space routing, GTK-simple Unicode input, preedit focus cancellation,
narrow resize with retained preedit, modal scope/cancellation, rapid cell
click/type routing, row-switch cancellation, horizontal and vertical scrolling,
screenshot capture and clean window close. The resize check preserves the
already-fitting window height and verifies the narrower canvas and stacked panes;
it does not demand a client taller than the desktop work area.

The stable Mojo 1.1.0 build passed this complete GUI run after the rebase. Wide
and narrow screenshots show the actual compiled GTK workbench. Source archives,
toolchains, screenshots and logs are recorded in [VM validation](vm-validation.md).

After compiling, an X11 session with a window manager and `xdotool` can run
`pixi run --locked linux-ui-smoke`. Its per-run summary, native event/publication
trace and app log are saved under `dist/linux-native-artifacts`. The optional
`--screenshot PATH` argument requires `xfce4-screenshooter`. CI uses Xvfb/Openbox;
that lane is separate from the real VM desktop observation.

GTK-simple Unicode preedit/commit is synthetic input. A real Japanese input method,
physical keyboard/trackpad use and Wayland remain unverified. No AT-SPI
semantic tree is supplied, so Linux screen-reader acceptance remains unavailable.
The separate macOS manual checks below remain open.

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
