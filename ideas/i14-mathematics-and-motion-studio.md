# I14 — A playable mathematics and motion studio

Turn equations, transformations, and recorded gestures into an expressive performance surface.

Status: speculative product concept, captured October 20, 2026.
Origin: Second brainstorm, idea 5. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

An equation defines a trajectory, a graph connects transformations, and an object follows it. Record a coefficient gesture, edit it as a curve, snap to meaningful mathematical states, and move between configurations. Keyboard actions latch parameters, hold constraints, step states, and enter exact values. A future audio adapter could add oscillators, tuning, rhythm, and spatial sound.

## Foundations and missing work

Relevant foundations: [Proposed math editing](../docs/design/math-editing.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Define gesture recording, clock ownership, curve interpolation, and playback semantics. Audio requires a separate real-time engine and scheduling contract; UI frame timing cannot serve as proof of audio readiness.

## Smallest useful experiment

Animate a 2D trajectory with one recorded parameter curve and keyboard-controlled latch. Edit the curve during a stopped preview and replay deterministically before attempting audio.

Confidence: **Moderate for visual motion; low for audio integration**. Responsive performance with predictable timing would support the visual product; audio feasibility needs an independent measured engine prototype.

## Historical assessment

User value **3/5** · Distinctiveness **5/5** · Moxi fit **5/5** ·
Feasibility **2/5** · Reuse **4/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

A distinctive tactile showcase with reusable animation instruments. Its audience is narrower and timing requirements more demanding than the data workbench.

Related: [I02](i02-tangible-mathematics.md), [I05](i05-attachable-instruments.md), [I07](i07-performed-explanations.md), [I19](i19-inspectable-interactions.md), [I21](i21-living-linkage-sketch.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
