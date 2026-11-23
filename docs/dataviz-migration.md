# dataviz_mojo migration and convergence

The external reference used for the overlap inventory is `dataviz_mojo` tag `v0.8.0`, commit `3fd5a7e7c622d6130c99a290b88c4fee039deab2`. The reference is a fluent chart builder with raster and SVG backends and a larger mark catalog than Moxi's current declarative PlotSpec.

Moxi absorbs the reusable contract and recipe capabilities, not the upstream package's private renderer or module layout:

- `PlotSpec` is the interchange boundary between Mojo, Python, and future native bindings.
- `line`, `point/scatter`, `bar`, `area`, `box`, and `heatmap` are the initial overlap set.
- The Python reference renderer proves the clean-install API and deterministic export path.
- The recipe wave now has executable Python transforms and export evidence for histogram, density, ECDF, hexbin, regression, and error bars; the matching Mojo PlotSpec transforms remain the cross-language source of truth.
- The inventoried catalog is now available through `PlotSpec.add_catalog_mark` and canonical Mojo `PLOT_*` values. Its row-oriented lane covers every inventory row with exports, row anchors, accessibility summaries, and benchmark/parity fixtures; common interval, sector, edge, calendar, and sized-point families now have deterministic row-native geometry. The inventory deliberately labels these rows `compatible-static` rather than claiming rich nested-layout parity.

For a mark to move from the static lane to a specialized implementation, add a canonical fixture, specify its field mapping and validation rules, emit the shared Scene contract, exercise the Canvas/SVG/software lanes, and record accessibility and interaction behavior. Visual comparisons classify structural geometry separately from font/platform pixels.

Use `pixi run dataviz-parity` to validate the pinned inventory, run the six overlap fixtures, the recipe wave, and every static catalog scenario. Set `DATAVIZ_MOJO_PATH` to a local checkout when doing a full upstream reference run; the check never vendors or imports upstream source into Moxi.

## E06 catalog reconciliation

Five families had public mark names and passing static export fixtures at Moxi
`839d0ff`. Each still needs a specialized layout. The comparisons below use
real upstream SVG exports at the v0.8.0 pin and Moxi's existing eight-row
catalog fixture. The two fixtures exercise different input contracts, so
these comparisons establish structural differences and carry no pixel score.

| Family | Upstream behavior exercised | Current Moxi behavior and proposed acceptance case |
| --- | --- | --- |
| [Parallel](../tests/fixtures/plot_catalog/parallel.svg) | Two records cross three independently scaled dimension axes. | Python connects raw x/y rows in input order. Native draws row markers. Require one path per record, named axes and a constant-dimension case. |
| [Funnel](../tests/fixtures/plot_catalog/funnel.svg) | Values 3, 9 and 6 produce stages B, C and A in descending order. Each band tapers to the next width. | Python emits points and native emits rectangles. Require centered trapezoids, a rectangular final band, and hit/table results that preserve original row IDs after sorting. |
| [Bump](../tests/fixtures/plot_catalog/bump.svg) | Two series exchange ranks across three categories. Rank 1 is at the top. | Python draws one raw-value line and native draws row markers. Require per-stage ranking, series identity, a tie fixture and rank-axis labels. |
| [Effect scatter](../tests/fixtures/plot_catalog/effect_scatter.svg) | Three observations produce six circles. Each marker sits above a larger, lighter halo. | Both backends draw a straight segment when secondary endpoints are supplied. The plain x/y form has a marker without a halo. Exercise the ordinary x/y form first and retain compatibility with existing endpoint specs. |
| [Arc diagram](../tests/fixtures/plot_catalog/arc_diagram.svg) | Three named nodes share a baseline, with weighted semicircles connecting them. | Both backends draw straight row-to-endpoint segments. Require shared node positions, curved weighted edges, node labels and edge selection that identifies the source record. |

Python SVG and PNG exports succeeded for all five current catalog fixtures.
All 40 tested anchor hits returned their original row index and all table
values matched the input. Native behavior in this audit comes from the
catalog branch in [plotting.mojo](../src/moxi_plot/plotting.mojo).
Native interaction, specialized geometry, timing and visual parity remain open.

Run the evidence check from the repository root:

```sh
PYTHONPATH=python python3 scripts/plot_catalog/check.py
```

To regenerate the reference SVGs, set `upstream` to a clean checkout of the
pinned dataviz commit and `font_dir` to a directory containing DejaVuSans.ttf.
The upstream renderer needs a TrueType font. The driver writes five SVG files
in the working directory.

```sh
root=$(pwd)
test "$(git -C "$upstream" rev-parse HEAD)" = 3fd5a7e7c622d6130c99a290b88c4fee039deab2 &&
test -z "$(git -C "$upstream" status --porcelain)" &&
mkdir -p dist/e06/reference &&
(cd dist/e06/reference && CANVAS_MOJO_FONT_PATH="$font_dir" pixi run \
  --manifest-path "$upstream/pixi.toml" mojo run -I "$upstream" \
  "$root/scripts/plot_catalog/reference.mojo") &&
diff -r tests/fixtures/plot_catalog dist/e06/reference
```
