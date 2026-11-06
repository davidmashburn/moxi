# Native math editor: D02 implementation evidence

This is a local implementation candidate for M0–M4, based on `df1eff8` with
D01 and F01 integrated. It is not a declaration that every release gate has
passed. The implementation and reproduction instructions are in
[math-editor.md](math-editor.md). D01's persistent SymPy choice remains
provisional, with moderate confidence; its report is unchanged.

## Reference environment and confidence

Measurements were made on 2026-11-06 on macOS 27.0.1 (26A434), arm64,
Mac16,13 / Apple M4, 32 GiB. Dependencies: locked Mojo 1.1.0 and
canvas_mojo 0.42.0, HarfBuzz 14.5.0, STIX Two Math 2.13b171, optional
SymPy 1.14.0 and mpmath 1.3.0. Native rendering uses AppKit/CoreText and the
font's actual HarfBuzz MATH tables, variants, assemblies and glyph metrics.

Confidence is high in the covered model/geometry/lifecycle contracts and
moderate in interaction readiness. Physical keyboard/IME trials, compositor
captures, broader notation review and an independent consumer host could
change the latter assessment. Synthetic native events and content-view PNGs
do not establish physical usability, screen-reader announcements or display
latency.

## Executable coverage

`bash scripts/math/check.sh` builds both real native applications and runs:

| Check | Evidence covered |
| --- | --- |
| `tests/math/model.mojo` | Every notation family, holes, quoted Unicode/error spelling, canonical round trips, unchanged sibling identities after insertion, token/NUL limits |
| `tests/math/editor.mojo` | Fraction/scripts/matrix editing, shared text/visual history, malformed-text recovery, source-span selection, grapheme deletion, symbol entry, clipboard fresh IDs, one-transaction moves, rejected descendants, cancellation, monotonic reopen revisions, stale/malformed result rejection, key remapping, paired slots, rejected text rollback |
| `tests/math/geometry.mojo` | Real font measurement; nested fractions/radicals, scripts, tall delimiters, matrices, sums/integrals; 16–64 pt; glyph ink containment within 1 pt; caret self-hit; no remeasurement of unchanged layout; unaffected subtree cache reuse |
| `tests/math/native_acceptance.mojo` and `native_probe.m` | Actual App/window/view; AppKit NSEvent interpretation, structural keyboard chords, marked Unicode text and commit, no structural mutation during preedit, current candidate rectangle, semantic labels/bounds, native structured clipboard with saved/restored pasteboard, transformed/scrolled hits at 480 pt and 0.5–2× zoom |
| `tests/math/backend_test.py` | Actual persistent SymPy expansion/differentiation, process reuse, target identity, source revision, ancestor binder rejection, unsupported/incomplete notation, stale/closed/superseded requests, ready-to-stale transition without reimporting edited results, cancellation/restart, absent worker, deadline, corrupt transport and grouping in imported results |
| `tests/math/performance.mojo` | Full App CPU edit path, continuous widths, distinct edits, no math remeasurement for caret-only updates, large rows/matrix/deep nesting |

The backend tests exercise real processes; selected notation is projected rather
than passed through `eval`. Unsupported ancestor sums/integrals are rejected
before submission. The editor-only consumer imports no Python backend.

The capture replay delays real SymPy worker startup by three seconds, checks
that it is still pending, edits the denominator while its selected numerator is
in flight, rejects Apply, then waits for the stale completion and resubmits.
The worker subsequently remains persistent. This demonstrates that the actual
host can edit during pending computation; it does not measure physical latency.

## CPU benchmark

The benchmark records five warmups followed by 60 edits. Each edit uses a
distinct replacement token and continuously varying width. The timed region
includes selection, event routing, mutation/history, App rebuild, geometry,
paint-command generation and native scene publication. It excludes display
presentation and worker computation. Cold time is App construction plus first
geometry publication, after the font session opens; it is not process startup.
There is no claim that the view-cache capture measures frame delivery.

The isolated rerun (no concurrent D02 build) produced these values, in ms:

