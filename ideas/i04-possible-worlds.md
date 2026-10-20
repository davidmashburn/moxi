# I04 — Mind maps of possible worlds

Use branches to keep competing assumptions and parameter configurations alive together.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 4. This is an idea brief, not an implementation commitment.

## Experience

Create alternatives such as a lighter arm, a removed equation term, or a different joint. Each branch holds overrides and a small live preview. Scrub a shared parameter across the alternatives, compare pinned metrics, and promote a chosen result. Record why the alternative exists beside what changed.

## Foundations and missing work

Relevant foundations: [Proposed mind mapping](../docs/design/mind-mapping.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed math editing](../docs/design/math-editing.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Define snapshot versus inherited values, explicit shared dependencies, recomputation, and promotion semantics. Visual ancestry alone cannot determine computational dependencies. Comparing alternatives must not require solving arbitrary semantic merges.

## Smallest useful experiment

Compare three parameter sets of one existing plot, with one shared input and one local override. Promote one set as an explicit transaction and undo it.

Confidence: **Moderate**. Confidence rises if users predict inheritance and promotion correctly; frequent accidental coupling would require a simpler branch model.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **5/5** ·
Feasibility **3/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Alternative exploration serves many domains and fits maps plus reactive views. Explicit parameter overrides give it a smaller first slice than full document branching.

Related: [I01](i01-progressively-executable-sketch.md), [I03](i03-inverse-design.md), [I08](i08-reasoning-debugger.md), [I10](i10-investigations-become-tools.md), [I19](i19-inspectable-interactions.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
