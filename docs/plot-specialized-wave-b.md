# Specialized Wave B layouts (E02)

E02 adds opt-in `layout_version: 1` geometry for fourteen distinct families, including
`radialbar` from the authoritative capability inventory. Version 0 remains the
existing row-native catalog. The capability TSV continues to describe that baseline;
its contour module attribution is corrected to `absent-at-pin`. Specialized support
is described here, not inferred from catalog mark names.

The E01 restrictions still apply: one untransformed layer, implicit linear scales,
no facets, composition, explicit scales or transforms. Existing PlotSpec wire fields
are reused; no wire version or field is added. `specialize()` opts in. Unsupported
channels/options fail validation. No automatic downgrade to version 0 occurs.

## Algorithms and source contract

All numeric layout inputs must be finite, non-boolean numbers within ±1e15. Source
rows must be nonempty with nonnull categories. Categories/groups retain first-seen
order; grid cells use sorted coordinates independently of input row order. Wide
series retain declared field order. Duplicate series fields are rejected.

| Mark | Existing fields and specialized behavior | Source identity / limitations |
| --- | --- | --- |
| pie | x category, y nonnegative value; positive total; proportional clockwise sectors starting at twelve o’clock | One key per wedge; zero-value rows remain in table but have no geometric focus stop |
| donut | Same, inner radius 0.5 | Ring interior hit test excludes the hole |
| radar | 3–4095 indicator rows (extended-path capacity); y or `series_fields`; optional y2 per-indicator maxima, otherwise per-indicator maximum across series | Filled polygon retains all indicator keys; edges retain their two keys; point anchors select individual indicators. Nonnegative input; zero maxima map to center |
| gauge | One row; y measurement; paired `stat_low_field`/`stat_high_field`, default 0/100, minimum < maximum | 270° dial, 20/80% bands, 0.7 inner radius, 0.9 needle; measurement clamped; bands decorative, needle/pivot interactive |
| polar | x clockwise radians, y nonnegative radius with positive maximum | Connected source-order line plus anchors; segments retain both endpoint keys |
| polar_bar | x category, y nonnegative radius; equal angles, 20% angular padding | One source key per sector; radius/max normalization |
| radialbar | x category, y nonnegative value; outside-in rings with 25% slot gap | Value/max sweep; decorative full tracks excluded from hit tests |
| beeswarm | x group, repeated y samples, signed values accepted | Pixel-rounded y ordering, neighbor-chain collision groups, alternating offsets spaced by marker diameter. Stable tie ordering; geometry order may differ from source order |
| violin | x group, repeated y samples | Gaussian KDE at 30 min-to-max samples; bandwidth 0.9 × population std × n^-0.2, fallback 1 for constant groups; peak-normalized mirrored half-width 0.32 category units |
| ridgeline | Same distribution schema/KDE | First group at top, 1.3-unit peak height, overlapping baseline polygons |
| nightingale | x category, y nonnegative value | Equal angles; linear radius mode, matching upstream default. Does not silently substitute area mode |
| streamgraph | x category, required wide `series_fields`; ≥2 source rows, nonnegative values | Centered total baseline and linear quadrilaterals per adjacent source pair, matching upstream `line_smoothing=0`; no stream reordering/wiggle baseline |
| contour | x/y numeric grid coordinates, y2 scalar; complete unique rectangular ≥2×2 grid | Each cell split lower-left→upper-right; seven interior levels; linearly interpolated triangle-edge crossings; all three triangle keys retained |
| contourf | Same grid schema | Eight scalar bands clipped against each triangle; zero-area polygons omitted; constant triangles on an interior boundary belong only to the upper band |

A completely flat scalar grid emits no contour/band geometry; the table still
exposes every source row. Constant KDE groups produce finite zero-area silhouettes,
not invented sample dispersion. No smoothing, triangulation of scattered samples,
histogram substitute, missing-cell interpolation or fabricated density is used.
Contour interpolation is piecewise-linear over a fixed diagonal, **not bilinear
marching squares**. This is an explicit Moxi scientific choice pending independent
review; it is not upstream parity.

## Pinned reference and visual classification

The real read-only reference is dataviz_mojo v0.8.0,
`3fd5a7e7c622d6130c99a290b88c4fee039deab2`, with Canvas
`58fb12a471a65dfbc29ebc743860448439a6af22`. Moxi's own unchanged Canvas pin is
`8fcb0c83966ef872248239f9dafd6baaba06204e`. The runners record both dependency/lock
hashes, generated driver hash, supported `CANVAS_MOJO_FONT_PATH`, DejaVu Sans font
hash and artifact hashes in `tests/fixtures/wave_b/observed.json`.

