# I12 — An application that grows new instruments while you use it

Extend an application at the moment a user discovers a missing instrument.

Status: speculative product concept, captured October 20, 2026.
Origin: Second brainstorm, idea 3. This is an idea brief, not an implementation commitment.

## Experience

Capture five repeated operations, expose two parameters, and pin a new control. Open its implementation, change the calculation, preview it against current data, and explicitly replace the old instrument. Direct composition, handwritten Mojo, and generated components could offer different authoring routes.

## Foundations and missing work

Relevant foundations: [Reloadable scene shell](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/live_script.mojo), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [In-process capability bus](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/capability_bus.mojo), [Proposed canvas interactions](../docs/design/canvas-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

The existing demo swaps a scene module; it does not migrate arbitrary component state. Define module lifetimes, build failures, versioned state migration, preview isolation, and rollback. Generated code must use the same explicit boundaries.

## Smallest useful experiment

Replace one calculation behind a fixed panel with a versioned value interface. Preserve host focus and data; keep the last working version after a failed build. Defer arbitrary component replacement.

Confidence: **Low**. A safe replacement across one interface change would raise confidence; native lifetime hazards or unavoidable lost state would constrain the feature to development tools.

## Assessment

User value **4/5** · Distinctiveness **5/5** · Moxi fit **5/5** ·
Feasibility **1/5** · Reuse **5/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Very distinctive and potentially reusable, but live compilation and state evolution make it one of the riskiest integrations.

Related: [I09](i09-curated-instrument-panels.md), [I13](i13-visual-execution-debugger.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
