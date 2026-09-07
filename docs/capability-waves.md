# Capability waves

The convergence work is intentionally staged:

| Wave | Contents | Exit evidence |
| --- | --- | --- |
| A / overlap | point, line, bar, area, box, heatmap | shared PlotSpec, scene replay, Canvas/SVG/software checks, Python exports |
| B / recipes | histogram, density, ECDF, regression, hexbin, error bars | data transforms, bounds/validation, canonical checksums, accessibility summary |
| C / layouts | grouped/stacked bars, polar/radial, hierarchy, graph/flow, calendar | layout invariants, interaction policy, reference comparison, benchmark row |

The external `dataviz_mojo` catalog contains additional specialized marks. They remain visible as planned rows in `docs/dataviz-capabilities.tsv` until a complete evidence row exists. This prevents a broad API inventory from being mistaken for completed parity.
