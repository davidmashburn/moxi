# V11 bounded flat/folded editing comparison

The six-panel fixture now supports direct pitch editing from either representation and direct crease tilt editing from the folded surface. Pointer, keyboard and numeric routes update the same patch, preview, comparison and undo history. Pitch is bounded to 10–30 mm in tenths; tilt is bounded to whole degrees from 0–75°. The unfolded sheet exposes pitch; tilt has a geometric handle in the folded view.

This record verifies the bounded implementation. A measured paper sample and a human maker trial remain **open**. No fabrication, material-behavior or usability result is claimed.

## Source and environment

- Public starting point: `aedd058d1ac9605d25a4b0660c93c9220901362f`, verified against the public main reference before the isolated checkout was fast-forwarded.
- Tested implementation: `f8e9aa5e8c1264de28cdbe89180c9f8300808192`. The source was clean at the start of the final capture run; subsequent additions are confined to this evidence directory.
- The planning contract was read from `project-planning` at `59e0be2`: the deferred implementation master and `ideas/v11-patterns-become-structures.md`. No planning or shared ledger was edited.
- [results.json](results.json) records UTC capture time, exact browser version, host, source hashes, generated HTML hash, all eight original evidence hashes, scenario steps, expected/observed results and screenshot descriptions. The revision plus source hashes identifies the tested checkout and build.
- Browser: existing Google Chrome 158.0.8127.37 through local Playwright, headless, offline context, device scale 1. Both 1180 × 900 and 390 × 844 CSS-pixel viewports were exercised. No account or customer data; the built-in six-panel synthetic fixture was reloaded for each scenario.
- Build: Node 26.10.0, Python 3.14.7, Apple Clang 21.0.0 on macOS arm64. Mojo 1.1.0 ran through an already-present Pixi 0.81.0 environment with `--as-is`; no installation or environment update was performed.
- Two consecutive builds produced byte-identical HTML. All geometry samples come from this checkout's Moxi portable orthographic projection core; the browser composes SVG vertices from those samples.

## Observed scenarios

All 20 scenarios passed: nine editor scenarios at each width and the original offline deck at each width. Assertions use mouse, keyboard and form entry points; read-only geometry inspection supplies pointer targets and verifies outcomes. No application state is injected. Screenshots show appearance; assertions establish behavior and undo.

| Scenario, at each width | Steps and expected result | Observed result |
| --- | --- | --- |
| Flat pitch, folded pitch, folded tilt (three scenarios) | Drag each circle; inspect linked preview; apply; undo; enter the same numbers. | Exact linked geometry, inputs and readouts match numeric entry; focus survives redraw; preview creates no history; each commit undoes once. |
| Flat/folded pitch at 75° | From 10 mm / 75°, edit pitch to 24.5 mm in each representation and undo. | Identical patches, including when the narrow sheet readout wraps during the drag. Captured drags retain the initial pointer transform. |
| Keyboard equivalence | Tab to all circles; arrows, Home/End, Enter, undo and Escape; enter 16.1 mm. | All circles reachable, 0.1 mm / 1° steps, clamped endpoints, numeric parity, stable focus and valid decimal acceptance. |
| Cancellation and bounds | Escape during each captured drag, move again, release; use Cancel edit after release; drag beyond both bounds. | Committed patch restored without history; stale motion cannot revive the draft; bounds match keyboard entry. |
| Invalid drafts | Submit empty, out-of-range and excessive-precision values; attempt pointer and keyboard edits with an invalid other parameter. | Draft remains visible with rejection; last valid geometry and history remain intact; Escape restores committed inputs. |
| Per-view picking | Click all six panel centroids in both views at four pitch/tilt endpoint pairs; use panel-control arrows. | All 48 centroid clicks per width select the intended panel in both views (96 total), including tight neighbors at 10 mm / 75°. |
| Measurement and linked undo | Attach/undo measurement during numeric and direct previews; cancel; attach measurement, apply flat pitch, apply folded tilt, undo all three steps. | Drafts and previews survive measurement attachment/undo; shared patch, selection, height and trace remain linked; each undo restores its exact preceding state. |
| Original offline deck | Decode images; use Next, ArrowRight, Previous and thumbnail navigation. | All six original slides decode and navigation works at both widths, offline. |

Every editor scenario also checks that the page has no horizontal overflow. No browser page errors were recorded. The unchanged [original check](../../../../examples/foldable-motif/check.cjs) also passed all 76 samples against the analytic camera and panel constraints, original editing/navigation checks, measurement draft/preview regressions and neighboring-panel picking. See [original-check.log](logs/original-check.log).

Scoped Moxi checks passed using this checkout's unchanged native/Mojo sources:

