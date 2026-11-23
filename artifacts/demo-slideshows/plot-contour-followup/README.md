# Contour reference follow-up

This supplemental gallery resolves reference availability for `contour`, `contourf`, and `tricontour` at dataviz 0.15.0 commit `377b519e07f017d4a120b7fc3551f972a0b3fe16`. It contains genuine output from all three APIs and six reference/comparison scenarios. The historical 26-family report remains an accurate record of the older pin, which has no contour APIs. Its six blocked scenarios have not been retrospectively reclassified.

Open `contour-comparison.html`, `contourf-comparison.html`, and `tricontour-comparison.html` for the actual paired images. The corresponding `*-reference.html` pages show upstream output alone. The chart margins are 48/32/28/52 pixels on a 640×480 canvas. Moxi uses the explicit fixture extent; upstream adds 5% axis padding. Colors, labeling, gridlines, tessellation, and rasterization also differ. Full visual parity remains **partial for all three families**.

| Scenario | Expected and checked result | Outcome |
| --- | --- | --- |
| contour reference | Clean pinned API produces nonempty PNG/SVG output | Pass |
| contour comparison | Seven scalar levels have matching grid-edge crossings within 0.00002 data units | Bounded check passes; full geometry partial |
| contourf reference | Clean pinned API produces filled PNG/SVG regions | Pass |
| contourf comparison | Same seven thresholds; eight Moxi bands cover the complete 16-unit source grid | Moxi area check passes; upstream band area/topology unverified |
| tricontour reference | Clean pinned API produces PNG/SVG and Delaunay triangle connectivity | Pass |
| tricontour comparison | Fixture's supplied mesh matches upstream Delaunay; all three levels have matching unique endpoints within 0.00002 data units | Bounded check passes; arbitrary meshes unverified |

Regular contours use fixed-diagonal marching triangles in Moxi and marching squares upstream. Agreement on grid-edge crossings does not establish agreement on connections inside each cell. Filled contours use per-triangle clipping in Moxi and above-level union paths upstream; equal filled regions have not been demonstrated. Native filled-band seams remain visible. Tricontour accepts explicit meshes in Moxi, whereas this upstream API computes Delaunay connectivity. The fixture's agreement does not generalize to every supplied mesh.

Each family also has an interaction page and a recovery page. The Mojo harness applies a valid data update, rejects a nonfinite update, and restores the original data. Automated pixel comparisons require the valid update to change the chart, rejection to retain the valid update exactly, and restoration to reproduce the initial pixels exactly. These are recorded PlotView operations displayed by the browser; they are not browser interactions with a live plot.

The 12 `*-frame.png` files are local headless Chrome captures at 1400×900 and scale 1. `captures.json` records capture times, browser version, decoded image sizes, viewport dimensions, page errors, and failed requests. Capture requires every image to decode, no document overflow, no page errors, and no failed requests. `results.json` holds the numerical checks. `artifact-sha256.json` fingerprints the PNG/SVG artifacts. `provenance.json` records both compilers, commands, upstream and Canvas pins, lock hashes, font hash, and Moxi revision. `source-state.json` records the precise runtime and driver inputs, including uncommitted source; the capture aborts if they change during generation.

Reproduce from the repository root with a clean upstream checkout at the stated pin, its locked Pixi environment installed, and a Python environment containing Pillow, numpy, matplotlib, and Playwright. The recorded run used Pillow 13.0.0, numpy 2.5.5, matplotlib 3.10.7, and Playwright 1.65.2, with installed Google Chrome and DejaVu Sans from matplotlib.

```sh
PYTHONPATH=python python scripts/contour_parity.py /path/to/pinned/dataviz_mojo output/contour-parity --font-dir /path/to/dejavu/ttf
```

This writes the raw driver output/logs to the supplied output directory and refreshes this gallery. Use `--gallery` to choose a different gallery directory inside this repository. Both output and gallery directories should be separate from the upstream checkout. The generator checks the upstream revision, clean working tree, and Canvas dependency revision before compiling.

No native-window input, physical input, GPU rendering, VoiceOver usability, independent scientific review, large-workload performance, complete filled-region equivalence, or full image equality was verified. Confidence is high in the listed fixture checks; a failing rerun at the recorded pins or a counterexample to the stated comparisons would change those conclusions.