Primary source inspected: `arc.mojo`, `polar.mojo`, `polar_bar.mojo`, `radar.mojo`,
`gauge.mojo`, `radialbar.mojo`, `nightingale.mojo`, `beeswarm.mojo`, `violin.mojo`,
`ridgeline.mojo`, `streamgraph.mojo`, and shared distribution helpers. Radial, KDE,
swarm and stream algorithms are adapted from that MIT source; retain
`tests/fixtures/wave_a/DATAVIZ-LICENSE`. DejaVu license and font attribution live
in `tests/fixtures/wave_b/DEJAVU-LICENSE`.

**Neither contour API exists in the pinned source.** A tracked-tree search for
`contour` under `dataviz` exits 1, and `dataviz/contour.mojo` is absent. The two
contour slideshows show that primary-source absence report instead of substituting
another renderer. Their real upstream-output gate remains missing.

Both runners use 640×480 canvases, equal source values, 48/32/28/36 margins,
3-pixel upstream point radius versus 6-pixel Moxi diameter, no upstream legend,
zero stream smoothing, and deterministic fixtures. Upstream's background/axis
colors and mark color are normalized where the public Theme API permits. Several
upstream categorical marks hard-code their palette; no upstream source is patched.
Moxi's Python renderer and Canvas renderer have different presentation styles.

Narrow checks in `compare.py` require colored plot-region silhouette overlap >98%
for pie/donut/polar_bar/radialbar/violin/ridgeline/nightingale/streamgraph, >96% for
gauge, exact radar/polar SVG vertex correspondence within 0.001 px, and source-row
beeswarm centers within 1 px (upstream rounds/truncates pixel centers). Full-image
pixel equality is not claimed. Radar's alpha fill differs from upstream's
white-lightened opaque fill. Moxi adds radar anchors, retains Cartesian axes/grid
for radial families, and uses sampled arcs. Upstream renders category/radial labels;
Canvas currently lacks text/legend labels. These are remaining differences, not
waived pixel checks disguised as parity.

Ridgeline's top peak exceeds the nominal y domain: upstream paints into the top
margin, while Moxi clamps it to the plot boundary. The silhouette comparison
crops both images to the shared plot rectangle and does not cover that overflow.

## Shared boundaries and interaction

`PlotPoint` adds polygon vertices and all contributing source keys; its copy owns
both lists. `PlotGlyphKind.POLYGON` flows through layout, exact point-in-polygon /
edge-distance hit testing and Scene rendering. Python Glyph mirrors those fields
with immutable tuples and adds hit-result `source_rows` for specialized geometry.

The existing typed `ScenePath` defaults to its unchanged 16-command inline limit.
The new named `ScenePathStorage.EXTENDED` policy permits up to 4096 commands with
owned overflow storage; unknown policy values and overflow remain invalid. This
is necessary for continuous sampled rings/KDE polygons: legacy string paths do
not fill in Canvas, while separately antialiased pieces produce seams. Wave B
uses one extended typed path per polygon. No generic renderer/parser rewrite or
root gallery change is needed. Existing inline ScenePath callers remain bounded.

Clicking multi-source geometry selects its documented representative (first
contributing source key), not a synthetic row. Keyboard and linked selections
can address all contributing keys. Tooltip/visual anchor remains attached to the
representative shape, so it does not claim a unique data point for a density,
triangle or interval. Hover/selection highlight may be at the shape's anchor;
source table and semantic values carry the authoritative keys. Rectangular brush
and lasso remain anchor-based and are not specialized area-intersection parity.
Rows that produce no geometry remain in the source table/Python row semantics,
but have no Mojo geometric focus stop. Native screen-reader behavior is unverified;
VoiceOver remains paused.

Wave B PlotView resize recompiles pixel-dependent geometry and remaps selection
by stable source keys. It preserves viewport domains and series visibility, and
clears pixel-relative hover and unfinished gestures. Its eager and queued
source replacements validate before committing, preserve the last valid output
on rejection, and clear selection on a successful source update. These additions
are restricted to Wave B specialized specs; E01 and version-0 update/resize paths
retain their behavior. The public API inventory includes the extended path policy,
`SpecializedPlotScenario` and `canonical_wave_b_scenarios`. The shared scenario
registry is the only family inventory; the checked JSON export contains its hash.

## Verification and reproduction

Use separate E02 environment/output directories; the upstream checkout stays
unchanged. Run from the implementation worktree:

```sh
python3 -m venv /tmp/moxi-e02-venv
/tmp/moxi-e02-venv/bin/pip install pytest pillow numpy matplotlib==3.10.7
export PYTHONPATH=python
/tmp/moxi-e02-venv/bin/python scripts/wave_b/fixtures.py
/tmp/moxi-e02-venv/bin/python scripts/wave_b/check_boundaries.py
/tmp/moxi-e02-venv/bin/python scripts/wave_b/verify.py /tmp/moxi-e02-actual
E02_FONTS=$(/tmp/moxi-e02-venv/bin/python -c 'import matplotlib; print(matplotlib.get_data_path()+"/fonts/ttf")')
/tmp/moxi-e02-venv/bin/python scripts/wave_b/upstream.py /tmp/moxi-e01-dataviz /tmp/moxi-e02-reference --font-dir "$E02_FONTS"
/tmp/moxi-e02-venv/bin/python scripts/wave_b/compare.py /tmp/moxi-e02-reference /tmp/moxi-e02-actual
/tmp/moxi-e02-venv/bin/python scripts/wave_b/evidence.py /tmp/moxi-e02-reference /tmp/moxi-e02-actual
python3 -m http.server 8767 --bind 127.0.0.1
```

In T3 collaborative preview, open each `artifacts/demo-slideshows/e02-*/source.html`,
`comparison.html`, and `selection.html` at 1280×900. Save actual browser snapshots
to `01-source.png`, `03-comparison.png`, `04-selection.png` in the same directory.
For contour/contourf also capture `reference-gap.html` to `02-reference.png`.
Then run `scripts/wave_b/slideshows.py`; it invokes the shared schema validator
and renderer without touching the root gallery. All fourteen sequences contain
source/schema → reference (or explicit missing gate) → actual Moxi → keyed table
selection → export/update → rejection → recovery. Browser pages are labeled
artifact/event replay, not fabricated live plot UI. Generated PNG/PDF/SVG/HTML
remain ignored locally; manifests, fixtures, observed results and scoped source
hashes are reviewable.

Focused regression commands (with the environment above):

```sh
/tmp/moxi-e02-venv/bin/pytest -q tests/python
/tmp/moxi-e02-venv/bin/python scripts/wave_a/verify.py /tmp/moxi-e02-wave-a
python3 scripts/plot_spec_contract_check.py
for test in scene_extended_path scene_typed_contract canvas_renderer canvas_scene_parity plot_spec plot_runtime plot_selection plot_view plotting plot_render plot_statistics
do
  pixi run mojo run -I src "tests/$test.mojo"
done
bash scripts/api_status_check.sh
python3 scripts/capability_wave_check.py
bash scripts/python_package_consumer.sh
bash scripts/package_consumer.sh
PYTHONPATH=python /tmp/moxi-e02-venv/bin/python scripts/wave_b/slideshows.py
```

The package consumer builds and installs through a temporary local file channel;
it does not publish to an external service. Its added assertions exercise the
installed shared registry, polygon geometry, source keys and extended Scene path.

`verify.py` compiles the actual serialized Python spec into Mojo, compares every
primitive bound, polygon vertex and contributing key, renders Canvas/SVG,
dispatches click/keyboard/linked selection, checks CSV source values, rejects
nonfinite eager/queued updates and checks pixel-identical recovery. Independent
boundary examples cover empty/nonfinite/negative inputs, zero/constant data,
missing/duplicate grid cells, analytic scalar planes, deterministic order and
source updates. Python tests also assert Gaussian KDE values, pie proportions,
donut hole, clockwise polar coordinates, stream centering and filled-grid area.

The native table retains its existing Float32 storage. Python computes layout
with double precision; fixture bounds/vertices are compared within 2e-5. Very
finely spaced coordinates that collapse after Float32 conversion may be rejected
as a duplicate/degenerate native grid; this work does not change the table ABI or
claim arbitrary-precision cross-runtime geometry.

Bounded measurements retain 30 samples, median, min/max and sample standard
deviation per family for Python layout and Mojo layout plus Scene construction.
They exclude compilation, rasterization/export, browser capture and native/GPU
or human latency. They are fixture evidence, not throughput or responsiveness
claims. Samples were collected on a shared host with concurrent compilation;
they are not isolated performance measurements. `observed.json` records the
exclusions and all missing gates. Full logs
are `/tmp/moxi-e02-*.log`; generated Mojo drivers/run logs remain in the separate
`/tmp/moxi-e02-actual`, `-boundaries`, `-reference` and `-wave-a` directories.