| Check | Result |
| --- | --- |
| Portable spatial contract and interaction | [1,832 assertions passed](logs/spatial-contract.log). |
| Portable spatial panel | [Passed](logs/spatial-panel.log). |
| Mojo control state | [Passed](logs/control-state.log). |
| Mojo interaction foundation | [Passed](logs/interaction-foundation.log). |
| Mojo form | [Passed](logs/form.log). |

## Current captures

These are full-page captures from the final run. Each capture's action and expected state are in `results.json`.

| State | Wide | Narrow |
| --- | --- | --- |
| Flat pitch preview | [1180 px](1180-flat-pitch-preview.png) | Verified by assertions |
| Folded pitch preview | [1180 px](1180-folded-pitch-preview.png) | Verified by assertions |
| Folded tilt preview | [1180 px](1180-folded-tilt-preview.png) | [390 px](390-folded-tilt-preview.png) |
| Cancelled drag | [1180 px](1180-cancelled.png) | [390 px](390-cancelled.png) |
| Invalid draft | [1180 px](1180-invalid.png) | [390 px](390-invalid.png) |
| Per-view picking | [1180 px](1180-picking.png) | [390 px](390-picking.png) |
| Linked measurement after both view edits | [1180 px](1180-linked-measurement.png) | [390 px](390-linked-measurement.png) |

The [original offline deck](../index.html), six captures and manifest retain their original bytes and historical baseline. They were not regenerated or relabeled as current evidence.

## Rerun

From the repository root, with an existing C++20 compiler, Python, Node, Playwright and Chrome. Set `NODE_PATH` only if the already-installed Playwright package is outside Node's normal lookup path.

```sh
examples/foldable-motif/build.sh /tmp/v11-flat-folded-current.html
examples/foldable-motif/build.sh /tmp/v11-flat-folded-repeat.html
cmp /tmp/v11-flat-folded-current.html /tmp/v11-flat-folded-repeat.html
node examples/foldable-motif/check.cjs /tmp/v11-flat-folded-current.html /tmp/v11-original-check
node examples/foldable-motif/editing-check.cjs /tmp/v11-flat-folded-current.html /tmp/v11-current-evidence
```

The second check writes its scenario record and twelve PNGs to the requested directory and exits nonzero on failure. Reuse a temporary output directory to preserve committed captures.

The scoped Moxi commands were:

```sh
mkdir -p /tmp/v11-flat-folded-scoped
c++ -std=c++20 -O2 -Wall -Wextra -Werror native/spatial/core.cpp tests/spatial/contract.cpp -o /tmp/v11-flat-folded-scoped/spatial-contract
/tmp/v11-flat-folded-scoped/spatial-contract
c++ -std=c++20 -O2 -Wall -Wextra -Werror native/spatial/core.cpp tests/spatial/panel.cpp -o /tmp/v11-flat-folded-scoped/spatial-panel
/tmp/v11-flat-folded-scoped/spatial-panel
```

For the Mojo checks, `MOXI_EXISTING_MANIFEST` names the existing environment's `pixi.toml`. Absolute source/test arguments keep the tests tied to this checkout even when the environment belongs to another local checkout. `--as-is` avoids dependency installation or lockfile changes.

```sh
pixi run --as-is --manifest-path "$MOXI_EXISTING_MANIFEST" mojo run -I "$PWD/src" "$PWD/tests/control_state.mojo"
pixi run --as-is --manifest-path "$MOXI_EXISTING_MANIFEST" mojo run -I "$PWD/src" "$PWD/tests/interaction_foundation.mojo"
pixi run --as-is --manifest-path "$MOXI_EXISTING_MANIFEST" mojo run -I "$PWD/src" "$PWD/tests/form.mojo"
```

## Limits and open work

High confidence in the bounded mechanical comparison for this synthetic fixture and tested Chrome environment, based on exact pointer/numeric state comparisons, cancellation/undo checks, endpoint picking and the existing analytic geometry check. A failing replay on a different browser, actual pointer device or layout would narrow that conclusion.

Paper-sample comparison and human maker prediction/revision trials remain open. Physical thickness, crease placement, fabrication, free-form notation, arbitrary joint dragging, saved-document persistence, touch-device gestures, operating-system capture loss, other browsers, native platform backends, the full Moxi suite, performance, VoiceOver and independent accessibility/usability were not tested. Reload resets the fixture; no persistence is implemented or claimed.

A supplementary local browser-preview exercise observed keyboard apply/cancel at both widths. Its narrow screenshot capture timed out; it is not used as final capture evidence. The offline Chrome interaction checks and narrow PNGs above completed against the tested source. No other agents, remote/shared writes or system installations were used.
