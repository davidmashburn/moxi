# I09 — Make an instrument panel from what matters

Turn a selection of parameters, measurements, and views into a reusable instrument panel.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 9. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

Select three parameters, two measurements, and a viewport. Package them into a compact panel that another person can use without navigating the construction. Keep an explicit path into its internals. A researcher creates a teaching widget, a designer a configurator, or a developer a diagnostic panel.

## Foundations and missing work

Relevant foundations: [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Packaging needs an explicit value specification, dependencies, defaults, and supported operations. Do not serialize live components, closures, native handles, or caches. Initial reuse can stay inside one application.

## Smallest useful experiment

Extract a panel from the data workbench using fixed supported controls. Save its declarative configuration, reopen it, and verify that it still controls the intended values.

Confidence: **Moderate**. A compact configuration shared by two panels would increase confidence; requiring arbitrary object serialization would change the design.

## Historical assessment

User value **4/5** · Distinctiveness **3/5** · Moxi fit **5/5** ·
Feasibility **4/5** · Reuse **5/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

The interaction is familiar but highly useful and reusable. Fixed component choices make a first experiment relatively feasible.

Related: [I05](i05-attachable-instruments.md), [I10](i10-investigations-become-tools.md), [I12](i12-live-tool-authoring.md), [I17](i17-one-instrument-many-bodies.md), [I20](i20-reusable-application-operations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
