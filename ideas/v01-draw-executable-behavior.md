# V01 — Draw executable behavior

Let designers and programmers author how something behaves by shaping its
responses, transitions, and constraints. A gesture becomes part of a precise
program that can be inspected and changed through several coordinated views.

## Experience

Design a camera that follows a moving character. Draw the desired response to
a sudden turn, pull the settling-time handle, and mark a region the camera
must never enter. A state graph describes tracking, anticipation, and recovery;
structured expressions define the transitions and response functions. Scrub
the scene, grab the trajectory, and try an alternative without losing the
previous behavior. A keyboard command selects the next constraint, exposes its
value, and adjusts it with the same preview and undo as dragging.

The larger vision includes animation behavior, musical instruments, reactive
applications, and simulated machines. People could exchange executable behavior
as an editable object with examples and acceptance conditions.

## What the combination enables

Plots can be authored specifications, measured traces, or constraint envelopes;
the editor makes those roles explicit. The graph supplies discrete structure,
math supplies precise relationships, and a 2D or 3D scene supplies consequences.
Editing a target response requests a candidate implementation within a chosen
model family. It does not silently rewrite an arbitrary program. Unsupported
targets remain visible as unsatisfied requirements.

## First question to test

Can a person create and revise a response without repeatedly translating their
intent between a curve editor, code, and a preview? Use one bounded motion
model, two states, and one trajectory. Compare direct parameter editing with
editing a target curve and selecting among candidates. Check whether people
can explain which representation owns each change and recover from a failed
fit. This can begin in 2D without a general solver or complete language editor.

## Assessment and uncertainty

Agency **5/5** · Expression **4/5** · Transfer **5/5**.
Probe cost **Medium**: response fitting, representation ownership, and integrated
editing are new work. The whole vision requires a much broader execution model.

Potential confidence: **Moderate**. Repeated successful revisions across two
behavior domains would strengthen it; constant escape to hidden code or
unpredictable inverse edits would weaken it. These are design hypotheses, not
claims of novelty or measured productivity.

Related ingredients: [progressive sketches](i01-progressively-executable-sketch.md),
[inverse design](i03-inverse-design.md), and
[application operations](i20-reusable-application-operations.md).
See the [portfolio](README.md), [ranking rubric](RANKINGS.md#criteria), and
[shared requirements](README.md#evidence-and-shared-requirements).
