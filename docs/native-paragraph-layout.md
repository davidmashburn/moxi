# Native paragraph layout slice

A provisional Mojo box protocol now exercises the first part of the
[layout design](design/layout-system.md): a custom policy measures children,
stages placements, and publishes one geometry snapshot. A macOS paragraph owns
the exact CoreText lines used for both measurement and drawing.

Run the resizable example:

```sh
pixi run paragraph-layout
```

The differently sized label and title share a first baseline. Wrapped text sets
the row heights; the chart takes the remaining height with a 160-point minimum.
Click the chart or press Space to remove/restore the summary. At very small
heights, the minimum content overflows and is clipped to the viewport.

## Authoring contract

Import `moxi.box_layout` and, for macOS paragraphs, `moxi.native_paragraph`.
These provisional modules are not re-exported from the package root.
[ParagraphFormLayout](../examples/paragraph_layout_policy.mojo) is the compiled
custom-policy example shared by the demo, native acceptance test, and benchmark.

1. Declare stable nonnegative child keys using `set_paragraph` or `set_box`.
   Identical declarations are no-ops. Content, font, direction, removal, and
   remount changes invalidate the relevant measurements and staged plans.
2. Implement `BoxLayout.measure` and `BoxLayout.arrange`. Mojo traits cannot
   currently take type parameters, so these methods are generic over the
   `ParagraphPayload` provider. Measurements return size and first/last baselines.
3. Measure each child at its exact final width, then call `plan` and `place`.
   Fractional widths remain distinct; zero width is a real constrained offer.
   Leaves in this profile have height-independent measurement results. A fixed
   box declares its minimum content height; the policy decides allocation.
4. Call `commit`. It validates owner, declaration revision, environment, base
   snapshot generation, unique complete placement coverage, and final widths
   before publishing. Failure preserves the previous snapshot. Commit performs
   no leaf measurements.
5. Read paint commands, hit testing, and accessibility from the committed
   snapshot. All use the same placement and viewport clip. Begin the renderer
   frame, call `draw_box_snapshot`, submit custom chart drawing, then publish
   the snapshot's accessibility nodes.

Each leaf caches at most two exact widths. Older snapshots retain their own
paragraph payloads through reference counting after eviction or child removal.
The native draw slot also retains its payload until the next frame, so a
later AppKit draw does not depend on the lifetime of a temporary Mojo value.
Call `invalidate_environment()` when fonts, fallback, or display conditions
change; host notification wiring is not included in this slice.

## Boundaries

This implements one region of paragraph/fixed-content leaves. Intrinsic queries,
nested regions, adaptive built-ins, viewport virtualization, dependency graphs,
and migration of `ColumnView` remain design work. It does not replace the
existing estimated-text content-layout path.

Native text currently uses the system font, natural/LTR/RTL base direction,
word wrapping with a composed-cluster fallback, and LF/CR/CRLF hard breaks.
It supports display paragraphs, not editing, selection, caret navigation, or
IME. Embedded NUL text is rejected at the Mojo bridge. Rich text, font-family
selection, paragraph alignment, and typography configuration are not exposed.
Runtime-owned fields and snapshot immutability are enforced by API convention,
not language-level opacity. Callers must not mutate underscored state or tokens.

## Validation

```sh
pixi run box-layout-test
pixi run native-paragraph-test
pixi run paragraph-layout-benchmark
```

The portable test covers exact/fractional widths, cache reuse and bounded
retention, stale/foreign measurements and plans, atomic failure, remounts,
environment changes, and common clipped paint/hit/accessibility geometry.
The native test compares line ranges against an independent CTFramesetter,
checks hard breaks and a real fractional wrap threshold, verifies baseline
alignment and chart reallocation, compares actual canvas pixels with drawing
retained CTLines, and checks snapshot and native-slot lifetime.

Local acceptance on 2026-10-02: all 75 Mojo suite files and the native paragraph
test passed. Native text parity, custom-paint cache, all 64 accessibility ABI
flag combinations, package compilation, and API inventory checks also passed.
The live AppKit example was checked at wide and narrow widths;
click and Space changed summary visibility and chart allocation, and the
accessibility tree reflected summary removal. This is not a VoiceOver audit,
an IME test, or evidence of non-macOS native support. CI and the entire aggregate
`pixi run check` gate were not run for this slice.

## Timing method

The benchmark reports seven fresh four-leaf contexts, each followed by 100
unchanged passes and 100 passes alternating between 380 and 760 points. Each
pass includes identical declarations, measurement/arrangement, atomic commit,
paint-command generation, and accessibility snapshot generation. Compilation,
native submission/drawing, and event handling are excluded. The first fresh
context also pays process-level font initialization. Alternating two widths
fits the two-entry cache; these timings do not represent a continuous resize
through previously unseen widths or a general layout-engine speed comparison.

[Recorded samples](native-paragraph-timings.json) from an Apple M4 with 32 GiB,
macOS 26.6.2, and Mojo 1.1.0.dev2026082605: median fresh-context time 253 µs
(first process sample 10.194 ms), unchanged pass 1.32 µs, alternating-width pass
1.88 µs. Every unchanged batch performed zero leaf measurements. Each alternating
batch performed four measurements when first visiting the second width, then
reused the retained entries. These are local four-child observations, not a
performance gate or comparison against the existing layout path.
