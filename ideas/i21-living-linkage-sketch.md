# I21 — A living linkage sketch

Demonstrate coordinated math, geometry, alternatives, and reusable controls with a small mechanism.

Status: speculative demonstrator concept, captured October 20, 2026.
Origin: First brainstorm's proposed first demonstration. This is an idea brief, not an implementation commitment.

## Experience

Manipulate a few joints and bars, inspect editable equations and a trajectory trace, pin a length, and branch into another configuration. Keep alternatives in a mind map. Package the interesting controls into a small instrument panel. A kinetic sculpture supplies the motivating example.

## Foundations and missing work

Relevant foundations: [Proposed math editing](../docs/design/math-editing.md), [Proposed mind mapping](../docs/design/mind-mapping.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Choose a bounded kinematic model and explicit constraints; a full CAD kernel or physics engine is unnecessary. A planar mechanism can establish the interaction before any 3D renderer dependency.

## Smallest useful experiment

Use a single planar linkage with one degree of freedom, one editable length, and a trace. Verify pointer and keyboard editing, exact text/layout round trips, cancellation, and shared undo before adding branches or 3D.

Confidence: **Moderate**. A compelling small mechanism with understandable constraints would strengthen its showcase value; solver discontinuities would favor the simpler matrix demonstrator.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **5/5** ·
Feasibility **3/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

A vivid end-to-end showcase for the new plans, but it requires more new surfaces than the existing workbench experiment. Its pieces are more reusable than its specific mechanism.

Related: [I01](i01-progressively-executable-sketch.md), [I02](i02-tangible-mathematics.md), [I04](i04-possible-worlds.md), [I09](i09-curated-instrument-panels.md), [I14](i14-mathematics-and-motion-studio.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
