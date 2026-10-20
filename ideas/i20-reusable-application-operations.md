# I20 — Application operations across interaction styles

Expose domain operations so controls, keyboard commands, scripts, agents, and recorded procedures can share their meaning.

Status: speculative framework concept, captured October 20, 2026.
Origin: Second brainstorm's framework synthesis. This is an idea brief, not an implementation commitment.

## Experience

A parameter change or cohort creation can be invoked through several presentations, with application-owned validation, stable targets, and policy. Searchable operation descriptions improve discoverability. Scripts and agent adapters use explicit invocation paths rather than mutating component internals.

## Foundations and missing work

Relevant foundations: [In-process capability bus](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/capability_bus.mojo), [Conversation context](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/conversation.mojo), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Typed UI actions and capability invocations have different responsibilities. Share the underlying domain operation where appropriate; do not force every pointer event through JSON or authorization machinery. Persistent macros need versioned arguments and results.

## Smallest useful experiment

Route a button, keyboard command, and deterministic scripted invocation to one cohort operation. Verify equivalent results, appropriate caller policy, and stable behavior when view IDs change.

Confidence: **Moderate**. A small shared handler that reduces duplicate behavior would support the direction; disproportionate envelope or policy plumbing would favor a narrower boundary.

## Assessment

User value **4/5** · Distinctiveness **3/5** · Moxi fit **5/5** ·
Feasibility **4/5** · Reuse **5/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

The concept builds on implemented action and capability seams and has broad reuse. Generalized automation still requires explicit application contracts.

Related: [I09](i09-curated-instrument-panels.md), [I11](i11-visible-agent-work.md), [I12](i12-live-tool-authoring.md), [I17](i17-one-instrument-many-bodies.md), [I19](i19-inspectable-interactions.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
