# Accordion study (V11)

Build the single-file editor from the repository root and open the output in a browser. The build uses a local C++20 compiler, Python 3 and Moxi's existing portable spatial core. The editor runs directly from disk.

```sh
examples/foldable-motif/build.sh /tmp/accordion.html
open /tmp/accordion.html  # macOS
```

The fixture repeats a rigid two-panel pleat three times across a rectangular sheet. Every panel has pitch *p* and depth 40 mm. Number the seven parallel sheet edges from 0 through 6. In millimetres, their cross-section coordinates are `((i−3)p cos θ, (i mod 2)p sin θ)`. The panel length is therefore *p*, the span is *6p cos θ*, and the peak rise is *p sin θ*. Tilt θ measures inclination from the table. Adjacent panels have an interior opening of 180° − 2θ. The model assumes ideal hinges and zero thickness.

Moxi's `moxi::spatial::project` projects the unit-pitch sections and the two sheet-edge anchors through a fixed orthographic camera at build time. Orthographic displacements scale linearly with pitch. The browser composes the projected vertices for each edit from those samples. Every allowed whole-degree tilt has its own sample. The flat drawing uses the same pitch and panel IDs.

Pick a panel in either view, or use the active-panel control and arrow keys. Sweep the tilt for a preview, then press Escape or apply the edit. Exact pitch and tilt inputs share the same commit and undo history. Compare the starting and current span and rise in millimetres. Measuring crease 3 turns the anchored question into a height readout and overlays the endpoint's sweep on the folded surface. Attaching or undoing the measurement preserves pending inputs and previews. Its readout follows the displayed configuration.

Drag the right corner circle in either representation to change panel pitch (10–30 mm, in tenths). Drag the middle front crease circle up or down in the folded view to change tilt (0–75°, in whole degrees). Pitch in the folded view follows the projected sheet direction; tilt follows the crease endpoint through the same Moxi samples used for drawing. Pointer edits stop at the supported bounds. Flat paper exposes pitch; its unfolded geometry does not show tilt.

Tab to any circle for the same edit using arrows, Home/End for limits, and Enter to apply. Each circle reports its parameter and current value. Both views, the comparison and numeric fields preview together. Release leaves the preview pending; Apply edit or Enter commits one undo step. Escape or Cancel edit restores the committed patch, including during a captured drag. Invalid numeric drafts are rejected before direct editing; correct them or cancel. Valid numeric drafts participate in the next handle edit, as with the tilt slider. Undo is shared across both views and measurement attachment. Reload starts a fresh fixture; this study does not save documents.

## Repeat the check

With Node, Playwright and Google Chrome already present locally, run the following from the repository root. If Playwright lives outside the normal Node lookup path, set `NODE_PATH` to the installed package's parent directory. The browser context runs offline.

```sh
examples/foldable-motif/build.sh /tmp/accordion.html
node examples/foldable-motif/check.cjs /tmp/accordion.html /tmp/accordion-frames
node examples/foldable-motif/editing-check.cjs /tmp/accordion.html /tmp/accordion-editing
```

The check compares all 76 geometry samples with the analytic camera and unit-length constraints, exercises both picking directions, keyboard traversal, preview/cancel, edit/undo, range endpoints and invalid inputs, and checks the stacked layout at 390 CSS pixels. Regressions cover measurement attachment/undo during numeric drafts and slider previews, explicit cancellation without an implicit commit, and a pointer click at the center of the neighboring folded panel at 10 mm pitch and 75° tilt. The optional last argument writes six walkthrough screenshots plus four regression screenshots. Open the [offline slideshow](../../artifacts/demo-slideshows/v11-foldable-motif/index.html) for the recorded walkthrough.

`editing-check.cjs` adds direct pointer/numeric parity for all three circles, real Tab traversal, arrow steps and endpoints, in-flight cancellation and limits, rejected drafts, every panel's centroid in each view at pitch/tilt bounds, and measurement interleaved with flat/folded edits and undo. It repeats these at 1180 × 900 and 390 × 844 CSS pixels, then checks the original offline deck's images and navigation. Its required output directory receives screenshots and a scenario record with source/build hashes. See the separate [current editing evidence](../../artifacts/demo-slideshows/v11-foldable-motif/flat-folded-editing/README.md); the original deck and captures retain their historical baseline.

## Evidence limits

V11 covers the bounded geometric preview and comparison, including direct pitch editing in flat and folded views and direct crease tilt editing in the folded view. I01 is represented by promoting the crease question into a live measurement and undoing it at its original location. Arbitrary sketch-to-linkage formalization remains open. I21 is represented by the single tilt degree of freedom, editable length, endpoint trace, keyboard and pointer routes, preview cancellation and shared undo. Exact numeric values and the fixture layout round-trip. Free-form notation, saved document round trips and arbitrary joint dragging remain open.

A maker trial is needed to assess prediction and intentional revision. Folding a measured paper sample and comparing it with the preview is still required to assess the influence of thickness, crease placement and material behavior. No physical, fabrication, independent usability or screen-reader assessment was performed.
