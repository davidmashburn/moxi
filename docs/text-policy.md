# Text and native parity policy

Moxi has two text paths with deliberately different support claims:

- `PortableTextShaper` is deterministic and approximate. It provides practical
  grapheme boundaries, script/direction runs, fallback-face classes, stable
  source clusters, and bounded wrapping. It is the headless contract, not an
  OpenType or paragraph-layout implementation.
- `MacOSTextShaper` delegates to CoreText for native glyph ids, advances,
  fallback, and bidi behavior. `HarfBuzzTextShaper` is an optional host-linked
  OpenType adapter with one host-selected font; it does not claim a production
  fallback collection or full paragraph bidi policy.

## Shared corpus

`canonical_text_corpus()` in `moxi.scenarios` is the source for portable tests,
native replay, and future host adapters. It covers combining marks and emoji,
explicit RTL, auto-direction RTL, mixed bidi, and a mixed-script fallback case
that also wraps. The conformance test additionally exercises codepoint-safe
selection, replacement ranges, marked-text/IME state, and boundary clamping.

The parity contract compares properties that should be engine-independent:
non-empty input produces glyphs, source clusters stay in range, measured output
has positive dimensions, and native output is marked non-approximate. Glyph ids,
exact advances, run segmentation, and pixel checksums are not required to
match between engines.

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
pixi run native-text-parity
pixi run native-scene-parity
pixi run native-screenshot-check
```
