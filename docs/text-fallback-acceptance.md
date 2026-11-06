# F01 acceptance evidence and capture recipe

Implemented scope: host-selected ordered scalable font collections, explicit
missing-coverage policy, retained HarfBuzz paragraph resources, revision-aware
layout caching, cluster wrapping, caret/selection geometry, and a shared
10-case corpus. CoreText ownership and its structural comparison remain intact.
The precise supported subset is in [text policy](text-policy.md).

## Automated acceptance

Verified on macOS arm64, Mojo 1.1.0 (8189361e), HarfBuzz 14.5.0, FreeType
26.6.20 (pkg-config package version), Fontconfig 2.18.3:

- `tests/text_boundary.mojo`, `text_shaping.mojo`, `text_layout.mojo` and
  `text_conformance.mojo`: pass. Corpus includes mixed scripts, composed
  units, narrow wraps, CRLF/blank/trailing lines, marked-text state and edits.
- `pixi run harfbuzz-check`: native collection policy/lifetime tests, Mojo
  integration across all ten fixtures, compatibility shaper smoke, executable
  laboratory, and generated-artifact assertions pass. Deterministic fixture
  coverage reports zero missing clusters for every corpus case. Explicit
  missing-glyph tests independently verify `.notdef` and rejection.
- `pixi run native-text-parity`: all ten shared cases pass CoreText structural
  parity. Glyph IDs, metrics and pixel output are deliberately not equated.
- Native collection tests compiled and passed with both AddressSanitizer and
  UndefinedBehaviorSanitizer; no diagnostics. Failure cases cover malformed
  UTF-8, out-of-profile input, invalid faces/indices/policies, strict missing
  coverage and extreme caret/hit-test coordinates.
- Collection changes invalidate new layouts while old snapshots remain usable
  after cache eviction and collection destruction. A second collection has
  independent resources and counters. Generated retained SVG is byte-identical
  to the original snapshot after the fallback order changes.

Logs for this checkout's implementation run are in `/tmp` with prefix
`f01-3f502be0-`: `harfbuzz.log`, `portable.log`, `coretext.log`, and
`sanitizer.log`. The environment was reused from the existing development
checkout by setting PATH/MODULAR_HOME; sources and generated outputs are from
this isolated checkout. No planning files were changed.

## Runnable screenshot sequence

From the checkout root:

```sh
pixi run text-laboratory
# Open dist/text-laboratory/index.html in a browser.
```

The command builds and runs `examples/text_laboratory.mojo`. It emits SVGs from
actual HarfBuzz glyph IDs and their retained FreeType outlines, plus a local
HTML replay. Browser text shaping is not used for the paragraph images. The
page is a replay of executable states, not an interactive browser editor.
Use an approximately 1100 × 850 viewport and capture these URL fragments:

1. `#mixed`: wide mixed-script paragraph; primary/fallback colors and missing
   coverage count. One build, revision 4.
2. `#wrap`: 330-unit constraint; more lines, two builds, revision 4.
3. `#fallback`: alternative fallback moved ahead of the previous fallback;
   new outlines/metrics, three builds, revision 5.
4. `#selection`: selected range across scripts/lines and caret; still three
   builds, one cache hit, revision 5.
5. `#edit`: one `TextInputState.delete_backward()` removes the composed
   `e + acute`; four builds, one cache hit, revision 5.

The default requested families are Arial, Arial Unicode MS and Hiragino Sans.
Fontconfig substitution is host-dependent; missing emoji coverage is displayed
and counted, not hidden. A host can rerun the compiled laboratory with three
family names as positional arguments. Check the actual resolved choices with
Fontconfig or `moxi_font_collection_path/face_index`; use explicit file/index
collections in applications that need reproducibility. SVG filenames match
these fragments. `retained.svg` is an additional original-snapshot control.
`python3 scripts/text_laboratory_check.py` validates output structure, expected
build/hit counts and retained-snapshot identity. It also reports whether the
host's fallback choices changed outlines (verified on this macOS host). If
Fontconfig substitutes identical faces, choose distinct installed families for
that visual acceptance step.

## Unmet or excluded gates

Human IME acceptance was not performed. VoiceOver remains paused; no human
screen-reader acceptance is claimed. Browser screenshots and visual acceptance
are left to the parent's capture pipeline. Linux execution, full release/CI,
performance benchmarking, color/bitmap fonts, full UAX #9/UAX #29 conformance,
word-breaking/hyphenation and production font licensing/distribution were not
verified or added. The bounded native implementation reshapes candidate lines;
it is correctness evidence for this profile, not a throughput claim.
