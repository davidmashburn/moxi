# E02/E03 gallery review on d7fa3ed

The [November 23 follow-up](../plot-contour-followup/README.md) records genuine upstream references and measured comparisons for all three contour families. The [ridgeline follow-up](../plot-ridgeline-followup/README.md) shows the repaired peak. The counts and table below describe the original review.

All **26 galleries** were regenerated from the published runtime. All **170
slideshow frames** and **78 supporting PNGs** were visually inspected, using
52 labelled panels at original image resolution and additional individual
barbs update/original inspection. The hash audit also covers 40 SVGs and 26
PDFs. Full per-frame observations, hashes, scenario steps, expected/observed
results and portable evidence links are in [review.json](review.json).

The bounded geometry/source-key/event checks pass for all 26 families. Full
visual acceptance is **partial for all 26**, with the differences below.
Scenario totals: **114 pass, 36 partial, 6 blocked**. The six blocked scenarios
are the reference and upstream-comparison gates for contour, contourf and
tricontour. Their native rendering was reviewed; no substitute upstream plot
was introduced.

Each table row links the exact reviewed comparison frame. P = pass,
partial = remaining visible difference or verification limit, blocked = exact
pinned upstream lacks the required API. Selection passes cover the bounded
recorded-event/source-table contract, with representative markers. They do
not certify full-glyph highlighting, physical input or accessibility usability.

| Family | Source | Reference | Comparison | Selection | Update/export | Reject/recover | Visual and semantic assessment |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [E02 pie](../e02-pie/03-comparison.png) | P | P | partial | P | P | P | Proportions, clockwise ordering and row identity retained; native Cartesian grid, palette and missing labels/legend remain. |
| [E02 donut](../e02-donut/03-comparison.png) | P | P | partial | P | P | P | Annular proportions and hole exclusion retained; grid remains visible through the hole, with representative selection marker. |
| [E02 radar](../e02-radar/03-comparison.png) | P | P | partial | P | P | P | Five-spoke/two-series geometry and source identities retained; fills, grid and missing category labels differ. |
| [E02 gauge](../e02-gauge/03-comparison.png) | P | P | partial | P | P | P | Threshold zones and value/needle geometry retained; dark native needle has low contrast, with no value label. |
| [E02 polar](../e02-polar/03-comparison.png) | P | P | partial | P | P | P | Seven angle rows retain coincident 0/2π endpoints; update opens the path as expected. Native grid and missing labels remain. |
| [E02 polar-bar](../e02-polar-bar/03-comparison.png) | P | P | partial | P | P | P | Four gapped sectors and normalized radius behavior retained; native palette/grid and center marker differ. |
| [E02 radialbar](../e02-radialbar/03-comparison.png) | P | P | partial | P | P | P | Four progress tracks and their non-interactive decoration contract retained; native grid/labels and representative marker limit parity. |
| [E02 nightingale](../e02-nightingale/03-comparison.png) | P | P | partial | P | P | P | Four equal-angle sectors use the declared linear-radius rule, rather than an area interpretation; labels/legend absent. |
| [E02 beeswarm](../e02-beeswarm/03-comparison.png) | P | P | partial | P | P | P | All 24 source rows and collision offsets retained; update reflows the affected group, with unlabeled native axes. |
| [E02 violin](../e02-violin/03-comparison.png) | P | P | partial | P | P | P | Symmetric sampled KDE profiles and all 24 rows retained; density selection uses a representative row, with no category labels. |
| [E02 ridgeline](../e02-ridgeline/03-comparison.png) | P | P | partial | P | partial | P | All 24 rows and stacked KDE profiles retained; top density is clamped in native Canvas and cropped at the Python export edge. |
| [E02 streamgraph](../e02-streamgraph/03-comparison.png) | P | P | partial | P | P | P | Three centered source-ordered bands and interval identities retained; native grid/palette and faint vertical seams differ. |
| [E02 contour](../e02-contour/03-comparison.png) | P | blocked | blocked | P | P | P | Seven native isoline levels and 25-row contributing identities reviewed; no upstream contour API, labels or scalar-level legend. |
| [E02 contourf](../e02-contourf/03-comparison.png) | P | blocked | blocked | P | P | P | Eight native filled bands and 25-row triangle ownership reviewed; native triangle seams and no level legend; upstream API absent. |
| [E03 treemap](../e03-treemap/03-comparison.png) | P | P | partial | P | P | partial | Descendant-weight rectangles retained; branch own values are ignored as declared. Missing leaf labels/separators merge same-color siblings visually. |
| [E03 sunburst](../e03-sunburst/03-comparison.png) | P | P | partial | P | P | partial | Depth rings, hidden root and weight angles retained; elliptical scaling and radial tessellation seams reduce readability. |
| [E03 tree](../e03-tree/03-comparison.png) | P | P | partial | P | P | partial | Seven nodes/six edges and parent-child identities retained; reparenting updates layout. Labels absent and extreme markers clip at plot bounds. |
| [E03 sankey](../e03-sankey/03-comparison.png) | P | P | partial | P | P | partial | Five flows, long-edge pass-through and column normalization retained; labels absent, diagonal seams visible, aggregate nodes table-only. |
| [E03 chord](../e03-chord/03-comparison.png) | P | P | partial | P | P | partial | Incident totals, subarcs and quadratic ribbons retained; ellipse scaling and dense tessellation seams remain, aggregate rim nodes table-only. |
| [E03 graph](../e03-graph/03-comparison.png) | P | P | partial | P | P | partial | Four nodes/five weighted edges and deterministic ordering retained; stretched circular layout, no labels, aggregate node selection table-only. |
| [E03 calendar heatmap](../e03-calendar-heatmap/03-comparison.png) | P | P | partial | P | P | partial | Five ISO dates include leap day and year end with correct Sunday-first placement; labels, color scale and month reserve differ. |
| [E03 corrplot](../e03-corrplot/03-comparison.png) | P | P | partial | P | P | partial | Full 3×3 signed matrix and invisible zero inputs retained; elliptical disks, colors, radial seams and missing category/value labels differ. |
| [E03 punchcard](../e03-punchcard/03-comparison.png) | P | P | partial | P | P | partial | First-seen axes and size/10 radius contract retained, including invisible zero row; labels absent and per-row colors differ. |
| [E03 marimekko](../e03-marimekko/03-comparison.png) | P | P | partial | P | P | partial | Six rectangles retain total-based widths and normalized heights; missing labels/separators merge same-series rectangles visually. |
| [E03 barbs](../e03-barbs/03-comparison.png) | P | P | partial | P | P | partial | Six calm/tick/flag glyphs retained; update changes second glyph from 5 to rounded 15 units. Data-space staff lengths, palette and missing labels differ. |
| [E03 tricontour](../e03-tricontour/03-comparison.png) | P | blocked | blocked | P | P | partial | Twelve segments across three levels and three-vertex source identities retained; scalar legend absent and exact upstream API unavailable. |

