# Specialized Wave C geometry

E03 implements opt-in layout version 1 for the twelve Wave C rows in
`docs/dataviz-capabilities.tsv`. The existing mark names and row-native version
0 remain available. These implementations consume source hierarchies, edge
lists, matrices, vectors and an explicit triangle mesh; row-native glyphs are
not evidence of specialized behavior.

This is a local implementation with bounded checks, not an E6 gate closure.
The pinned upstream has **no tricontour module or API**, despite the prior inventory's
`tricontour.mojo` entry (now corrected to `unavailable-at-pin`). Its slideshow explicitly records the missing reference.
No substitute renderer is presented as upstream evidence. The other eleven
references are produced by real unmodified upstream code.

## Public contract and data

```python
from moxi import PlotSpec, plot

spec = PlotSpec("Hierarchy")
layer = spec.add_catalog_mark("treemap", x_field="id", y_field="value",
                              y2_field="parent")
spec.specialize(layer)
figure = plot({"id": ["root", "A", "B"], "parent": ["", "root", "root"],
               "value": [0, 6, 4]}, spec)
figure.save("hierarchy.svg")
print(figure.table())
```

The wire remains PlotSpec version 1. `Layer` and `PlotSpec.specialize` add
optional `triangles` (lists of three integer row indices) and `levels` (strictly
increasing finite numbers), both defaulting to empty lists. Missing fields in
old documents retain their defaults. Mojo `PlotLayer.triangles_json` and
`levels_json` preserve the wire arrays and strictly parse them at the layout
boundary. `LayoutVersion`/`PlotLayoutVersion`, `WaveCMark`, existing named Mojo
mark constants and `GlyphKind`/`PlotGlyphKind` represent domain choices.

`GlyphKind.TRIANGLE` and `PlotGlyphKind.TRIANGLE` add a primitive. Python `Glyph`
adds `vertices`, `source_rows`, `size`, `stroke_width`; Mojo `PlotPoint` adds
`x3`, `y3`, `source_keys`, `stroke_width`. These are provisional layout/render
seams; no root package exports are added. `source_keys` is a comma-separated
sequence of actual integer keys, never a fabricated aggregate node key.

| Mark | Source schema | Geometry |
| --- | --- | --- |
| treemap | x unique id, y nonnegative value, y2 parent id; root parent empty | Alternating slice/dice, leaf rectangles, branch colors |
| sunburst | same hierarchy | Descendant-weight angles and depth rings; root hidden |
| tree | same hierarchy | DFS leaf slots, mean child positions, depth; parent-child edges |
| sankey | x source id, y nonnegative weight, y2 target id | DAG longest-path columns, long-edge pass-through nodes, normalized strips |
| chord | same edge list | Incident-weight ring sectors and quadratic center-control ribbons |
| graph | same edge list | Deterministic circular layout; source-list then target-list first-seen nodes; weighted edges |
| calendar_heatmap | x unique YYYY-MM-DD, y value | Sunday-first Gregorian week/day cells in one year |
| corrplot | x row labels, y first numeric field, series_fields square wide matrix | Full matrix with radius proportional to absolute correlation in [-1,1] |
| punchcard | x/y categorical axes, one numeric series_field | First-seen categorical cells, size/10 pixel radius |
| marimekko | x category labels, y first numeric field, series_fields wide nonnegative matrix | Category width total/grand; cell height value/category total |
| barbs | x/y positions, series_fields [u,v] | Upwind staff; nearest-five speed, flags 50/full ticks 10/half ticks 5, calm circles |
| tricontour | x/y vertex positions, one z series_field, triangles, levels | Explicit mesh marching triangles; half-open crossing ownership |

Hierarchy internal values are ignored in descendant sums, as upstream does.
One root, consistent parent links and reachability are required; duplicates,
cycles, missing parents, negative/nonfinite values and zero leaf totals fail.
A root-only sunburst has no sectors. Graph self-loops are omitted; Sankey
self-loops and all directed cycles fail. Edge names define the node set, so
there is no independent node list that can silently omit a referenced node.
Chord/Sankey require positive totals. Matrix zero cells remain invisible or
zero-area; Marimekko requires a positive grand total. Empty input is rejected.
Tricontour rejects duplicate coordinates/triangles, invalid indices, zero-area,
nonmanifold and overlapping/crossing triangles. It accepts only supplied meshes;
it does not claim Delaunay triangulation. Barbs cap speed at 50,000 to bound
primitive expansion. Ordering follows source order, with no random layout seed.

