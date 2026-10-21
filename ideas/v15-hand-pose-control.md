# V15 — Play a tool with the whole hand

Use a camera pointed at a hand as a continuous, high-dimensional controller.
Palm position and orientation, finger curl, spread, and relationships among
fingers could become expressive inputs. The ambition is simultaneous control
with learned fluency, beyond recognizing a handful of discrete gestures.

## Experience

Shape a sound or simulated material while moving the hand. Demonstrate a few
comfortable poses, associate them with meaningful results, and explore the
space between them. A clutch engages control; releasing it lets the person
reposition without changing the composition. Freeze a result, inspect its
parameters, adjust a response curve, and save the mapping as an instrument.

The horizon includes musical performance, animation, spatial modeling, robot
teleoperation, and exploration of high-dimensional models. Meaningful mappings
might use a subset of hand features or interpolate among demonstrated poses;
no fixed one-finger/one-parameter vocabulary is assumed.

## What the combination enables

A camera adapter estimates pose; plots expose response curves and coupling;
math defines transformations; a graph describes clutch and mode behavior;
a 2D or 3D view makes consequences immediate. [V12](v12-personal-instruments.md)
supplies the broader question of authoring a personal interaction language.

Estimated landmark count is not the number of independently usable controls.
Tracking uncertainty, occlusion, coupled movement, fatigue, and accidental
activation must inform the mapping. Show which inputs are active, support
recalibration, and make tracking loss enter an explicit domain-appropriate
hold or disengaged state. Reacquisition must not cause a parameter jump.
Camera input does not itself provide physical force feedback.

Keyboard interaction remains primary for authoring mappings, selecting axes,
precise adjustment, clutch alternatives, and committing or reverting edits.
It need not imitate every simultaneous performance gesture to expose the same
domain operations. Primary shortcuts use Cmd on macOS and Ctrl on Windows/Linux.

## First question to test

Can someone intentionally and repeatedly control several coupled parameters
more expressively than with separate sliders? Choose one creative task and a
small initial subset of continuous hand features. Compare independent mappings
with demonstrated pose interpolation. Measure repeatability, end-to-end latency,
accidental activation, comfort, and recovery from occlusion or tracking loss.
Keep recorded input replay so mapping failures can be separated from tracker
failures. Expand dimensionality only when useful control survives the expansion.

## Assessment and uncertainty

Agency **4/5** · Expression **5/5** · Transfer **5/5**.
Probe cost **Medium**: a tracker adapter, calibration, clutch, editable mappings,
and confidence/loss handling need integration for one bounded task.

Potential confidence: **Low** for usable simultaneous control. Intentional,
repeatable performance across sessions would strengthen it; fatigue, unwanted
coupling, or substantial tracking dependence would weaken it. No full recovery
of all hand degrees of freedom or universal accessibility benefit is claimed.

Reference: [MediaPipe Hands](https://arxiv.org/abs/2006.10214) describes single-RGB-camera
hand tracking. It is an implementation reference, not a dependency choice;
code, model assets, and transitive licenses need separate assessment.

Related visions: [cross-media composition](v06-compose-across-media.md),
[invented notation](v03-invent-notations.md),
[invisible phenomena](v08-instruments-for-invisible-phenomena.md), and
[visual instrumentation](v13-visual-instrumentation.md).
See the [portfolio](README.md), [ranking rubric](RANKINGS.md#criteria), and
[shared requirements](README.md#evidence-and-shared-requirements).
