# Text and native parity policy

Moxi has two text paths with deliberately different support claims:

- `PortableTextShaper` is deterministic and approximate. It provides practical
  grapheme boundaries, script/direction runs, fallback-face classes, stable
  source clusters, and bounded wrapping. It is the headless contract, not an
  OpenType or paragraph-layout implementation.
- `MacOSTextShaper` delegates to CoreText for native glyph ids, advances,
  fallback, and bidi behavior. `HarfBuzzTextShaper` is an optional host-linked
  OpenType adapter backed by an owned `FontCollection`. CoreText continues to
  own its native fallback and paragraph policy; neither adapter borrows the
  other's glyph identities or resource handles.

## Shared corpus

`canonical_text_corpus()` in `moxi.scenarios` is the source for portable tests,
CoreText replay, and HarfBuzz collection tests. Its ten cases cover combining
marks, emoji modifiers/ZWJ/keycaps/flag pairs, explicit and auto RTL, mixed
scripts, Devanagari marks/conjuncts, narrow wrapping, long unbroken text,
CRLF, blank lines and trailing breaks. The conformance test additionally exercises codepoint-safe
selection, replacement ranges, marked-text/IME state, and boundary clamping.

The parity contract compares properties that should be engine-independent:
non-empty input produces glyphs, source clusters stay in range, measured output
has positive dimensions, and native output is marked non-approximate. Glyph ids,
exact advances, run segmentation, and pixel checksums are not required to
match between engines.

## Font collections and paragraph policy

`FontCollection.add_file(path, face_index)` loads a scalable Unicode face.
`add_family(name)` resolves once through Fontconfig, including the matched
face index. Fontconfig may substitute a family; the C ABI exposes the resolved
path and index. Use explicit file/index choices when reproducibility matters.
No fonts are downloaded and no implicit system search occurs during shaping.

The first face covering every required scalar in a practical grapheme is
selected for that entire unit. Joiners and variation selectors do not require
standalone glyphs. This is nominal coverage, not proof that a font implements
an emoji ligature or variation sequence. Adjacent units with the same face,
script and direction are shaped together, preserving OpenType context.
`MissingFontPolicy.NOTDEF` keeps an uncovered unit in the primary face and
reports it through `missing_clusters()`; `REJECT` fails the entire paragraph.
Unsupported policy values fail without mutation. Glyph/font IDs are local to
the paragraph's engine and retained collection snapshot.

Collections own FreeType resources and a one-entry cache. Text, font size,
width, direction and collection revision form the cache key. Adding/reordering
faces or changing missing-font policy increments that revision; failed and
no-op changes do not. Existing `HarfBuzzParagraph` snapshots retain their
original faces and geometry after eviction, reordering or collection disposal.
Hosts must serialize calls sharing a collection, including snapshot rendering;
independent collections have independent resources and counters. The old
`harfbuzz_text.h` C ABI remains a legacy single-threaded path; the Mojo shaper
uses the owned `harfbuzz_collection.h` API.

The supported paragraph profile is deliberately bounded:

- At most 2,048 Unicode scalars, finite positive font size up to 4,096 and a
  finite nonnegative width. Width zero is unconstrained. Invalid UTF-8, invalid
  direction values and invalid dimensions fail; Mojo also rejects embedded NUL.
- Greedy **cluster** wrapping, including inside words, with each candidate line
  reshaped. It is not Unicode word/line breaking or hyphenation. An indivisible
  unit may overflow a narrow constraint; measured width reports that overflow.
  CRLF is one break, and blank/trailing lines are retained.
- Practical composed units include marks, variation selectors, emoji modifiers,
  ZWJ sequences, paired regional indicators and Devanagari virama sequences.
  This is not a complete UAX #29 implementation. The portable editor includes
  the corpus's Hebrew, Arabic and Devanagari marks and uses the same practical
  boundaries for wrapping and deletion.
- Direction is first-strong or explicitly requested, with coarse script-run
  ordering. Full UAX #9 paragraph bidi (including neutral/number resolution)
  remains outside this profile. Explicit bidi controls and tabs are rejected.
  `approximate=False` describes real OpenType glyph shaping, not full bidi or
  typography conformance.
- Carets clamp to shaped-cluster boundaries (ligatures may cover multiple
  editing units), with downstream affinity at ambiguous boundaries. Hit testing
  uses advances. `selection_rects()` returns one rectangle per selected shaped
  cluster, preserving disjoint mixed-direction geometry. No caret inside an
  OpenType ligature is synthesized.

Use `FontCollection.paragraph()` for checked failures, native status, geometry
and retained snapshots. The existing nonthrowing `TextShaper.shape()` seam
returns an empty approximate result on failure, never a previous result.
`FontTextStatus` reports native failures; validation rejected in Mojo raises
before entering the native API. The default shaper retains the historical
Arial Unicode MS Fontconfig request; applications opt into additional faces.

`tests/fixtures/fonts/` contains original geometric fonts for deterministic
coverage, fallback-order and advance assertions. System-font corpus checks
compare structural properties; no cross-engine glyph ID or pixel equality is
asserted. See [F01 acceptance and capture recipe](text-fallback-acceptance.md).

## Scene and GPU replay

`tests/native_scene_parity.mojo` replays a compact scene through both
`SoftwareSceneRenderer` and `MacOSMetalRenderer`. Command order/count, rendered
primitive counters, and explicit fallback counters are exact structural
signals. Native pixel comparison is a separate masked/tolerance lane:
`tests/native-screenshot-policy.json` records the dimensions, channel budget,
mismatch budget, and the CoreText mask. `pixi run native-screenshot-check`
captures the offscreen Metal texture, compares it with the software oracle,
and writes a reviewable report under `dist/native-artifacts/`. CoreText
rasterization, GPU color space, device drivers, and scale factor can still
change pixels; the mask makes that variance explicit instead of treating a
native checksum as exact pixel parity.

Run the checks on a macOS host with the relevant frameworks:

```sh
pixi run text-conformance
pixi run harfbuzz-check
pixi run native-text-parity
pixi run native-scene-parity
pixi run native-screenshot-check
```