Version 1 still requires one untransformed layer with implicit linear scales.
Explicit scales, transforms, composition, facets and per-row visual channels
remain unsupported. Wave A dispatch and all row-native version-0 behavior are
preserved. Python's numeric arithmetic is double precision; Mojo geometry uses
Float32. Comparisons use a 2e-5 data-coordinate tolerance on these fixtures.
Extreme magnitudes beyond representable native geometry are not a supported
cross-language precision guarantee.

## Interaction and recovery

Triangles render as closed Scene paths and use point-in-triangle hit testing.
Rectangle/segment/point interactions retain the existing shape-distance rules.
All glyphs retain primary source rows. Hierarchy edges retain parent/child keys;
contours retain all three vertex keys. Flow ribbons select their edge row.
Aggregate graph/Sankey/chord nodes expose incident edge identities and are
noninteractive: they have no unique source row. Cell parts identify the series
column in addition to the source row. Zero-size punchcard cells are not targets.

Selection/keyboard/linking remain row-based, not a new independent node or matrix
cell selection model. Overlaps resolve through existing nearest/topmost hit
ordering. Brush/lasso use primitive anchors, not polygon intersection. Selecting
a contour segment selects its primary vertex row; additional vertex identities
are metadata, not an automatic multi-row selection. The source CSV and semantic
subtree include invisible hierarchy/mesh rows. Native screen-reader usability is
unverified and VoiceOver remains paused.

`PlotView.replace_data` and `request_data` validate Wave C source data before
accepting it. Invalid replacements return false without changing the current
plot. Callers must advance table versions for new snapshots, as required by the
existing view API; independent tables with equal version counters are not treated
as updates. Direct primitive mutation remains rejected. Validate data/spec before
constructing a plot or replacing its specification. Recovery evidence rejects a
nonfinite replacement, then restores the original source and checks exact Canvas
pixel equality. It does not imply an error UI was implemented.

## Reference and visual differences

Reference is `randyzwitch/dataviz_mojo` v0.8.0 at
`3fd5a7e7c622d6130c99a290b88c4fee039deab2`, MIT, copyright Randy Zwitch 2026.
Algorithm adaptations are attributed in the layout modules; the full notice is
`tests/fixtures/wave_c/DATAVIZ-LICENSE`. Tricontour is independently implemented.
The reference's Canvas pin is `58fb12a471a65dfbc29ebc743860448439a6af22`;
Moxi's is `8fcb0c83966ef872248239f9dafd6baaba06204e`. The runner checks the clean
reference checkout. It uses DejaVu Sans via supported `CANVAS_MOJO_FONT_PATH`;
The DejaVu/Bitstream font notice is `tests/fixtures/wave_c/DEJAVU-LICENSE`;
font SHA256 is `3fdf69cabf06049ea70a00b5919340e2ce1e6d02b0cc3c4b44fb6801bd1e0d22`.
Dependency lock hashes, git revision, scoped dirty source hashes and actual
artifact hashes are recorded in `tests/fixtures/wave_c/observed.json` and manifests.

Both renderers receive the same 640×480 canvas and source values. Upstream margins
are normalized to native Scene's 48/32/28/36, legend disabled and font pinned.
Sankey node width is normalized to 22.4 pixels and corrplot bubble_fraction to
0.8 (radius 0.4 of the smaller cell dimension). Fixed upstream palettes have no
public override in these encoders; Moxi retains its palette. Moxi Canvas lacks
text/legend rendering; labels survive in source tables/semantics. Python exports
use their existing margins. Circular data-space geometry is stretched by Moxi's
independent x/y scales; upstream uses the smaller plot dimension. Barbs use
data-space lengths instead of upstream's fixed pixel staff length. Sectors and
ribbons are tessellated rather than analytic arcs. Calendar upstream reserves
label space and rounds cells. These are explicit visual/metric differences.
No pixel parity, native-window, human usability or physical performance gate is
claimed. Small deterministic workloads report seven samples of ten layout/Scene
builds with dispersion, excluding Canvas/export/browser/native-input latency.

## Reproduction and evidence

Use a separate environment/output directory; do not modify the upstream checkout.
On the recorded host the already verified checkout is `/tmp/moxi-e01-dataviz`.

