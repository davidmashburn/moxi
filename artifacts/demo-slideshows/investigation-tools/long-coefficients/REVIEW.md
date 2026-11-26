# Investigation layout verification

The change gives each full-precision coefficient a labeled editor and wraps saved
metadata using the native font's measured height. Membership mode has its own
line. Saved-panel spacing keeps the observation table inside its column; the
plots retain a nonzero data area and separate endpoint labels.

Source baseline: `17dc619ee4215709876792a307e3fde538cad5b3`. The implementation
was tested as a local patch on that revision. [Source and executable hashes](manifest.json)
identify the tested files; the local delivery commit records that exact source.
No model, parser, serialization, shared native host or toolkit source changed.

The I10 independent review supplied with this task reported a 64-character name
hiding membership mode and a 140-character hypothesis clipping at 980×800.
This record independently reproduces that case with 64 and 140 `W` characters.
Only synthetic sensor data and local panel files were used.

Environment: macOS 27.2.1, arm64, AppKit NSWindow, 2× backing scale; Mojo 1.1.0
(`8189361e`) and Apple clang 21.0.0. Sizes below are native **content points**:
980×800 (the configured minimum) and 1140×860 (the normal larger size).
The build reused an installed Pixi environment with the identical repository lock
hash. It emitted existing macOS deployment-target linker warnings.

Verification launches the normal native executable and component, then supplies
AppKit mouse and text-input callbacks, including end navigation, deletion and
insertion through the window's first responder. Events use the normal dispatch,
hit testing, rendering and local save/load paths. Captures come from the actual
native view. This is callback-driven native verification, without physical input.

| Scenario and steps | Expected result | Observed result |
| --- | --- | --- |
| Baseline: collect six observations, fit linear, compare, resize to both sizes. Then edit a negative intercept and scientific-notation c2; save maximum metadata in frozen and live modes. | Reproduce the reported defects without changing domain data. | Reproduced. Linear c0 needs 173.99 points but receives 150.67 at minimum. Edited c0/c2 also clip at 1140×860. Name and hypothesis clip and the combined mode disappears. The negative regression fails its final fit assertion as expected. |
| Changed layout: collect, fit, compare and resize to both sizes. | All coefficient text fits; controls, plots and alternatives remain usable. | Pass. Editors provide 430/510 points; the longest tested value needs 222.80. Both plots retain separate endpoint labels; alternatives fit inside the column. |
| At minimum, enter invalid c2; enter all three long valid values; use end/delete/insert on c1 and the hypothesis; attempt Save before Apply. Apply, then no-op Apply at larger size. | Invalid/pending edits preserve the fit and reject Save; valid values remain exact and editable. | Pass. Invalid Apply and pending Save preserve the model. Native text edits and exact no-op Apply checks pass. |
| Save 64-character name and 140-character hypothesis, first frozen then live. Resize each saved state to both sizes; refit and reopen from disk. | Full metadata and separate mode remain visible; coefficients and stable membership survive; all eight table rows remain inside the column. | Pass before and after reopening each mode at both sizes. Every native glyph fits. At minimum the final table row ends at 698 points, inside the column ending at 706. |
| Exit and launch a fresh native process; reopen, resize to both sizes, no-op Apply, refit and reopen again. | Restore exact metadata and coefficients; refit still targets the same six observations. | Pass. Live mode, full metadata, all three exact coefficients and six IDs restore from disk; refit and repeated reopen pass. |
| Existing example regression: domain tests, parser rejection cases and normal native save/reopen/failure flows. | Preserve existing behavior. | Pass: domain tests, 31 rejected boundary cases, five native processes and seventeen native captures. |

The edited coefficient values are `-33.333333333333336`, `16.123456789012344`
and `-1.2345678901234567e-123`. The regression checks exact Float64 equality and
independently checks the actual [saved JSON](saved-panel.json), including all
metadata, mode and stable observation IDs. No-op Apply must preserve serialized
values. The equation and metrics continue their existing display-only rounding.

Before captures use the unchanged baseline `screen.mojo`, model and persistence
code with native test adapters added in a temporary source overlay. The
[baseline manifest](before-manifest.json) identifies those sources and executable;
the [negative native log](before-native.log) and [fresh-reopen log](before-reopen.log)
preserve the failed fit checks.
This overlay enabled the same long-value scenario without changing the baseline
component's rendering or behavior. Both maximum-metadata before captures show
the live panel reopened in a separate process, matching the after captures.

| Native appearance | Before | After |
| --- | --- | --- |
| Linear fit and alternatives, 980×800 | [Clipped c0](before-linear-min.png) | [Full c0 and separated plots](after-linear-min.png) |
| Maximum metadata and edited coefficients, 980×800 | [Clipped metadata and hidden mode](before-metadata-min.png) | [Frozen saved panel](after-frozen-min.png), [fresh-process live reopen](after-reopened-min.png) |
| Maximum metadata and edited coefficients, 1140×860 | [Still clipped](before-metadata-large.png) | [Fresh-process live reopen](after-reopened-large.png) |

Reproduce from the implementation checkout:

```sh
python3 examples/investigation-tools/check_layout.py --dest /tmp/moxi-i10-layout
python3 examples/investigation-tools/check.py --dest /tmp/moxi-i10-existing
```

The scoped command builds and retains ten PNGs across two native processes.
This directory retains seven before/after images plus short [layout](native-layout.log)
and [existing-regression](existing-regression.log) logs,
saved JSON and hashes. The existing regression retains seventeen captures in its
requested temporary destination. Capture times and file hashes are in the
manifest. Screenshots support appearance claims; event assertions and disk reads
establish editing and persistence.

Not verified: physical mouse/keyboard interaction, VoiceOver (excluded by request),
other OS hosts, other font/scale configurations, or the full repository suite.
Confidence in the reported fix is high for the tested native environment;
different font metrics or scale-dependent rendering would warrant another native
run. No push or shared-system action was performed.
