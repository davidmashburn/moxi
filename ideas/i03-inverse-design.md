# I03 — Design by pulling on consequences

Let users manipulate a desired result while explicitly choosing which inputs may change.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 3. This is an idea brief, not an implementation commitment.

## Experience

Pull a trajectory peak upward while pinning its landing point. Stretch a mechanism's reach while preserving its footprint. Drag a response curve toward a target while locking coefficients. Candidate solutions appear as inspectable alternatives; impossible targets expose the conflicting constraints.

## Foundations and missing work

Relevant foundations: [Proposed math editing](../docs/design/math-editing.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md), [Scoped request scheduler](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/tasks.mojo).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

This requires domain-specific inverse solving, admissible ranges, units, solution selection, and cancellation. Direct manipulation does not imply a general inverse for arbitrary code. Preview changes only to the parameters the user authorized.

## Smallest useful experiment

Use a low-dimensional trajectory with two adjustable parameters and one pinned constraint. Compare solver proposals, reject an infeasible target, and cancel a pending solve without stale changes.

Confidence: **Low**. Raise confidence when a bounded solver gives continuous, understandable feedback across multiple solutions; discontinuity and unstable latency are decisive negative evidence.

## Assessment

User value **5/5** · Distinctiveness **5/5** · Moxi fit **5/5** ·
Feasibility **1/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Expressing intent against results has unusually high potential value and distinctiveness. Solver semantics and responsive feedback make feasibility the weakest dimension.

Related: [I02](i02-tangible-mathematics.md), [I04](i04-possible-worlds.md), [I11](i11-visible-agent-work.md), [I19](i19-inspectable-interactions.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
