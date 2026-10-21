# V14 — Give a robot predictive chemical perception

Give a robot chemical sensor input that might help it predict something useful
about its surroundings. Make this unfamiliar sensory world inspectable: what
was measured, what the model inferred, what it predicted, and what happened.
Identifying a substance is one possible task, not the definition of the project.

## Experience

Replay a robot's route alongside chemical sensor responses and observations of
a chosen outcome. Inspect where a model anticipated a change, where it was
uncertain, and where it failed. Select a time interval in a trace to highlight
the matching location, sensor channels, learned representation, and subsequent
outcome. Compare episodes with similar responses but different outcomes.
Keyboard navigation can select episodes, align traces, inspect predictions,
and revise model settings without depending on a spatial gesture.

The horizon includes anticipating environmental conditions or process stages,
and choosing where or when to sample next. These are candidate tasks to test,
not demonstrated capabilities of a particular sensor. The robot's actions
could eventually help it gather more informative observations.

## What the combination enables

Plots expose signals and uncertainty; spatial views connect measurements to
place and movement; graphs expose processing and decision paths; math makes
transformations inspectable. A learned sensory representation could become a
new perceptual instrument within [V08](v08-instruments-for-invisible-phenomena.md).
A useful interface would let people interrogate a machine's unfamiliar evidence
without pretending to share the robot's senses directly.

Keep the physical phenomenon, measured sensor response, learned representation,
prediction, and action distinct. A visually separated embedding is not proof of
chemical identity or predictive value. Manipulating a view or a hypothetical
input must not rewrite recorded observations. Label observed and inferred fields,
calibration context, acquisition times, and uncertainty.

## First question to test

Does chemical input improve a specified prediction beyond an appropriate
baseline, and can a person understand when that improvement fails? Choose one
outcome and prediction horizon; collect timestamped sensor recordings paired
with outcomes. Compare models with and without chemical input on held-out
collection sessions, checking for temporal leakage and environmental confounds.
Inspect calibration, changing response over time, and failures through replay.
Synthetic data can test the UI but cannot establish predictive usefulness.
Autonomous sampling is a later experiment, contingent on useful evidence.

## Assessment and uncertainty

Agency **4/5** · Expression **4/5** · Transfer **3/5**.
Probe cost **High**: credible sensor collection, outcome alignment, predictive
evaluation, and an honest replay interface cross several uncertain boundaries.

Potential confidence: **Low** for predictive usefulness, **High** for its
conceptual fit with V08. Repeatable improvement on independent recordings would
strengthen the product case; benefits explained by leakage or simpler inputs
would weaken it. No sensor, chemistry model, or robot platform is selected.

Related visions: [visual instrumentation](v13-visual-instrumentation.md) for
constructing the pipeline and [hand control](v15-hand-pose-control.md) for
optional exploration controls. Sensing the world and intentionally controlling
an interface remain separate roles even when combined in one instrument.
See the [portfolio](README.md), [ranking rubric](RANKINGS.md#criteria), and
[shared requirements](README.md#evidence-and-shared-requirements).
