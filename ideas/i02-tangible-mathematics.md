# I02 — Mathematics you can physically interrogate

Give mathematical structures precise visual handles with coordinated symbolic and geometric views.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 2. This is an idea brief, not an implementation commitment.

Portfolio status: retained from the earlier brainstorm. Its assessment below
uses the superseded implementation-oriented rubric. See the
[current portfolio](README.md#product-visions) for broader product visions and
[framework questions](FRAMEWORK.md) for supporting mechanisms.

## Experience

A matrix exposes a coordinate frame: drag a basis vector to change its entries, or edit an entry to move the frame. Pin the determinant and explore allowed transformations. A derivative becomes a tangent probe, an integral a stretchable region, a complex number a rotation handle, and an eigenvector a direction to test. Snap feedback reveals meaningful mathematical states.

## Foundations and missing work

Relevant foundations: [Proposed math editing](../docs/design/math-editing.md), [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Each gesture needs a declared mathematical interpretation and numerical behavior near singularities. The WYSIWYG expression always retains its one-to-one editable text form; a computed or sampled visualization is a projection, not a lossless substitute for the expression.

## Smallest useful experiment

Start with a 2D matrix and basis vectors, exact numeric entry, keyboard movement, shared selection, and one undo history. Add determinant constraints only after unconstrained editing works.

Confidence: **Moderate**. A matrix prototype that remains predictable near singular cases would strengthen confidence; unexplained jumps or opaque constraint choices would weaken it.

## Historical assessment

User value **4/5** · Distinctiveness **5/5** · Moxi fit **5/5** ·
Feasibility **3/5** · Reuse **4/5**.
These are subjective comparisons under the [historical ranking rubric](HISTORICAL-RANKINGS.md#criteria), not measurements.

Direct mathematical manipulation is an expressive showcase for reactive UI. A bounded matrix example is tractable even though general symbolic geometry is not.

Related: [I03](i03-inverse-design.md), [I05](i05-attachable-instruments.md), [I14](i14-mathematics-and-motion-studio.md), [I18](i18-coordinated-representations.md), [I21](i21-living-linkage-sketch.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
