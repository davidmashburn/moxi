# Folding lamp

Tune a spring-loaded arm by hand, then compare its response with a bounded inverse search. From the repository root, build the workbench with the local Moxi Python package and open the resulting file in a browser.

```sh
PYTHONPATH=python python3 examples/spring-linkage/build.py /tmp/folding-lamp.html
open /tmp/folding-lamp.html  # macOS
```

The file works offline. The pose slider moves the arm through thirteen angles from 15° to 75°. The plot cursor follows the tip along the dashed trajectory. Edit either dimension by typing or nudging the number field and applying it. Escape discards a draft. Reload starts a fresh session.

## Model and inverse search

The synthetic fixture has one moving rigid bar with length *L*, a pivot fixed at the origin, a spring anchor at (0, −*h*), and a spring attached at radius *r* = *L*/2. At angle θ the spring length is *s* = hypot(*r* cos θ, *r* sin θ + *h*). Spring tension is 0.12 max(0, *s* − 35) N for lengths in mm. Balancing moments about the pivot gives the tangential tip force required to hold the arm, *F* = tension × *r h* cos θ / (*s L*). The arm has no mass, friction, gravity load or damping in this model.

Moxi's public PlotSpec and plot APIs project the computed samples to SVG coordinates. All response and target curves share the same angle and force scale. The synthetic light and firm target curves come from grid designs. High load requests a flat 4.8 N. The sweep evaluates every combination of seven arm lengths (80–140 mm) and six anchor depths (30–80 mm) at 10 mm spacing, scoring the RMS difference over all thirteen poses. It shows up to three candidates within 0.16 N RMS, ordered by error. Equal scores retain grid order. Select a candidate to preview the arm, spring, trajectory and force together. Use preview commits it. Target edits and dimension commits share undo history. Editing the draft clears existing proposals.

## Reproducible checks

With Python Playwright and Google Chrome already available locally, run the following from the repository root. Building and using the demo requires neither Playwright nor a server.

```sh
PYTHONPATH=python python3 examples/spring-linkage/check.py
```

The check rebuilds the HTML from this checkout, opens its file URL in an offline Chrome context, and regenerates the six PNGs, manifest and [standalone slideshow](../../artifacts/demo-slideshows/v04-spring-linkage/index.html). The slideshow supports previous/next, arrow keys and a thumbnail view. The [capture manifest](../../artifacts/demo-slideshows/v04-spring-linkage/manifest.json) records source revision, time, browser, viewport, action and expected observation. The recorded source was committed and clean during capture.

| Scenario | Action and observed result |
| --- | --- |
| V04 hand tuning | Increasing the anchor from 40 to 50 mm lowered firm-target error from 0.752 to 0.424 N RMS. |
| V04 / I03 alternatives | The best of 42 pairs matched exactly. Previewing the second (130 / 60 mm) gave 0.034 N RMS. Escape restored the hand-tuned geometry and response. Applying the same preview committed both dimensions. |
| V04 / I03 rejection | Switching to High load and sweeping yielded zero matches. The committed geometry and response stayed identical. Undo restored the prior target and another undo restored the hand-tuned pair. |
| I21 linked editing | Keyboard pose changes moved the tip and restored its exact SVG coordinates on return. Pointer selection changed the preview. An off-grid 85 mm draft failed browser validation. Escape restored the committed text. A new dimension draft cleared earlier alternatives. |
| Narrow layout | At 390 × 844 CSS pixels, the page fit the viewport width and dimension apply/undo restored the previous geometry and curve. |
| Numerical check | All 546 model samples agreed with an independent central difference of spring energy per unit tip travel within relative tolerance 1e−8. |

## Evidence boundaries

This covers V04's bounded search, I03's pinned pivot and selectable/cancellable alternatives, and I21's one-degree-of-freedom trace, numeric edits, cancellation and shared undo. The search is synchronous. Asynchronous stale-result races, arbitrary drawn target curves, dragging an endpoint, equation editing and general text-to-layout round trips remain open. The comparison measures model error. Whether people can select a useful branch or explain why a target failed requires a human session. Force measurements, material response, settling dynamics and fabrication tolerances require external physical evidence. Browser replay supplies no native-host, assistive-technology or hardware-input acceptance.
