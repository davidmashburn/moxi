# I17 — One instrument with several bodies

Adapt an instrument's presentation to the person, input method, and device while preserving its meaning.

Status: speculative product concept, captured October 20, 2026.
Origin: Second brainstorm, idea 8. This is an idea brief, not an implementation commitment.

## Experience

A workstation shows a full canvas; a smaller device shows task-specific controls; a keyboard view exposes searchable objects and commands; an accessible outline preserves relationships without spatial navigation. Eventually a physical knob or six-degree-of-freedom controller can bind to a parameter or transform.

## Foundations and missing work

Relevant foundations: [Host architecture plan](../CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md), [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md), [Proposed 3D interfaces](../docs/design/3d-interaction.md).
See the [evidence boundary and shared requirements](README.md#evidence-and-shared-requirements).

Different local presentations can precede multiple devices. Connected devices need synchronization, ownership, authentication, conflict handling, and disconnect behavior; host portability supplies none of those automatically. Preserve native modifier conventions and host-specific input semantics.

## Smallest useful experiment

Present one instrument as a graphical panel and a keyboard/accessible structural view in a single host. Verify equivalent operations and state before adding a second host or device.

Confidence: **Moderate for local alternate views; low for distributed devices**. Equivalent task completion across local presentations would support the model; actual device reliability requires separate host and synchronization evidence.

## Assessment

User value **4/5** · Distinctiveness **4/5** · Moxi fit **4/5** ·
Feasibility **3/5** · Reuse **5/5**.
These are subjective comparisons under the [ranking rubric](RANKINGS.md#criteria), not measurements.

Potentially broad reach and reuse. Feasibility scores the bounded local alternate-view experiment; the full cross-device experience has substantially greater dependency and synchronization risk.

Related: [I05](i05-attachable-instruments.md), [I09](i09-curated-instrument-panels.md), [I18](i18-coordinated-representations.md), [I20](i20-reusable-application-operations.md).
Return to the [complete idea reference](README.md) or [rankings](RANKINGS.md).
