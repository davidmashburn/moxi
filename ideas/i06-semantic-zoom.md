# I06 — Semantic zoom as a way of thinking

Navigate between argument, diagram, equation, and editable subexpression while preserving orientation.

Status: speculative product concept, captured October 20, 2026.
Origin: First brainstorm, idea 6. This is an idea brief, not an implementation commitment.

## Experience

From a distant map of questions and conclusions, enter a node's live diagram, then its equations, then a numerator. Follow a symbol to its definition or measurement and return to the exact origin. Keep multiple levels open side by side when useful. Keyboard enter, leave, follow, and return actions complement spatial transitions.

## Foundations and missing work

Relevant foundations: [Proposed mind mapping](../docs/design/mind-mapping.md), [Proposed canvas interactions](../docs/design/canvas-interaction.md), [Proposed math editing](../docs/design/math-editing.md), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Presentation changes need stable focus, selection mapping, breadcrumbs, and explicit entry rules. Zoom must not unexpectedly enter an editor or replace familiar content. A reduced-motion structural path must preserve the same navigational meaning.

## Smallest useful experiment

Build three explicit levels around one plot and its formula. Return to the same caret and selection after visiting a definition; verify keyboard-only traversal.

Confidence: **Moderate**. Navigation that remains predictable without animation would raise confidence; disorientation or loss of editing state would lower it.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **5/5** ·
Feasibility **3/5** · Reuse **4/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

This could make dense workspaces usable while exercising moxi's identity and focus contracts. Explicit levels keep the experiment smaller than automatic semantic zoom.

Related: [I01](i01-progressively-executable-sketch.md), [I07](i07-performed-explanations.md), [I16](i16-executable-essay.md), [I18](i18-coordinated-representations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
