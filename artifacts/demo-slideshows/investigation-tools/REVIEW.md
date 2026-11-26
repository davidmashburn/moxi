# I10 native consumer verification

The bounded experiment is runnable: named cohort → explicit fit and residuals → alternatives → saved fixed panel → fresh-process reopen.

Captured 2026-11-26T03:41:14.234146+00:00 on macOS 27.2.1 (arm64). Source commit: `f0682a1828d85d1bd2a301bc11be331447216795`. Source changes at capture: `clean`.

The build compiles this checkout's Moxi source and AppKit host using the locked Pixi environment. Compiler versions and linker warnings are retained in [build.log](logs/build.log). The exact executable hash, source hashes and PNG hashes are in [manifest.json](manifest.json). The no-argument executable first creates its normal App, component and native window; the optional replay then supplies mouse, text, F2 and resize callbacks through the same dispatch/render functions as interactive use. It reads state for assertions and never mutates the model directly.

Environment: local synthetic fixture with eight stable observation IDs, no external account; native AppKit window at 1140×860 and 980×800 points, 2× capture backing scale. This is native UI verification; no browser hosts the consumer.

## Scenarios

Each row passed its interaction assertions and produced the linked native-window PNG. Appearance is evidence from the capture; numeric/persistence claims also have assertions and independent saved-file checks.

| Scenario | Steps | Expected / observed | Outcome / evidence |
|---|---|---|---|
| Normal native entry | Launch investigation with no arguments. | Fresh sensor workbench; no cohort or fitted model. | PASS · [PNG](01-entry.png) |
| Name, collect and fit | Edit name and hypothesis, click Collect, then Fit linear. | I20 collects six stable IDs; slope 16, SSE 149.333 and signed residuals. | PASS · [PNG](02-linear.png) |
| Rejected numeric edit | Enter oops for c0 and click Apply coefficients. | Visible error; the previous model and residuals remain intact. | PASS · [PNG](03-invalid-coefficient.png) |
| Compare identical observations | Click Compare alternatives and resize to 980 by 800 points. | Mean, linear and quadratic list parameter counts and training SSE on the same cohort; all remain above status. | PASS · [PNG](04-alternatives.png) |
| Choose another explicit model | Click Fit quadratic. | Coefficients 68, -2, 2 and zero residuals on the synthetic cohort. | PASS · [PNG](05-quadratic.png) |
| Edit the model | Enter c0=69, verify Save refuses the pending edit, then Apply coefficients. | Six residuals of -1; SSE 6. The alternatives remain separately fitted. | PASS · [PNG](06-edited.png) |
| Filter and reorder | Filter the table to >=70 and reverse its order. | Membership, coefficients and fitted data remain unchanged. | PASS · [PNG](07-stable-ids.png) |
| Frozen membership | Toggle reading 207 from 58 to 76. | 207 becomes visible but stays outside the frozen cohort; the old fit is invalidated. | PASS · [PNG](08-frozen.png) |
| Live membership | Switch membership to live and fit quadratic. | 207 enters the cohort through I20; the fit and residuals use seven observations. | PASS · [PNG](09-live.png) |
| Extract and save a fixed panel | Restore baseline readings, freeze IDs, fit quadratic, apply c0=69, then Save fixed panel. | Compact panel records cohort, provenance, target, coefficients, refit and coefficient controls. | PASS · [PNG](10-saved-panel.png) |
| Narrow native layout | Resize the actual window to 980 by 800 points. | Saved panel and its controls remain visible and clickable. | PASS · [PNG](11-narrow-panel.png) |
| Reopen and inspect internals | Refit at the narrow size, Reopen the saved panel, Open investigation internals, focus the table filter button, then press F2. | Saved c0=69 is restored first; F2 outside text editing re-collects the same stable IDs and invalidates the old fit. | PASS · [PNG](12-internals.png) |
| Reopen in a new process | Launch the same no-argument executable again and click Reopen panel. | Name, hypothesis, frozen IDs, fixture, quadratic model and edited c0=69 survive process exit. | PASS · [PNG](13-new-process-reopen.png) |
| Saved refit control | Click Refit quadratic in the reopened panel. | The intended six sensor observations produce 68, -2, 2 and zero residuals. | PASS · [PNG](14-panel-refit.png) |
| Saved coefficient control | Change c1 to -1 and click Apply coefficients. | The intended observations produce SSE 139; this edit is unsaved. | PASS · [PNG](15-panel-edit.png) |
| Reject an incompatible panel | In a fresh workbench fit linear, then Reopen an unsupported panel version. | The error is visible and the current investigation is unchanged. | PASS · [PNG](16-load-rejected.png) |
| Preserve state after a save failure | Fit linear and Save where panel.json is a directory. | Atomic write fails visibly; the investigation and existing destination survive. | PASS · [PNG](17-save-rejected.png) |

## Additional checks

- [Domain checks](logs/domain.log): known OLS coefficients, signed residuals, mean/linear/quadratic SSE, edited coefficients, typed Unicode round-trip, inclusive threshold, frozen/live behavior, insufficient samples, and transactional failed refreshes.
- [Panel boundary checks](logs/boundary.log): 31 malformed or incompatible configurations rejected; reordered fields, escaped Unicode and a consistent live rule accepted.
- Five separate native processes: create, fresh reopen, incompatible load, [missing file](logs/missing.log), and failed atomic save. The failed save leaves the existing destination directory intact; file-load failures preserve the current model.
- [saved-panel.json](saved-panel.json) independently records the six intended IDs, quadratic coefficients with c0=69, stable sensor target and two supported controls.

## Reproduce

```sh
python3 examples/investigation-tools/check.py
```

Run from the repository root on macOS. Set `MOXI_PIXI_MANIFEST` only when reusing a matching installed locked environment. Open [index.html](index.html) for the offline 17-frame slideshow. PNGs and HTML follow the repository's generated-artifact ignore convention and are regenerated by this command; the manifest, saved configuration, source and short logs remain reviewable.

## Limits

Confidence is high for this bounded synthetic flow. A failing replay or a mismatch between captured source hashes and the proposed source would change that assessment. Physical input, human repeated use, other operating systems, VoiceOver and the full repository suite were not tested. Native callbacks do not establish physical IME or assistive-technology behavior. F2 was exercised with focus outside text editing. No scientific validity or generalization is claimed. The original workbench is not extended with general extraction, symbolic editing, canvas or 3D authoring. Shared ledger and index changes are left to the parent.