| Fixture | Nodes | Cold | p95 | p99 / worst | Measurements over 65 edits | Retained cache entries |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Row | 100 | 2.520 | 0.989 | 1.598 | 130 | 132 |
| Row | 1,000 | 4.023 | 6.414 | 19.102 | 130 | 132 |
| Row | 10,000 | 28.840 | 43.768 | 56.393 | 130 | 132 |
| 20×20 matrix | 421 | 1.257 | 1.650 | 1.781 | 195 | 198 |
| Depth-60 fractions | 121 | 2.281 | 2.493 | 2.833 | 3,965 | 4,027 |

All cases generated 44 host paint commands, plus respectively 101, 1,001,
10,001, 454 and 63 math glyph placements. The isolated process used 156.6 MiB
maximum RSS and 147.0 MiB peak memory footprint (`/usr/bin/time -l`), including
all five cases and retained histories. These are process totals, not a leak or
per-allocation measurement. The suite run's 1,000-node p95 was 3.848 ms; the
isolated run's 19.102 ms outlier and variation preclude claiming every frame
meets a 60 Hz budget even though the proposed p95 CPU target is met.

The proposed p95 CPU target is 8 ms at up to 1,000 nodes. A 10,000-node row is a
stress case, with visibly higher whole-document serialization/history and scene
cost despite subtree measurement reuse. The model enforces 20,000 nodes, depth
64, 1 MiB canonical text, 4,096-byte tokens and 100×100 matrices. These are
bounded-input limits, not frame-rate promises.

Each benchmark case retains 65 undo snapshots (the editor caps history at 100).
Caret-only changes remeasure zero math nodes. Inactive workbench blocks retain
their independent state/history and are not laid out. Published snapshots are
rebuilt for changed expressions; ancestor measurement and traversal remain real
work. The cache is keyed by subtree spelling and math size within one immutable
font session, is capped at 40,000 entries, and must be discarded on font reopen.
Detailed per-allocation accounting and a long-duration memory plateau test were
not performed.

## Reuse and package evidence

`bash scripts/math/consumer-check.sh` creates a local archive containing
precompiled `moxi`/`moxi_math` modules, the native adapter archive, font and
notices; extracts it to a new directory; and builds/runs
`tests/math/consumer.mojo` there. It supplies only the installed module path,
not `src` or private imports. The consumer owns a real App/window/renderer,
edits a fraction/root, renders native geometry, closes/reopens the font, and
checks a missing-font diagnostic. The installed compiler environment and
separate HarfBuzz installation are still prerequisites.

The minimal executable example is five lines and calls public
`run_math_editor(title, text, font_path)`. A custom host owns `App[MathEditor]`
and calls the documented input/prepare/present seam; neither the component nor
its document/position types adds public generics or requires duplicate geometry.
The first timed installed-consumer build took 12.15 seconds elapsed (18.64 user,
1.20 system). The final rerun took 1.70 seconds (1.58 user, 0.26 system) with the
compiler cache warm; both include Pixi setup. The final log preserves the
diagnostic output. This is a
local source-free package installation, not a fresh-machine or registry install.

Mojo emits warnings about the model's bounded recursive clone routines and
existing deprecated native-window string calls. The exercised recursive paths
terminate under the validated depth limit. Compiler crashes were encountered
with deeply nested mutable `App.component` expressions; moving those operations
into component-level helpers allowed compilation. This is a toolchain constraint,
not evidence of portability to another Mojo version.

## Capture reproduction and provenance

Follow the dependency setup in [math-editor.md](math-editor.md), then run:

```sh
MOXI_SYMPY_PYTHON=/tmp/moxi-math-python/bin/python \
  bash scripts/math/run.sh --capture /tmp/moxi-d02/gallery/d02-native-math-editor
python3 scripts/demo_slideshows.py /tmp/moxi-d02/gallery --check
python3 scripts/demo_slideshows.py /tmp/moxi-d02/gallery
```

