# V13 — Wire an executable instrument

Build a visual programming environment where people assemble acquisition,
computation, state, controls, and outputs into an instrument they can operate
and inspect. LabVIEW is a reference for the product category; Moxi's opportunity
is an unusually direct, keyboard-capable, tactile authoring experience.

## Experience

Connect a sensor stream to a filter, a feature calculation, a plot, and a
recording sink. Probe a wire to see values and timing, select a node to inspect
its state, and change a parameter while comparing the resulting trace with a
recorded run. Package the useful controls as a panel without hiding their
relationship to the executable graph. Keyboard commands create nodes, choose
typed ports, connect them, navigate execution, and adjust values with preview,
cancellation, and coherent undo.

The horizon includes experimental apparatus, interactive installations, robot
perception tools, and personally authored instruments. Recorded data and
simulation make an instrument useful before physical hardware is connected.

## What the combination enables

The canvas expresses the mechanism; plots expose observations and timing;
structured math defines transformations; native controls make the instrument
operable. Edges need explicit value or stream semantics, units, scheduling,
state, and failure behavior. A graph drawing library supplies none of those
execution rules automatically. Cycles need an explicit state/delay contract.

[V01](v01-draw-executable-behavior.md) emphasizes authoring desired behavior.
This vision emphasizes constructing and operating the mechanism. They can
coexist: wire a model, draw a target response, inspect candidate parameter
changes, and accept one. Neither experience requires the other.

## First question to test

Can someone build, diagnose, and revise a small instrument without losing the
connection between its wiring and its behavior? Use a recorded source, bounded
processing nodes, one explicit stateful node, a plot, and a recorder. Include a
rate mismatch, a failed node, and an invalid connection. Test keyboard-only
construction and cancellation of a live parameter preview. Keep acquisition
and execution scheduling separate from UI redraw; a device ecosystem and
hard real-time control are outside this first experiment.

## Assessment and uncertainty

Agency **4/5** · Expression **3/5** · Transfer **5/5**.
Probe cost **Medium**: a bounded dataflow runtime, typed connections, execution
inspection, and an operable panel must work together.

Potential confidence: **Moderate** for the instrument-building use case,
**Low** for Moxi's advantage. Independent authors building and debugging useful
instruments would strengthen it; opaque scheduling or excessive graph ceremony
would weaken it. Existing products establish a reference, not demand for this one.

Reference: NI's [dataflow explanation](https://www.ni.com/docs/en-GB/bundle/labview/page/block-diagram-data-flow.html)
describes execution driven by input availability. It informs the reference
model, without selecting a runtime or dependency for Moxi.

Related visions: [robot nose](v14-robot-nose.md),
[hand control](v15-hand-pose-control.md), and
[personal instruments](v12-personal-instruments.md).
See the [portfolio](README.md), [ranking rubric](RANKINGS.md#criteria), and
[shared requirements](README.md#evidence-and-shared-requirements).
