# Python support

Moxi ships a clean-install Python package under `python/moxi`. It is a value-boundary package: importing it does not start Mojo, load a compiler, or require `canvas_mojo`.

The supported MVP is:

```python
import moxi

spec = moxi.PlotSpec("Telemetry")
spec.add_line("CPU", "time", "value")
figure = moxi.plot({"time": [0, 1, 2], "value": [1, 3, 2]}, spec)
figure.save("telemetry.svg")
pixels = figure.to_numpy()       # optional moxi[numpy]
```

The same value boundary covers the statistical recipe wave:

```python
recipe = moxi.PlotSpec("Distribution")
recipe.add_histogram("values", "value", bins=12)
figure = moxi.plot({"value": [1, 2, 2, 3, 5, 8]}, recipe)
png = figure.to_png()
```

The inventoried `dataviz_mojo` catalog is available through the same
row-oriented contract:

```python
catalog = moxi.PlotSpec("Schedule")
catalog.add_catalog_mark(
    "gantt", "tasks", "start", "duration", x2_field="end",
    color_field="team", opacity_field="confidence"
)
figure = moxi.plot({
    "start": [0, 1], "duration": [2, 3], "end": [2, 4],
    "team": ["red", "blue"], "confidence": [0.9, 0.7],
}, catalog)
figure.hit_test(120, 80)       # stable mark/layer/row anchor, or None
figure.accessibility()         # chart plus tabular mark summaries
```

Every catalog name has validation, static export geometry, row anchors, and a
shared parity/benchmark scenario. The optional `x2_field`, `y2_field`,
`size_field`, `color_field`/`fill_field`, `opacity_field`, `text_field`, and
statistic fields are carried by the same JSON schema. Row-native geometry is
implemented for the common interval, sector, edge, calendar, and sized-point
families; richer upstream nested-array layouts remain explicit promotion work.

The Python package and the Mojo package share the versioned `PlotSpec` JSON contract. `moxi.render(spec_json, named_columns, width, height, format)` is the low-level boundary for services that want bytes without retaining a `Figure`.

Current Python exports are deterministic reference implementations for PNG, SVG, PDF, and raw RGBA, plus NumPy conversion. Core marks and the recipe wave (histogram, density, ECDF, regression, hexbin, and error bars) use executable transforms rather than raw-point placeholders. Mapping-like column data and row sequences are supported directly. pandas and NumPy are optional adapters; they are not import-time dependencies.

This is the stable value-boundary lane, not a CPython extension. A future native/limited-ABI binding may reuse this contract, but the Python API will not depend on compiler availability. The support policy is documented in [the support matrix](support-matrix.md), and the clean-wheel gate is `pixi run python-check`.