The twelve states cover initial, interaction, result and recovery phases. They
are produced from the live Moxi AppKit content view by `cacheDisplayInRect`.
They are correctly classified as **`offscreen-render`**, not `native-window`.
No precomputed image is used by the editor. The rich `frames.json` records
canonical source, revision/selection/caret IDs, geometry generation, status,
window size, source fingerprint and the three-second worker startup delay.
The shared `manifest.json` remains a version-1 object.

Some replay states begin from explicit notation fixtures (matrix and polynomial);
the fraction/radical/scripts use routed typing and structural commands. These
are executable acceptance fixtures, not claims of a physical end-to-end user
journey. The final state saves/reopens and checks exact notation equality.

Visual inspection covered the radical/paired-script state, uneven matrix,
malformed literal, editable Result block, applied numerator and reopened source. The content is legible and the
denominator is retained across application; optional script holes leave
noticeable extra space. This is an implementation review, not human typography
acceptance. Captures use the observed 2× content-view pixel scale on this run.

A temporary `.app` bundle launched and appeared as running in the native UI
inventory. Both path-based and bundle-ID window binding returned
`cgWindowNotFound`. Therefore no OS-compositor screenshot is claimed. Parent
integration owns the final native capture/gallery and must replace the base
revision-plus-uncommitted-source provenance with the final reviewed commit.

## Remaining gates and deliberate boundaries

- **M0/M2 keyboard and IME:** native synthetic paths pass; physical US/non-US
  layouts, OS shortcut conflicts, candidate-window placement on multiple
  displays/scales and a human keyboard-only journey remain unverified.
- **Accessibility:** semantic labels, values, focused state and bounds are
  published and probed. VoiceOver remains paused by instruction. Actual
  structured navigation/announcements are an open release gate; no screen-reader
  equivalence is claimed from the flat semantic-child exposure.
- **M4 presentation:** native-window captures, human font/spacing review,
  next-frame presentation at 60 Hz and the 8.33 ms budget at 120 Hz remain open.
  The automated 480 pt check covers canvas geometry; toolbar ergonomics at
  narrow widths still require human review.
- **Packaging:** fresh-host dependency resolution, signing/notarization,
  registry/conda publication, Linux/Windows and more than one simultaneous
  native math font/view session are not implemented or verified.
- **Notation/input:** this is the documented explicit grammar and conservative
  projection, not TeX, implicit algebra parsing, general bidirectional math or
  a font fallback collection. Two-dimensional selection is structural; arbitrary
  partial-token selection is available in Text mode. Moves target empty slots;
  general cross-document drag/drop is not claimed. Exact evaluation, expansion,
  differentiation with respect to `x`, and substitution of `x` with the captured
  Scratch expression are the exposed operations.
- **Storage:** the example host saves the active notation block. It does not
  persist all workbench tabs, history, cursor or viewport.

Full repository tests, cross-platform builds, sanitizer/leak tooling and physical
input/display tests were skipped. Existing shared/native ownership code, D01's
report, planning files and the orchestration ledger were not modified. No
commits, remote writes or PRs were made by the implementation worker.

## Local handoff artifacts

Full logs remain in `/tmp/moxi-d02`. The successful focused suite is
`check-handoff.log`, with individual `model-test.log`, `editor-test.log`,
`geometry-test.log`, `native_acceptance-test.log`, `backend-test.log` (ten
tests), and build logs. `performance-isolated.log` contains the table above
and process resource counters. `consumer-handoff.log` and
`installed-consumer-{build,test}.log` record the source-free archive check;
its extraction is `/tmp/moxi-math-consumer.e2PglB`.

The final capture replay log is `capture-handoff.log`; PNGs, the manifest,
fingerprint metadata and generated offline slideshow are under
`/tmp/moxi-d02/gallery/d02-native-math-editor`. The local distributable is
`/tmp/moxi-d02/moxi-math-local.tar.gz`. These temporary paths are evidence from
this session, not checked-in build artifacts. Reproduce them using the shipped
scripts before relying on them in another environment.
