# dataviz_mojo migration and convergence

The external reference used for the overlap inventory is `dataviz_mojo` tag `v0.8.0`, commit `3fd5a7e7c622d6130c99a290b88c4fee039deab2`. The reference is a fluent chart builder with raster and SVG backends and a larger mark catalog than Moxi's current declarative PlotSpec.

Moxi absorbs the reusable contract and recipe capabilities, not the upstream package's private renderer or module layout:

- `PlotSpec` is the interchange boundary between Mojo, Python, and future native bindings.
- `line`, `point/scatter`, `bar`, `area`, `box`, and `heatmap` are the initial overlap set.
- The Python reference renderer proves the clean-install API and deterministic export path.
- The Mojo PlotSpec already carries histogram, density, ECDF, hexbin, and regression recipes; those remain part of the next capability wave rather than being mislabeled as upstream parity.

For a mark to move from planned to implemented, add a canonical fixture, specify its field mapping and validation rules, emit the shared Scene contract, exercise the Canvas/SVG/software lanes, and record accessibility and interaction behavior. Visual comparisons classify structural geometry separately from font/platform pixels.

Use `pixi run dataviz-parity` to validate the pinned inventory and run the six overlap fixtures. Set `DATAVIZ_MOJO_PATH` to a local checkout when doing a full upstream reference run; the check never vendors or imports upstream source into Moxi.
