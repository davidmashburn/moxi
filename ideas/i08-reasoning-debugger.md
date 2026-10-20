# I08 — A debugger for your reasoning

Trace a result through assumptions, measurements, equations, and transformations.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 8. This is an idea brief, not an implementation commitment.

## Experience

Select a surprising result and highlight what contributed to it. Scrub meaningful edits, compare states, and temporarily suppress an assumption to inspect the consequences. Keep computational dependency, constraint, supporting evidence, and informal association visibly distinct.

## Foundations and missing work

Relevant foundations: [Proposed mind mapping](../docs/design/mind-mapping.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed math editing](../docs/design/math-editing.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Domain provenance must be recorded explicitly. A dependency graph cannot establish scientific causality or prove an argument. Suppressing an assumption requires an application-defined operation and may leave a model unevaluable.

## Smallest useful experiment

Trace one derived plot to source observations and a fitted equation. Show an invalidated result after a premise changes; compare a saved alternative without silently rewriting history.

Confidence: **Moderate**. Useful explanations from a small recorded provenance chain would support expansion; misleading causal interpretations would require narrower presentation.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **4/5** ·
Feasibility **2/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Understanding how a result arose has broad value. Capturing trustworthy provenance and distinguishing relationship kinds are the main costs.

Related: [I04](i04-possible-worlds.md), [I10](i10-investigations-become-tools.md), [I13](i13-visual-execution-debugger.md), [I15](i15-experiment-flight-recorder.md), [I16](i16-executable-essay.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
