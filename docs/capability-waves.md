# Capability waves

The convergence work is intentionally staged:

| Wave | Contents | Exit evidence |
| --- | --- | --- |
| A / overlap | point, line, bar, area, box, heatmap | complete: shared PlotSpec, scene replay, Canvas/SVG/software checks, Python exports |
| B / recipes | histogram, density, ECDF, regression, hexbin, error bars | Python value-boundary transforms and exports are implemented and benchmarked; Mojo PlotSpec already carries the matching transforms; native accessibility/interaction parity remains a promotion check |
| C / layouts | grouped/stacked bars, polar/radial, hierarchy, graph/flow, calendar | layout invariants, interaction policy, reference comparison, benchmark row |

The external `dataviz_mojo` catalog contains additional specialized marks. The
histogram row is promoted through the recipe lane; the other recipe marks are
Moxi-native capabilities rather than aliases for absent upstream marks. The
remaining specialized marks stay visible as planned rows in
`docs/dataviz-capabilities.tsv` until a complete evidence row exists. This
prevents a broad API inventory from being mistaken for completed parity.
