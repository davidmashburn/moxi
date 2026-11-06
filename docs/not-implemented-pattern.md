# Intentionally unfinished features

`NotImplemented` is an inert component for a feature that the application has
intentionally left unfinished. It shows the feature name, the literal status
“Not implemented yet”, and an optional explanation. All three labels wrap to
the available width. The enclosing view uses normal Moxi overflow handling.

Use the focused, provisional public import:

```mojo
from moxi.component import ComponentSlot
from moxi.geometry import Rect
from moxi.not_implemented import NotImplemented

var export_slot = ComponentSlot(
    NotImplemented("Report export", "This application has no report exporter yet."),
    slot_id=10,
    id_offset=100,
)
var child = export_slot.build(Rect(0.0, 0.0, 360.0, 0.0))
# Inside the host's build, mount at natural content height:
view.add_component_view_to(-1, export_slot.slot_id, child, export_slot.id_offset)
```

The feature name is required; the explanation defaults to an empty string and
is omitted when empty. Build is pure. The inherited component event handler
returns false. The ordinary label/container semantics expose readable text,
no focus stops, and no executable actions. This is neither a progress indicator
nor an error. The visually larger feature label retains the framework's normal
label role.

Give each mounted instance a distinct slot ID and disjoint ID namespace. Build
with the width actually available inside the host, and preserve intrinsic
height or provide normal scrolling when the allocated height is smaller. Host
controls own navigation, documentation links, and replacement with implemented
content. No renderer, platform, or `App` interface changes are needed.

This pattern is not for empty search results, loading, runtime failures, denied
permissions, or unsupported backend capabilities. It does not catch exceptions,
claim a release date, or discover unfinished code. The public lane is
provisional; the focused module and root re-export are inventoried in the API
status files. This additive API needs no migration or compatibility alias.

## Executable example and screenshot recipe

On macOS run `pixi run not-implemented-demo`. The checked-in example uses
`NotImplementedDemo`, the same host mounted by Playground. Alternatively run
`pixi run demo`, find **Not implemented pattern** under Components, and select
**Demo**. Use the standalone example for screenshots without Playground chrome.

Capture the actual Moxi window at each stage, retaining its title bar. The
standalone content area starts at 600 × 620 points. Use the system screenshot
window selector (Shift–Command–4, then Space) or the repository's native capture
workflow. A screenshot alone cannot establish inert behavior: perform the
listed interactions and compare the labels and host count.

1. **Initial:** capture the Counter default variant and Report export explanatory
   variant together. Both say “Not implemented yet”; Host clicks is 0. There is
   no spinner, error indicator, or action inside either informational component.
2. **Interaction:** click each informational label; neither instance changes.
   Activate **Host clicks: 0** to obtain 1. From that focused button, press Tab:
   focus skips both informational instances and reaches **Use implemented
   counter**. Capture the unchanged messages and the changed host count.
3. **Narrow wrapping:** resize the content area to approximately 280 × 620.
   Capture the wrapped explanation. At shorter heights, wheel-scroll to reach
   the bottom host button; the text and recovery control must remain reachable.
   Restore 600 × 620 before the next capture.
4. **Result:** activate **Use implemented counter**, then **Increment**. Capture
   the real counter at 1 beside the unchanged Report export message. This change
   belongs to the host and the implemented counter, not `NotImplemented`.
5. **Recovery:** activate **Restore unfinished counter**. Capture both original
   informational instances with Host clicks still 1. Replacement preserves the
   host's state; the counter retains its value if mounted again. In Playground,
   **Reset** resets this whole demo, including both counts and the replacement
   choice. Navigate to another catalog entry and back to confirm ordinary host
   navigation remains usable.

For a native accessibility check, use VoiceOver to read both feature names,
statuses, and the explanation, then navigate to the surrounding buttons.
Confirm the informational labels announce no action, progress, or error.
Headless semantic tests are separate evidence and do not certify VoiceOver.

## Checks

