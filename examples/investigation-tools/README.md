# I10 · An investigation becomes a tool

Run a native Moxi sensor workbench, name a cohort, fit an explicit model, inspect
signed residuals, compare alternatives, then save and reopen a fixed panel.
This is the bounded I10 experiment from the deferred implementation master,
implemented on public `bbf8b25`. It reuses I20's `Notebook`, registered
`observations.collect_high.v1` operation, capability policy and native replay
helpers; the shared operation's source is preserved.

## Run

On macOS with the repository's pinned Pixi environment:

```sh
bash examples/investigation-tools/build.sh
dist/investigation-tools/investigation
```

The executable takes no arguments. Its normal entry point opens the actual
`InvestigationScreen` Moxi component, AppKit host and `moxi_plot` plots. The panel
path initially names `panel.json` in the working directory. Change it before
saving if needed. All data is a local eight-observation synthetic fixture; no
network service or external account is used.

1. Edit the cohort name and hypothesis. Click **Collect >= 70** or press **F2**
   with focus outside a text field.
   Both use I20's operation over stable observation IDs. Choose **frozen** IDs or
   a **live** inclusive reading rule.
2. Fit a mean, linear or quadratic polynomial by least squares. Inspect the
   observed/model plot, residual plot and per-observation residuals. Residuals are
   observed minus predicted. Edit c0, c1 and c2, then **Apply coefficients**.
   Linear requires c2=0; mean requires c1=c2=0.
   The equation and metrics round to three decimal places for reading; coefficient
   fields and saved values retain full precision. Successful Apply and Save use
   the round-trippable Float64 spelling, removing accepted whitespace padding.
   Focused coefficient editors scroll horizontally to their selected text,
   including numbers entered with long whitespace padding.
   Each coefficient has its own
   labeled editor so its full Float64 value fits at the 980×800 minimum size.
3. **Compare alternatives** lists parameter counts and training SSE for the same
   cohort. Selecting another fit replaces the active model. Editing coefficients
   recomputes active residuals; the independently fitted alternatives stay separate.
4. Filter or reorder the table: neither changes cohort IDs or the fitted data.
   Toggle observation 207 across the threshold to see frozen and live semantics.
   Data or membership changes invalidate the previous fit rather than showing stale
   residuals. Fit again before saving.
5. **Save fixed panel** atomically writes a versioned declarative configuration
   and opens the compact panel. **Reopen panel** restores it from disk, including
   in a new process. Its refit and coefficient controls target the same cohort
   and sensor reading. **Open investigation internals** returns to the workbench.

The panel saves its fixture identity and state, observation IDs, membership mode,
fixed rule, name, hypothesis, explicit model and coefficients, stable target and
the two supported operations. It serializes no view IDs, live components, closures,
native handles, caches or arbitrary code. Unapplied numeric edits block saving.
Invalid, incompatible or missing files leave the current investigation intact;
failed atomic writes leave the existing destination intact.

## Reproduce and inspect

```sh
python3 examples/investigation-tools/check.py
```

To reuse a matching installed environment, set `MOXI_PIXI_MANIFEST` to its
`pixi.toml`. The build still compiles the Mojo, Moxi source and native host in this
checkout. To keep draft captures outside tracked source, pass `--dest /tmp/moxi-i10`.

The check builds both executables; tests known OLS coefficients, residual signs,
training errors, edits, live/frozen semantics, Unicode persistence and the
inclusive boundary; checks malformed and unsupported JSON configurations; then
launches the normal executable in five separate processes. The replay adapter
supplies AppKit mouse, text, key and resize callbacks. It performs no direct
mutation of the investigation model. Interaction assertions and independent
saved-file checks establish behavior; screenshots establish recorded appearance.

The [offline slideshow](../../artifacts/demo-slideshows/investigation-tools/index.html),
[capture manifest](../../artifacts/demo-slideshows/investigation-tools/manifest.json)
and [verification record](../../artifacts/demo-slideshows/investigation-tools/REVIEW.md)
retain steps, expectations, observed outcomes, source hashes, executable hash,
capture time, native environment, viewport sizes and the exact reproduction command.
The published walkthrough includes the original seventeen PNGs, offline HTML, short replay logs and saved JSON configuration. A second build of the integrated consumer reproduced all seventeen PNGs byte for byte.

Saved panels wrap the full accepted name and hypothesis, with membership mode
on its own line. Their height follows the native painter's line-fragment layout
with the actual font and column width, including fallback fonts and Unicode line
separators. Text taller than the column remains reachable with its native scrollbar.
The workbench keeps its normal single-line native editors and end navigation.

The scoped layout regression additionally exercises negative and scientific
notation in all three editors, native last-digit navigation/deletion/insertion,
no-op Apply without precision loss, invalid and pending edits, saving and
fresh-process reopening at 980×800 and 1140×860. It also saves and reopens the
accepted 64-character name and 140-character hypothesis and checks both frozen
and live mode remain independently visible:

```sh
python3 examples/investigation-tools/check_layout.py --dest /tmp/moxi-i10-layout
```

It retains native PNGs, source and executable hashes, exact saved JSON and short
assertion logs. The [layout verification](../../artifacts/demo-slideshows/investigation-tools/long-coefficients/REVIEW.md)
records the original clipping and the repaired layout.

The Unicode paint regression runs the same executable in four processes: create
and fresh reopen for frozen and live membership, at both supported sizes. It
compares the actual native label painter's complete raster with a tall reference,
with a deliberately shortened frame as a negative control. The checks include
63/139 `😀` followed by `Z`, maximum ASCII and CJK runs, Unicode line separators,
combining marks, mixed RTL text and emoji sequences, and an empty hypothesis.
They also check actual foreground pixels while editing a whitespace-padded
coefficient, native End/delete/reinsert, Apply, scrolling, and exact saved JSON:

```sh
python3 examples/investigation-tools/check_unicode.py --dest /tmp/moxi-i10-unicode
```

The output directory retains native captures, assertion logs, source/executable
hashes and each membership mode's saved panel. This is representative Unicode
coverage, not an exhaustive test of every accepted sequence or font/scale.

## Scope and limits

This delivers the staged cohort → explicit fit/residuals → alternatives → fixed
panel experiment. It is a separate consumer using existing Moxi workbench/plot
and I20 mechanisms. It does not add arbitrary import, an editable symbolic model,
a canvas/3D specimen link, or general panel authoring to the original data workbench.
The known synthetic curve is a numerical regression fixture. A better training
fit does not establish a scientific explanation, causation, or generalization.

Verification covers normal entry-point callbacks and actual local persistence,
including fresh-process reopen and failed file operations. Physical mouse/keyboard,
human repeated use, other operating systems, VoiceOver and the full repository
suite are outside this check. The parent owns the shared delivery ledger and index.
