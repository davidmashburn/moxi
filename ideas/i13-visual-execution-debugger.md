# I13 — A visual debugger you can climb inside

Make runtime behavior inspectable through coordinated graphs, timelines, plots, and frame views.

Status: speculative product concept, captured October 20, 2026.
Origin: Second brainstorm, idea 4. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

Show tasks, dependencies, and queues on a canvas; plot latency and allocations; select a spike to find the operation and affected subtree. Freeze a frame to inspect input, state changes, geometry, and rendering, then replay after a code change. Explore spatial ownership or memory views only when depth helps.

## Foundations and missing work

Relevant foundations: [Localized execution](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/execution.mojo), [Normalized event fixtures](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/event_replay.mojo), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Existing counters and fixtures do not provide a complete causal trace. Add bounded correlated records, explicit timestamps, retained snapshots, and measurement of tracing overhead. Allocation and memory visualization need additional instrumentation.

## Smallest useful experiment

Correlate one recorded action with subtree rebuild counters and a frame preview in a deterministic demo. Compare two replays and show dropped trace records explicitly.

Confidence: **Moderate**. Actionable explanations at bounded overhead would strengthen the case; diagnostic work that materially changes the observed timing would require a narrower recorder.

## Historical assessment

User value **4/5** · Distinctiveness **3/5** · Moxi fit **5/5** ·
Feasibility **4/5** · Reuse **5/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

Developer tooling is familiar, but moxi already exposes unusually relevant ingredients. It offers immediate internal use and reusable diagnostic components.

Related: [I08](i08-reasoning-debugger.md), [I12](i12-live-tool-authoring.md), [I15](i15-experiment-flight-recorder.md), [I18](i18-coordinated-representations.md), [I19](i19-inspectable-interactions.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
