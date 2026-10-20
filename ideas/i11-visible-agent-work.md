# I11 — Agents that work visibly inside your tools

Make delegated work inspectable in the same domain workspace the user manipulates.

Status: speculative product concept, captured October 20, 2026.
Origin: Second brainstorm, idea 2. This is an idea brief, not an implementation commitment.

## Experience

Select a troublesome model region and ask for investigation. Candidate fits, annotated plots, proposed parameter changes, and unresolved questions appear beside it. Delegate exploration of specific parameters under pinned constraints; inspect intermediate results and bring back three alternatives. Scope follows domain objects and allowed operations, not screen coordinates.

## Foundations and missing work

Relevant foundations: [In-process capability bus](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/capability_bus.mojo), [Conversation context](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/conversation.mojo), [Scoped request scheduler](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/tasks.mojo), [Proposed canvas interactions](../docs/design/canvas-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

The synchronous in-process bus is not a model client or distributed scheduler. Add transport, scoped object permissions, isolation, revision checks, cancellation, and explicit proposal previews. An agent adapter must not receive unrestricted mutable application state.

## Smallest useful experiment

Use a deterministic fake worker to propose changes to two permitted parameters. Inspect, reject, or apply its proposal; reject stale results after a user edit before adding a real model adapter.

Confidence: **Moderate**. Understandable proposals and reliable scope enforcement would support real adapters; opaque edits or confusing conflict handling would weaken the direction.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **4/5** ·
Feasibility **2/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Visible delegation could improve many workflows, but integration and trustworthy application boundaries dominate the first slice. Agent integration remains optional.

Related: [I03](i03-inverse-design.md), [I04](i04-possible-worlds.md), [I10](i10-investigations-become-tools.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