Wave B directly confirms invalid updates preserve the updated raster and
restoration recovers the original raster. Wave C checks rejection return
values and byte-identical restoration, but its existing driver takes no
snapshot between rejection and restoration. Its atomic pixel-preservation
claim is therefore unverified here. Per-family keyboard/linked traversal is
exercised in Wave B, and was not exercised by the Wave C driver.

All recorded structural/semantic observations match committed evidence.
Exactly **89 offscreen slideshow hashes match**; **81 browser hashes changed**.
Prior ignored PNGs were absent in this checkout, so the old/new comparison
uses committed hashes and observations; no direct prior-image visual review
is claimed. [checks.json](checks.json) preserves every old/new slide hash.

The [reproduction commands](REPRODUCE.md) cover setup, both runtime suites,
pinned references, capture and fail-closed checking. Runtime, assertions and
fixture inputs remain identical to `d7fa3ed`; only evidence/capture tooling
changed. Capture environment, timing, DPR, loaded images and errors are in
[captures.json](captures.json). One optional favicon 404 is separately
recorded; no unexpected page errors or failed evidence images occurred.

Each of the 26 family links in the table opens its historical comparison PNG in a clean clone. Their dimensions and SHA-256 values were checked against the original per-family manifests on November 23. Other historical scenario frames, generated exports, review-panel images and raw logs in `output/e02-e03-d7fa3ed/` remain local reproduction artifacts. The JSON and Markdown records in this directory are retained in Git.

Confidence is high in bounded reproduction/hash/semantic results and medium
in visual-quality judgments. A failed fingerprint, changed hash, missing
frame or independent scientific/native-input evidence could change these
outcomes. Full project/package CI, installed consumers, native/GPU/physical
input, VoiceOver, mobile/extra themes, independent human/scientific acceptance
and performance were not verified. PNG exports were reviewed visually;
SVGs were parsed and PDFs hash/header-checked without independent vector/PDF
rendering review. The common handoff and master index were not modified.