`tests/not_implemented.mojo` covers focused and root imports, both variants,
deterministic rebuilds, wrapping and scrolling, semantics, inert events, two
independent namespaces, host keyboard input, replacement, and Playground reset.
It runs through `pixi run test`.

Run `pixi run demo-catalog-check`, `pixi run api-status-check`, and
`pixi run check` for the catalog, public API inventories, and repository checks.
Native visual inspection at ordinary/narrow widths and a screen-reader pass
remain distinct from those automated checks.

## Implementation evidence (2026-11-06)

The focused test and the compiled documentation snippet passed. The standalone
native example builds. Offscreen AppKit captures of the real `NotImplementedDemo`
were inspected at 600 × 620 and 280 × 620, including host input, implemented
counter at 1, recovery, and narrow scrolling to the bottom button. A capture of
`DemoBrowserState` also confirms that the same host renders in Playground.
These use Moxi's native draw path; they are not mockups or desktop screenshots.

Local capture artifacts are `/tmp/n01-initial.png`, `/tmp/n01-interaction.png`,
`/tmp/n01-result.png`, `/tmp/n01-recovery.png`, `/tmp/n01-narrow.png`,
`/tmp/n01-narrow-bottom.png`, and `/tmp/n01-playground.png`. The temporary native
probe and event replay are `/tmp/n01-capture.m` and `/tmp/n01-capture.mojo`;
`/tmp/n01-capture-final.log` records their final build/run. The interactive
screenshot recipe above remains the reproducible user-facing acceptance path.

Live desktop automation could not bind the launched application window
(`cgWindowNotFound`); the process did reach the normal AppKit event wait.
Live pointer/keyboard interaction and VoiceOver were not verified. Portable
input and accessibility-tree assertions passed, but do not close those native
acceptance gates. No non-macOS native visual check was performed.

`pixi run test` passed all 89 files. `pixi run demo-catalog-check` and
`pixi run api-status-check` passed. The final test log is
`/tmp/n01-test-final.log`; catalog/API logs are `/tmp/n01-demo-catalog-check.log`
and `/tmp/n01-api-status-check.log`. The native example build log is
`/tmp/n01-build-final.log`, and the documentation snippet result is
`/tmp/n01-doc-import.log`.

`pixi run check` also passed (`Moxi validation passed`), including the repository's
native/backend checks; its full log is `/tmp/n01-check.log`. Expected negative
release-gate fixtures in that log deliberately print failed/skipped subcommands
and are followed by a passing fixture suite. This does not substitute for the
N01-specific live desktop and VoiceOver gates above. The native process sample
is retained at `/tmp/n01-native-sample.log`.
The repository check skipped Android host compilation because the Android
SDK/NDK is absent and iOS host checking because the iPhone simulator SDK is
absent. Those platforms were not verified by this run.

## Reproducible scripted slideshow

The checked-in [capture probe](../experiments/not-implemented-capture/run.sh)
replays actual App events and draws each state through AppKit into a bitmap:

```sh
bash experiments/not-implemented-capture/run.sh > /tmp/moxi-n01-capture.log 2>&1
python3 scripts/demo_slideshows.py --check
python3 scripts/demo_slideshows.py
open artifacts/demo-slideshows/not-implemented/index.html
```

The seven-state [slideshow](../artifacts/demo-slideshows/not-implemented/index.html)
covers the default/explanatory pair, host input, implemented replacement,
restoration, narrow wrapping and scrolling, and Playground. Its manifest records
the base revision and a SHA-256 of the working source, including the private
capture adapter. The adapter includes the actual native drawing implementation;
it introduces no production API. It may need updating when that private backend
changes. These are offscreen renders, not desktop screenshots. The live manual
acceptance recipe above remains open; VoiceOver is paused for this session.

Parent integration verification passed the focused test, API inventories and
27-entry catalog check. Seven fresh scripted renders were inspected. Narrow
panels retain the current label renderer's character wrapping, which can split
words; this component does not add word-boundary typography. The shared gallery
validator passed all four current demo manifests.
