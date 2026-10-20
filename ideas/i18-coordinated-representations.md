# I18 — Coordinated representations of the same object

Let stable domain identity connect tables, plots, equations, maps, and spatial views.

Status: speculative framework concept, captured October 20, 2026.
Origin: Shared synthesis in both brainstorms. This is an idea brief, not an implementation commitment.

## Experience

Select an observation in a table and locate it in a plot or specimen view. Move between an equation and its geometric interpretation while retaining the relevant selection. Give objects optional domain capabilities such as measurement or sampling so instruments can attach through explicit interfaces.

## Foundations and missing work

Relevant foundations: [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [Proposed math editing](../docs/design/math-editing.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Applications own domain models and mappings. Transform ancestry, document ancestry, and semantic ownership remain distinct. Derived geometry can be many-to-one or partial; only the specified math text/layout pair promises lossless one-to-one representation. Avoid a universal schema.

## Smallest useful experiment

Carry one stable observation selection between the existing table/plot and a new canvas card. Handle filtered, deleted, and aggregated observations explicitly, then test a second domain.

Confidence: **Moderate**. Two domains sharing a small mapping contract would justify extraction; broad exception tables would argue for keeping mappings local.

## Assessment

User value **4/5** · Distinctiveness **3/5** · Moxi fit **5/5** ·
Feasibility **4/5** · Reuse **5/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

This extends existing stable-key behavior and benefits most concepts. Its value comes from consistent semantics rather than novelty.

Related: [I02](i02-tangible-mathematics.md), [I05](i05-attachable-instruments.md), [I06](i06-semantic-zoom.md), [I10](i10-investigations-become-tools.md), [I17](i17-one-instrument-many-bodies.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
