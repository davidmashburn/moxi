# V04 — Design across material, mechanism, and system

Let a designer follow intent across scales: from a desired feeling or motion,
through a mechanism, down to geometry and material response. Each level offers
its own useful handles while exposing consequences elsewhere.

## Experience

Design a folding lamp whose arm moves easily and settles gently. Shape its
force-versus-angle curve, adjust a hinge, and watch the reach envelope change.
Pin the base footprint and compare two mechanisms. A material-response view
shows where the current approximation stops being credible. Step through joints
by keyboard, nudge a dimension precisely, or pull an endpoint while previewing
candidate changes to the permitted dimensions.

The horizon includes compliant structures, expressive mechanisms, responsive
architecture, and physical interfaces whose behavior matters as much as their
appearance. A design could carry both its geometry and the behavior it promises.

## What the combination enables

The scene describes shape, a graph describes assembly, equations describe
constraints, and plots describe behavior. Semantic navigation moves between
these different levels of explanation. The user explicitly chooses editable
parameters, fixed constraints, and objectives before requesting an inverse
change. Alternative solutions remain selectable; a failed solve preserves the
last committed design and explains which requirements conflict.

## First question to test

Can someone improve a mechanism by editing its behavior and still understand
the resulting geometry? Use a planar linkage with a simple spring model, one
force curve, and two allowed dimensions. Compare a bounded parameter sweep
against hand tuning. Test whether branch choice, infeasible targets, and undo
are understandable. This tests the relationship between views before adding
3D, material simulation, or manufacturing claims.

## Assessment and uncertainty

Agency **5/5** · Expression **4/5** · Transfer **4/5**.
Probe cost **High**: a coherent constrained mechanical model and predictable
inverse editing must work together. General multiscale design is a research
program with domain-specific validity boundaries.

Potential confidence: **Low**. A bounded mechanism task with intelligible
alternatives would strengthen it. Frequent discontinuities, unjustified model
accuracy, or expert-only constraint repair would weaken it. A persuasive
animation alone would not establish useful design capability.

Related ingredients: [inverse design](i03-inverse-design.md),
[living linkage](i21-living-linkage-sketch.md), and
[tangible mathematics](i02-tangible-mathematics.md).
See the [portfolio](README.md), [ranking rubric](RANKINGS.md#criteria), and
[shared requirements](README.md#evidence-and-shared-requirements).
