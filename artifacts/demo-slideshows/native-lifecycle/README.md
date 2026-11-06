# Native lifecycle slideshow

Run from the repository root in a macOS graphical session:

```sh
python3 scripts/native_lifecycle_gallery.py
python3 scripts/demo_slideshows.py --check
python3 scripts/demo_slideshows.py
```

Open `index.html` in this directory. The eleven slides show the real Moxi
workbench in two live AppKit windows, driven by the integration test's native
AX actions, text callbacks and mouse callbacks. Assertions check both models,
native editor selection, resource ownership and fresh handles. Captures use
`NSView.cacheDisplay` on each running window's content view at its backing
scale. They exclude title bars and are not compositor screenshots or physical
input acceptance. PNG and generated HTML files remain local build artifacts.
The manifest records the base revision and a source fingerprint including the
window ownership header and the reproduction harness.

The raw diagnostic `07-native-sheet.png` is deliberately excluded: AppKit's
material/button rendering is incomplete in `cacheDisplay`, so it cannot verify
the sheet's appearance. Cancel/Apply outcomes are captured and asserted;
physical menu and sheet appearance remains a manual gate. Earlier CUA attempts
failed with `cgWindowNotFound` and timeouts. VoiceOver remains paused.

For interactive acceptance, run `pixi run native-lifecycle`. Edit different deep
rows in A and B, leave and return to them, drag one row, use Actions to select
editor text, cancel and apply Reset label, then close A and use B's Reopen other
window button. Confirm edits, selection and row order survive. Physical IME,
window chrome, menu/sheet appearance and compositor behavior are unverified.
