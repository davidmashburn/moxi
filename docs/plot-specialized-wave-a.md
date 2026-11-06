# Specialized Wave A layouts

E01 adds opt-in layout version 1 for lollipop, waterfall, candlestick, bullet,
grouped bar, stacked bar, Gantt, span chart and population pyramid. Existing
PlotSpec version 1 and row-native layout version 0 remain compatible. The new
work is geometry and source-row identity, not additional mark names.

```python
from moxi import PlotSpec, plot

spec = PlotSpec("Grouped sales")
layer = spec.add_catalog_mark("grouped_bar", x_field="category", y_field="north")
spec.specialize(layer, series_fields=["north", "south"])
figure = plot({"category": ["A", "B"], "north": [6, -2], "south": [4, 7]}, spec)
figure.save("sales.svg")
print(figure.table())
```

The serialized layer adds `layout_version`, ordered `series_fields`,
`range_fields`, `error_fields`, `total_field`, `horizontal`, and `percent`.
Python converts the version to `LayoutVersion`; Mojo uses `PlotLayoutVersion`.
The Mojo value can be configured directly on `PlotSpec.layers` or read through
`plot_spec_from_json`. Serialized lists are held as JSON strings in the
implicitly-copyable Mojo layer, and decoded at the layout boundary.

| Family | Source fields | Specialized behavior |
| --- | --- | --- |
| Lollipop | x category, y value | Zero-to-value stem and head; optional horizontal orientation |
| Waterfall | x category, y delta, optional total_field | Running sum; total/checkpoint includes its own delta and starts at zero; connectors; narrower deltas when totals supplied |
| Candlestick | x category, y close, y2 open, stat_low_field, stat_high_field | Wick, sign-colored body and one-pixel doji |
| Bullet | x category, y measure, y2 target, range_fields | Ordered disjoint bands, narrow measure and full-width target |
| Grouped bar | x category, y numeric source, series_fields, optional matching error_fields | Ordered sub-bands; errors and caps; optional horizontal orientation |
| Stacked bar | x category, y numeric source, series_fields | Independent positive/negative accumulators; optional horizontal and nonnegative percent modes |
| Gantt | x category, y start, y2 end | Horizontal sorted intervals; first category at top |
| Span | x category, y start, y2 end | Vertical sorted intervals; first category at left |
| Population pyramid | x category, y left, y2 right | Mirrored magnitudes and symmetric domain; first category at top |

The grouped/stacked `y` channel remains required by the existing PlotSpec
boundary; it may name the first series column. Wide columns preserve upstream
matrix order. Glyphs retain source row keys; decorative connectors are not hit
targets. Shared seams are typed primitive kind, primitive extent, layout domain,
source row identity, and ordered named-column matrices. No other wave is
implemented here.

Validation rejects unknown versions/marks, missing or repeated field names,
empty/null categories, missing/null/nonfinite/non-numeric values, negative
errors, descending thresholds, malformed OHLC bounds, non-boolean total flags
(other than numeric 0/1), negative percent values and irrelevant layout options.
Percent zero columns remain zero. Duplicate field names in an option list are
rejected. Reversed intervals are sorted; pyramid inputs use magnitudes.

Layout v1 currently accepts one untransformed layer with implicit linear scales.
Facets, compositions, explicit scales, transforms and per-row visual channels
are rejected instead of silently ignored. Use layer color/size/opacity and the
layout's series palette. Layout version 0 retains existing combinations.
Source updates must go through `PlotView.replace_data`; direct primitive
`set_point` is rejected because one source row can determine multiple glyphs
and running totals. Invalid source data is rejected by Python construction and
Mojo validation; callers must check Mojo `validate_data` before compilation.

Scene rendering uses rectangles, segments and rounded endpoint markers, with
Canvas/software/SVG coverage. Dense GPU packets explicitly request the Scene
fallback. Specialized clicks use shape distance; keyboard navigation and linked
selection use one stop/item per source row. Hover descriptions include source
columns; accessibility exposes one semantic row per source row. PlotView exports
source CSV and Python exposes semantic `table()` rows. The CSV fallback now
uses one header row and escapes quoted string/category fields and column names;
the evidence table is parsed from that actual export, with source values checked. Brush/lasso retain the
existing anchor-in-region rule (interactive primitive anchors, deduplicated row
keys); this is not a claim of polygon/rectangle intersection selection.

## Upstream provenance and comparison

Reference: `randyzwitch/dataviz_mojo` v0.8.0, exact commit
`3fd5a7e7c622d6130c99a290b88c4fee039deab2`, MIT, copyright Randy Zwitch 2026.
The complete notice is in `tests/fixtures/wave_a/DATAVIZ-LICENSE`, with source
module attribution in both layout implementations. The upstream runner checks
the revision and clean checkout, invokes real `Plot.mark_*().encode_*()` APIs,
and saves actual PNG and SVG output. It never patches upstream. Its locked
reference dependency is canvas_mojo v0.15.0 at
`58fb12a471a65dfbc29ebc743860448439a6af22`; Moxi uses its own locked environment.

Both outputs are 640×480 with the same source columns. No random inputs are used.
Upstream runs with DejaVu Sans from matplotlib 3.10.7 via its supported
`CANVAS_MOJO_FONT_PATH`; its font SHA is recorded. On this macOS host the default
font resolution chose a TTC file that this pinned Canvas parser could not read,
including during label measurement that does not honor Theme.font_family.
Supplying DejaVu Sans resolves this without changing reference sources.
Font files are local dependencies, not redistributed here.

