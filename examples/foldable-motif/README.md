# Accordion study (V11)

Build the single-file editor from the repository root and open the output in a browser. The build uses a local C++20 compiler, Python 3 and Moxi's existing portable spatial core. The editor runs directly from disk.

```sh
examples/foldable-motif/build.sh /tmp/accordion.html
open /tmp/accordion.html  # macOS
```

The fixture repeats a rigid two-panel pleat three times across a rectangular sheet. Every panel has pitch *p* and depth 40 mm. Number the seven parallel sheet edges from 0 through 6. In millimetres, their cross-section coordinates are `((i−3)p cos θ, (i mod 2)p sin θ)`. The panel length is therefore *p*, the span is *6p cos θ*, and the peak rise is *p sin θ*. Tilt θ measures inclination from the table. Adjacent panels have an interior opening of 180° − 2θ. The model assumes ideal hinges and zero thickness.

Moxi's `moxi::spatial::project` projects the unit-pitch sections and the two sheet-edge anchors through a fixed orthographic camera at build time. Orthographic displacements scale linearly with pitch. The browser composes the projected vertices for each edit from those samples. Every allowed whole-degree tilt has its own sample. The flat drawing uses the same pitch and panel IDs.

Pick a panel in either view, or use the active-panel control and arrow keys. Sweep the tilt for a preview, then press Escape or apply the edit. Exact pitch and tilt inputs share the same commit and undo history. Compare the starting and current span and rise in millimetres. Measuring crease 3 turns the anchored question into a height readout and overlays the endpoint's sweep on the folded surface.

## Repeat the check

With Node, Playwright and Google Chrome already present locally, run the following from the repository root. If Playwright lives outside the normal Node lookup path, set `NODE_PATH` to the installed package's parent directory. The browser context runs offline.

```sh
examples/foldable-motif/build.sh /tmp/accordion.html
node examples/foldable-motif/check.cjs /tmp/accordion.html /tmp/accordion-frames
```

The check compares all 76 geometry samples with the analytic camera and unit-length constraints, exercises both picking directions, keyboard traversal, preview/cancel, edit/undo, range endpoints and invalid inputs, and checks the stacked layout at 390 CSS pixels. The optional last argument writes six desktop screenshots. Open the [offline slideshow](../../artifacts/demo-slideshows/v11-foldable-motif/index.html) for the recorded scenario.

## Evidence limits

V11 covers the bounded geometric preview and comparison. I01 is represented by promoting the crease question into a live measurement and undoing it at its original location. Arbitrary sketch-to-linkage formalization remains open. I21 is represented by the single tilt degree of freedom, editable length, endpoint trace, keyboard and pointer routes, preview cancellation and shared undo. Exact numeric values and the fixture layout round-trip. Free-form notation, saved document round trips and direct joint dragging remain open.

A maker trial is needed to assess prediction and intentional revision. Folding a measured paper sample and comparing it with the preview is still required to assess the influence of thickness, crease placement and material behavior. No physical, fabrication, independent usability or screen-reader assessment was performed.
