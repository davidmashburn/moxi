# Formula Editor and Fractal Explorer

Formula Editor opened with 45 buttons above an empty expression. Grouping commands behind Insert, Structure, Symbols, Document and Compute leaves six buttons on entry, including the text-editing switch. At 1180 × 820 pt the formula canvas now starts at 132 pt instead of 282 pt and has 548 pt of height instead of 313 pt. At 850 × 620 pt it gains the same 235 pt.

Fractal Explorer opened on a Koch curve with all 27 preset buttons below the drawing. The new Presets control names the current curve beside the depth controls. It opens one family at a time and closes when a preset is chosen. Four buttons and the depth field are visible on entry. The standalone drawing starts 62 pt higher. Inside the narrow Playground, both endpoints of the initial curve now fit beside the sidebar.

## Compare the same states

| View | Before | After |
| --- | --- | --- |
| Formula Editor, same radical containing a fraction and scripts | [Original workbench](before-formula-expression.png) | [Larger expression canvas](after-formula-expression.png) |
| Formula Editor on launch | [Original](before-formula.png) | [Revised](after-formula.png) |
| Formula Editor, 850 × 620 pt | [Original](before-formula-narrow.png) | [More room for the expression](after-formula-narrow.png) |
| Fractal Explorer, Koch Curve at depth 5 | [Original](before-fractal.png) | [Preset and depth above the drawing](after-fractal.png) |
| Fractal Explorer, 850 × 620 pt | [Original](before-fractal-narrow.png) | [Revised](after-fractal-narrow.png) |
| Fractal inside the Playground | [Original preview](before-playground.png) | [Revised preview](after-playground.png) |
| Fractal inside the Playground, 850 × 620 pt | [Original framing](before-playground-narrow.png) | [Both endpoints visible](after-playground-narrow.png) |

## Design rubric

The visitor should be able to compose and revise an expression, or choose and reshape a curve while watching it render. Opening the real demo and completing its first action are gates. Both passed after the changes. The [rubric](../../../.agents/skills/review-demo-design/SKILL.md) scores observed blockers at 0, repeated interference at 1, localized friction at 2 and a pass in the tested states at 3.

| Criterion | Formula Editor · before → after | Fractal Explorer · before → after |
| --- | --- | --- |
| Hierarchy | Document, compute and insertion commands competed with the expression. The canvas now follows two short rows even in the compact view. **1 → 3** | Trying the next curve required leaving the canvas. The current preset and depth are now directly above it. **1 → 3** |
| Legibility | The expression itself was readable. Narrow controls crowded the labels. Group names and the active block are readable at both sizes. **2 → 3** | The curve was readable, but the current preset was hard to identify. Its name stays visible with the chooser closed and the selected item is marked when open. **2 → 3** |
| Layout | Tool rows consumed most of the narrow window. The editor now has 348 pt for the formula at that size. **1 → 3** | The original narrow Playground cropped the right handle. The initial generator now fits horizontally. The fixed-resolution native artboard still requires vertical scrolling to reach the material beneath it. **1 → 2** |
| Interaction | Commands were individually visible but hard to scan. Inserting a fraction, finding π and switching blocks all worked through their groups. Native keyboard focus across every disclosure remains untested. **2 → 2** | Presets and canvas were far apart. Selecting a curve returns to the drawing. Browser keyboard selection, depth recovery and reset passed, as did a native drag in the narrow pane. Native keyboard-only navigation remains untested. **2 → 2** |

## Verification

Tested the parent revision `6639b77` and the revised source in this commit on 2026-11-28 UTC. Native captures use 2× backing resolution on macOS 27.2.1 (Apple Silicon, Mojo 1.1.0). Default window content sizes were 1180 × 820 pt for Formula Editor, 1180 × 900 pt for Fractal Explorer and 1180 × 760 pt for the Playground. Each also has a matched 850 × 620 pt capture. Browser checks used Chrome 158 at 1280 × 850 and 390 × 844 CSS pixels, with the local Wasm build served at `127.0.0.1:18935/experiments/fractal-web/`.

| Scenario | Expected and observed result | Outcome |
| --- | --- | --- |
| Search for Formula Editor in the Playground and launch it | The real workbench opened, completed its 12-step replay and returned control to the launcher. [Launch state](launch-formula.png) | Pass |
| Open Insert and choose Fraction, search Symbols for pi, then switch between Scratch and Expression | Fraction insertion updated the expression, search found π, and block switching selected the requested block. Insert also opened at 520 × 680 pt. [Open Insert group](formula-insert.png) | Pass |
| Replay structural editing, a bad source edit, undo, asynchronous results and save/reopen | Native acceptance and all 12 workbench steps passed, including stale-result rejection and persistence. The math checks ran with SymPy available. [Replayed expression](after-formula-expression.png) | Pass |
| Open Presets, change family and preset, increase depth and enable colors | The chooser showed one family and selection returned to the canvas. The standalone app rendered the chosen preset. [Open chooser](fractal-presets.png) · [Kite Spine at depth 6](fractal-edited.png) | Pass |
| Drag the displayed Koch handle beside the Playground sidebar at 850 × 620 pt | The handle moved to the pointer and the curve redrew. Regression coverage also checks that an eight-point pointer move changes the model point by eight. [After drag](playground-drag.png) | Pass |
| In Chrome, choose a preset with Enter, drag, reset, submit an invalid depth and open the chooser on mobile | The curve changed during the drag, reset restored its pixels, and invalid depth recovered. The mobile page stayed within the viewport with the chooser open and closed. A missing Wasm build produced the expected error state. [Mobile browser](fractal-web-mobile.png) | Pass |

The Playground and standalone fractal builds, demo-browser and fractal tests, fractal numerics and native/Wasm pixel comparisons passed. Standalone native screenshots use the AppKit fallback to capture the complete drawing. A separate run with the default Metal layer confirmed depth changes, render completion and preset switching. GPU-composited pixels, VoiceOver, physical-keyboard traversal, historical timing benchmarks and the full repository suite were outside this verification run.

The earlier reviews cover the [main Playground and its first four examples](../playground/REVIEW.md) and the [two browser explorers](../browser-explorers/REVIEW.md).
