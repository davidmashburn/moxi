# I05 — Instruments you can pick up and attach

Make probes, rulers, constraints, recorders, comparators, and sensitivity views reusable semantic components.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 5. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

Attach a probe to a moving point and turn its output into a graph. Connect the graph to a threshold to produce an event marker. Move the instrument between a canvas, a document margin, and an object anchor while keeping its identity and connection. A sensitivity lens exposes which adjustable inputs influence a result.

## Foundations and missing work

Relevant foundations: [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Applications must provide typed capabilities such as sampling or measurement, units, attachment lifetimes, and invalidation rules. Sensitivity analysis needs a domain computation adapter. Reuse must be demonstrated across real consumers before generalizing interfaces.

## Smallest useful experiment

Use one measurement component in both a plot and a geometry explorer. Preserve its attachment, units, keyboard controls, and history when changing presentation.

Confidence: **Moderate**. Two independently built consumers sharing the same instrument would strengthen the case; many adapter exceptions would weaken the proposed abstraction.

## Historical assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **5/5** ·
Feasibility **3/5** · Reuse **5/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

Useful semantic components could multiply across applications. Domain attachment and units cost more than ordinary widget composition, but a single measurement is bounded.

Related: [I02](i02-tangible-mathematics.md), [I09](i09-curated-instrument-panels.md), [I10](i10-investigations-become-tools.md), [I14](i14-mathematics-and-motion-studio.md), [I18](i18-coordinated-representations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
