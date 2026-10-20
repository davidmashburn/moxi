# I15 — A flight recorder for experiments and incidents

Capture a surprising episode as a reproducible investigation artifact.

Status: speculative product concept, captured October 20, 2026.
Origin: Second brainstorm, idea 6. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

A running program, machine, or experiment feeds linked plots, events, a structural map, and an optional spatial model. Freeze a bounded interval, rewind, follow an observation to its source, annotate hypotheses, and compare a counterfactual model. Another person can investigate the saved episode.

## Foundations and missing work

Relevant foundations: [Normalized event fixtures](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/event_replay.mojo), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Scoped request scheduler](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/tasks.mojo), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Input replay alone cannot reproduce an external system. Capture relevant results, clocks, randomness, versions, resource identity, and retention policy. Distinguish recorded observations from simulated alternatives and identify incomplete captures.

## Smallest useful experiment

Record a deterministic synthetic stream plus one asynchronous result, reopen the artifact, and reproduce the selected episode. Inject a missing result and display the replay limitation explicitly.

Confidence: **Moderate**. Portable replay with clear missing-data behavior would strengthen confidence; uncontrolled external dependencies would narrow the supported recorder scope.

## Historical assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **4/5** ·
Feasibility **2/5** · Reuse **4/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

Useful for diagnosis across domains, with substantial reusable capture machinery. External-state completeness makes it more difficult than replaying an internal UI fixture.

Related: [I08](i08-reasoning-debugger.md), [I13](i13-visual-execution-debugger.md), [I16](i16-executable-essay.md), [I19](i19-inspectable-interactions.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
