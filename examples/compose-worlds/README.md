# Compose Worlds

Build the offline browser app from the repository root with
`python3 examples/compose-worlds/build.py`, then open
`dist/compose-worlds/index.html`. Run the model checks with
`node examples/compose-worlds/check.mjs`.

Predict the grazer density relative to the reference bed at season 12. Change
the midpoint of the branch feeding curve, then run the comparison. Scrub the
season slider to inspect when the beds diverge. Reset restores the original
rule and both initial maps. Each history row restores its branch, prediction, shared and local midpoints,
and promotion undo stack, then reruns season 12 from the same seed. History lasts for the current page session.

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

## Branches and promotion (I04)

North, East and South start with the reference midpoint of 50%. Move the
shared slider and inspect each branch. Editing the branch slider pins a local
value, even when it equals the shared value. **Use shared** resumes inheritance.

For a three-way comparison, set North to 0%, East to 100% and the shared
midpoint to 70%. South follows the shared input. Promote East, then run a
comparison. East and South now inherit 100%, North still uses 0%, and the
reference uses 100%. Undo restores 70% and both override assignments.
Switching branches, running comparisons and inspecting seasons preserve the
promotion stack. A new midpoint edit starts a new undo sequence.
Reset restores the initial settings and keeps every recorded trial.

## Formula and definition (I06)

Focus the grazing chart and press Enter. The editor selects the midpoint in
`knots(0, 50, 100)`. Type a new midpoint or select text in either direction.
Tab past **Apply formula** to **Knot definition** and press Enter. Activate
**Return to formula** or press Escape to resume at the same selection. Apply
the draft to update the branch curve, then run a comparison. The endpoints
are fixed. The midpoint accepts multiples of ten from 0 to 100.

## Verification

From the repository root, run:

```sh
node examples/compose-worlds/check.mjs
python3 examples/compose-worlds/browser_check.py
```

The browser command requires Python Playwright and installed Chrome. It builds
the app, opens the local file offline at 1180 × 1050 and 390 × 844, and
exercises both scenarios and the original trial flow at each size. It records
all 13 seasons for each of the 11 midpoints and checks the canvas hashes and
result text when replaying the rows out of order. The formula checks cover a
collapsed caret and forward and backward selections after typing.

Use `--capture` on committed source to regenerate the [offline slideshow](evidence/compose-worlds/index.html)
and [capture manifest](evidence/compose-worlds/manifest.json). The automated
checks use synthetic keyboard input. Participant comprehension, physical
assistive technology and other browser engines remain unverified.
