# I19 — An interaction as an inspectable object

Represent an interaction with an origin, allowed changes, preview, constraints, and commit or cancellation.

Status: speculative framework concept, captured October 20, 2026.
Origin: First brainstorm's interaction synthesis; extended by replay and live instruments. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

A drag can also accept exact numeric entry, explain its active constraints, be cancelled, and commit as one undo unit. Its semantic result can be recorded, compared with alternatives, or shown as an agent proposal. Users can inspect what is changing before accepting it.

## Foundations and missing work

Relevant foundations: [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md), [Normalized event fixtures](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/event_replay.mojo), [Scoped request scheduler](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/tasks.mojo).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

A transient gesture session is not a durable replay record. Define revisions, conflict checks, coalescing, and explicit semantic command serialization. Previewing a local reversible edit does not make external side effects reversible.

## Smallest useful experiment

Implement one numeric/drag transform session with shared preview, Escape cancellation, and single-step undo. Replay its committed semantic command after a layout change; reject a stale target.

Confidence: **Moderate**. The same session behavior working for a canvas move and a parameter edit would strengthen the contract; consumer-specific state machines may require narrower sharing.

## Historical assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **5/5** ·
Feasibility **4/5** · Reuse **5/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

This directly supports tactile quality and many proposed products. Existing planned gesture contracts give a bounded experiment, though durable history remains new work.

Related: [I03](i03-inverse-design.md), [I07](i07-performed-explanations.md), [I11](i11-visible-agent-work.md), [I12](i12-live-tool-authoring.md), [I14](i14-mathematics-and-motion-studio.md), [I20](i20-reusable-application-operations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
