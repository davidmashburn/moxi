# I07 — An explanation you can perform

Record an explanation as meaningful, interruptible actions over an executable model.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 7. This is an idea brief, not an implementation commitment.

## Experience

Introduce an assumption, reveal a term, rotate the model, vary a parameter, and split into alternatives. During playback, the audience can inspect a dependency, change a value, or branch into another case, then return to the author's path. The same explanation can be presented as keyboard steps or a textual sequence.

## Foundations and missing work

Relevant foundations: [Normalized event fixtures](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/event_replay.mojo), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed math editing](../docs/design/math-editing.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Normalized input replay is only a foundation. Authoring needs semantic commands, versioned model/resource snapshots, checkpoints, branching, and a clear return policy. External results and timing must be captured when required for reproducibility.

## Smallest useful experiment

Record five semantic actions over a deterministic model. Interrupt after action three, explore, and return to the checkpoint without contaminating the authored path.

Confidence: **Moderate**. A short explanation that survives layout changes and audience interruption would strengthen confidence; dependence on pixel coordinates would invalidate the approach.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **4/5** ·
Feasibility **2/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Teaching and review benefit from executable explanations, but durable playback and branch restoration add substantial work beyond existing event fixtures.

Related: [I04](i04-possible-worlds.md), [I16](i16-executable-essay.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
