# Capability waves

The convergence work is intentionally staged:

| Wave | Contents | Exit evidence |
| --- | --- | --- |
| A / overlap | point, line, bar, area, box, heatmap | complete: shared PlotSpec, scene replay, Canvas/SVG/software checks, Python exports |
| B / recipes | histogram, density, ECDF, regression, hexbin, error bars | Python value-boundary transforms and exports are implemented and benchmarked; Mojo PlotSpec already carries the matching transforms; native accessibility/interaction parity remains a promotion check |
| C / static catalog | all inventoried catalog marks | complete: canonical Python/Mojo PlotSpec names, static Scene/export geometry, row anchors, accessibility summaries, parity fixtures, and repeated catalog benchmarks |
| D0 / row-native geometry | grouped/stacked bars, waterfall/candlestick/span, polar/radial, graph/flow edges, calendar cells, sized points | complete locally: deterministic rectangle, sector, segment, and channel-aware Python geometry; matching interval/edge Scene primitives in Mojo; shared fixtures cover exports and anchors |
| D / specialized layouts | nested Sankey routing, hierarchy packing, distribution envelopes, contour surfaces, full reference parity | future promotion: domain-specific nested schemas, reference comparison, and mark-specific interaction policy |

The external `dataviz_mojo` catalog contains additional specialized marks. The
histogram row is promoted through the recipe lane; the other recipe marks are
Moxi-native capabilities rather than aliases for absent upstream marks. The
catalog names now share Moxi's value boundary through `PlotSpec` and
`PlotSpec.add_catalog_mark`. Their inventory status is deliberately
`compatible-static`, so a usable row-native implementation is not mistaken for
exact parity with nested Sankey, hierarchy packing, distribution, or contour
algorithms. Further specialization can proceed mark by mark without changing
the serialized boundary.
