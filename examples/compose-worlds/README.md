# Compose Worlds

Build the offline browser app from the repository root with
`python3 examples/compose-worlds/build.py`, then open
`dist/compose-worlds/index.html`. Run the model checks with
`node examples/compose-worlds/check.mjs`.

Predict the grazer density relative to the reference bed at season 12. Change
the midpoint of the branch feeding curve, then run the comparison. Scrub the
season slider to inspect when the beds diverge. Reset restores the original
rule and both initial maps. Each history row replays its own prediction and
midpoint from the same seed. History lasts for the current page session.

Seed 2407 fixes kelp cover and grazer patches across 512 cells. Each season,
20% of grazer density mixes with the four wrapped neighbors. Kelp grows
logistically. Grazers remove kelp in proportion to their density and a
three-knot, piecewise-linear feeding response. Food offsets grazer mortality.
Green intensity encodes kelp cover and amber disc area encodes grazer density.
Percentages report mean density across the bed. Both maps use identical scales.

The Python builder uses the checkout's public Moxi PlotSpec and Figure SVG
renderer. Each curve's three plotted values also drive the browser model.
This is a fictional fixed ecosystem. Whether authors can explain delayed
effects and intentionally reproduce a pattern requires a participant trial.

## Verification

[Open the five-slide capture](evidence/compose-worlds/index.html) or inspect
the [scenario manifest](evidence/compose-worlds/manifest.json) for actions,
expected results, browser, scale, and captured revision. All five states passed
in the collaborative preview. For a repeatable interaction check, run
`python3 examples/compose-worlds/browser_check.py` from the repository root
after building, using a Python environment with Playwright and installed Chrome.
It compares the canvas pixels after replay, checks independent trial parameters,
scrubs seasons, exercises a 390-pixel layout and reloads the offline app.

Keyboard slider operation was exercised. Physical assistive technology and
participant comprehension have yet to be tested.