```sh
python3 -m venv /tmp/moxi-e03-r2-venv
/tmp/moxi-e03-r2-venv/bin/pip install pytest Pillow numpy
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python -m pytest -q tests/test_specialized_c.py tests/python
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/wave_c/upstream.py /tmp/moxi-e01-dataviz /tmp/moxi-e03-r2-reference --font-dir /private/tmp/moxi-e01-venv/lib/python3.14/site-packages/matplotlib/mpl-data/fonts/ttf
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/wave_c/verify.py /tmp/moxi-e03-r2-moxi
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/wave_c/evidence.py /tmp/moxi-e03-r2-reference /tmp/moxi-e03-r2-moxi
python3 -m http.server 8794 --bind 127.0.0.1 --directory artifacts/demo-slideshows
```

Through T3 preview at 1280×800 capture each `e03-<mark>/source.html`,
`comparison.html`, `selection.html` as `01-source.png`, `03-comparison.png`,
`04-selection.png`. Also capture tricontour's explicit missing-reference page as
`02-reference.png`. Reference/update/recovery frames are actual offscreen output,
not browser/native interactions. Selection pages show recorded real Mojo click
results and actual exported CSV; they are explicitly labeled event replay.
Then run `PYTHONPATH=python python3 scripts/wave_c/slideshows.py` and `--check`.
The resumed capture log is `/tmp/moxi-e03-r2-browser-captures.json`; pass it with
`--capture-log` when finalizing to retain viewport, page height and browser DPR.
T3 saved 1280×800 CSS-pixel PNGs at screenshot scale 1 while the browser DPR was 2.
This reuses `scripts/demo_slideshows.py` schema/renderer and does not rebuild the
root gallery. Each family has its own six-step slideshow. Generated image,
SVG/PDF/HTML files remain ignored; small manifests, source fixtures and observed
results are reviewable. `src/moxi/scenarios.mojo` owns membership/order; fixture
and runner code validate against that registry rather than keeping a second list.

## Resumed local verification and integration boundary

Recovered from the read-only paused worktree `t3-6ea44db8` (base `8c70147`)
onto `t3-1bf5b67f` at `bd3cccd`, preserving the integrated spatial D04 and
mindmap D07 commits. All E03 edits are uncommitted. No parent planning ledger,
root gallery infrastructure, external service or VoiceOver state was changed.

The recovery fixed the missing `PLOT_PUNCHCARD` import and corrected the
boundary harness to emit the compact JSON used by the existing Mojo parser.
The malformed-data tests now reach their intended validators; spaced JSON
parser support is not added by E03. Independent Python and Mojo inputs cover
91 invalid and ten valid degenerate cases, besides the twelve main fixtures.

Focused checks: 204 Python tests pass both from source and an installed wheel
in `/tmp/moxi-e03-r2-venv` outside the checkout; twelve Wave C contract, geometry,
identity, click, semantic-table, Scene/Canvas, update and recovery cases; nine
Wave A cases; PlotSpec/plotting/view/runtime/render/selection/scenario Mojo
regressions; API status and scenario consumer checks; six overlap, six recipe,
and the existing row-native catalog exports. The isolated precompiled Mojo
consumer passes all twelve Wave C fixtures. Reference structure checks are
recorded per family in `tests/fixtures/wave_c/observed.json`. Logs use
`/tmp/moxi-e03-r2-*.log`; original first-attempt logs remain unchanged.

Additional commands:

```sh
MOXI_E03_CONSUMER_DIR=/tmp/moxi-e03-r2-consumer MOXI_E03_PYTHON=/tmp/moxi-e03-r2-venv/bin/python bash scripts/wave_c/consumer.sh
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/wave_a/verify.py /tmp/moxi-e03-r2-wave-a
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/plot_spec_contract_check.py
bash scripts/api_status_check.sh
bash scripts/scenario_check.sh
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/wave_c/slideshows.py
PYTHONPATH=python /tmp/moxi-e03-r2-venv/bin/python scripts/wave_c/slideshows.py --check
```

E02 integration is not tested here. Its parent must reconcile shared additions
in `specialized.py`, `figure.py`, `spec.py`, `plot_layout.mojo`, PlotSpec wire
fields/parser, `PlotGlyphKind`/`PlotPoint`, `plotting.mojo`, `PlotView` and the
shared scenario registry/count checks. Keep both dispatch branches; Wave C
algorithms live in `specialized_c.py` and `plot_layout_c.mojo`. Root exports are
unchanged; the added fields/primitive remain on existing provisional APIs.

Not run: full repository/host suites, native windows, other operating systems,
VoiceOver, independent human usability, large-data or physical-input performance.
The timings describe these small source objects only and exclude rendering as
stated in each record. Tricontour upstream parity remains unavailable. Parent
review and integration, including E02 conflict resolution, remain outstanding.