`tests/fixtures/wave_a/observed.json` records actual file hashes, SVG element
counts/titles, Moxi glyph counts, source rows, selected keys, measurements and
classified differences. The comparison checks upstream SVG semantic titles for
lollipop and grouped/stacked bars, and exact Python/Mojo data-space primitive
coordinates for all nine fixtures. Unit assertions independently check layout
rules. The unaligned RGB delta is descriptive, never a pass threshold.

Common visual differences are the theme, palette, margins, grid, rounding and
text/legend handling. The current Canvas capture does not draw upstream's text
labels or per-series legend. Source tables and semantic rows are available;
this remains a visual fidelity gap. Python SVG carries the title; its raster/PDF
text support differs. Upstream uses circles for lollipop; Mojo uses rounded
rectangles and Python PDF uses its existing square marker fallback. Moxi's
candlestick/Gantt domains include zero while upstream fits the data. Grouped
errors paint above the bars in Moxi, below them upstream. Bullet shades differ.
Each family has its own classification and actual reference comparison slide.
These are specialized layouts, not pixel-identical upstream rendering.

Measurements separate workloads: 30 Mojo compile-to-Scene iterations, 30 Python
layout iterations, one Python PNG export, and upstream PNG+SVG export. They
include neither a native event loop nor physical presentation. The small checked
fixtures are not a large-data performance benchmark; the renderer and workload
are not equivalent enough to report a speed ratio. Current observations and
host details are in `observed.json`; reruns replace those observations.

## Exact reproduction and capture

Run from the implementation checkout. All generated reference and Moxi files
stay outside tracked source; screenshots/HTML and E01 exports are ignored.
Use a fresh temporary directory if these example paths already contain other work.

```sh
pixi install --locked
python3 -m venv /tmp/moxi-e01-venv
/tmp/moxi-e01-venv/bin/pip install pytest pillow numpy matplotlib==3.10.7
git clone --branch v0.8.0 --depth 1 https://github.com/randyzwitch/dataviz_mojo.git /tmp/moxi-e01-dataviz
pixi install --manifest-path /tmp/moxi-e01-dataviz/pixi.toml --locked
# Resolve font directory without assuming a Python minor version:
E01_FONTS=$(/tmp/moxi-e01-venv/bin/python -c 'import matplotlib; print(matplotlib.get_data_path()+"/fonts/ttf")')
PYTHONPATH=python /tmp/moxi-e01-venv/bin/python scripts/wave_a/upstream.py /tmp/moxi-e01-dataviz /tmp/moxi-e01-reference --font-dir "$E01_FONTS"
PYTHONPATH=python /tmp/moxi-e01-venv/bin/python scripts/wave_a/verify.py /tmp/moxi-e01-moxi
PYTHONPATH=python /tmp/moxi-e01-venv/bin/python scripts/wave_a/evidence.py /tmp/moxi-e01-reference /tmp/moxi-e01-moxi
PYTHONPATH=python /tmp/moxi-e01-venv/bin/pytest -q tests/python
python3 scripts/plot_spec_contract_check.py
python3 tests/demo_slideshows_test.py
for plot_test in plot_data plot_spec plot_runtime plot_view plot_render; do
  pixi run mojo run -I src "tests/$plot_test.mojo" > "/tmp/moxi-e01-$plot_test.log" 2>&1 || exit 1
done
python3 scripts/plot_spec_contract_check.py
python3 tests/demo_slideshows_test.py
python3 -m http.server 8971 --bind 127.0.0.1
```

Through the collaborative preview, set the viewport to 1280×900, device scale 1.
Use hyphens for fixture names in paths (for example `e01-grouped-bar`).
For each `e01-<fixture>` folder under `artifacts/demo-slideshows`, navigate to
`http://127.0.0.1:8971/artifacts/demo-slideshows/e01-<fixture>/source.html`,
`comparison.html`, and `selection.html`. Save actual browser screenshots with
`preview_snapshot(save=true)` and copy the returned PNG files to `01-source.png`,
`03-comparison.png`, and `04-selection.png` respectively. The report is explicitly
an evidence replay: selection was dispatched through Mojo PlotView, not through
HTML controls. Remaining slides are the actual upstream and Moxi offscreen PNGs.

`verify.py` dispatches a click at a real primitive midpoint, checks row selection,
exports source CSV and Scene SVG, updates the first row's numeric columns ×1.25
(except total flags), then restores the original snapshot. It asserts the update
image changes and restoration is pixel-exact. It also checks arrow/Enter/Escape
and linked selection. Python exports PNG/SVG/PDF through the real Figure methods.
No screenshot or intermediate state is generated from a fabricated UI.

```sh
python3 scripts/wave_a/slideshows.py
python3 scripts/wave_a/slideshows.py --check
```

Each of the nine manifests has source → real reference → Moxi/difference →
selection/table → export/update → restoration slides, following
`docs/demo-slideshows.md`. PNGs/HTML remain local; manifests, source fixtures,
observations and reproduction scripts are tracked. The evidence generator records
scoped source hashes and revision; the slideshow builder records capture hashes.
Rebuild and recapture after any relevant source change. The focused wrapper uses
`scripts/demo_slideshows.py`'s validator and renderer and writes
`artifacts/demo-slideshows/e01-index.html`; the repository-wide gallery includes
these sequences alongside the other locally available captures.

VoiceOver remains paused. Native-window input, human usability, physical frame
latency, full upstream tests, all platform/toolchain combinations, and large-data
performance were not checked. No external upstream acceptance is implied.
