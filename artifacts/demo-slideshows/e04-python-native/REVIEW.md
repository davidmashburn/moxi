# E04 gallery review — November 23, 2026

The final installed renderer supplies raster text and searchable vector PDF.
Both local CPython consumers pass **48 native and 364 facade tests**. Five fresh
browser frames were directly reviewed: **3 scenarios pass, 2 remain partial,
and all 5 visual checks pass**. The native-extension production gate stays open
because runtime redistribution and wider support remain unreviewed.

The tested source is `424126e12385c1cc74335e2384b6bc90fb084f9a`. This addresses the native Python
part of remaining item 3 in the project's planning branch; it does not promote
the experimental wheel to a distributed product.

## Tested environment and source binding

- Local host: macOS 27.2.1, Darwin 27.2.0 arm64; Mojo
  `1.1.0 (8189361e)`; separate CPython 3.14.7 and 3.13.15 consumers.
  Each consumer is a new venv outside the repository on the build host.
- Actual path: installed CPython C extension → compiled Mojo PlotSpec/table/Scene
  → CoreGraphics/CoreText for RGBA/PDF, or Mojo SVG serialization. Python encodes
  the exact RGBA bytes as PNG. The private ABI version is 2; `abi3` is false.
- All 139 recorded native inputs and all
  11 facade files match the tested commit,
  wheel and installed bytes. Each ABI's four installed binaries match its wheel;
  all three loaded Mojo runtimes come from that wheel's `.libs` directory.
  The build records `dirty: true` for surrounding integration/evidence changes;
  selected native/facade inputs have no diff from the tested commit.
- Native source aggregate: `044258a1cd389d6e4237f5d05fd8975484787ff85f8844098595bebdb040c532`.
  Native object: `9a132759e96ad6ee06888682f8bb7b031ef175b7cd879fc0374b0f2c551860e9`.
  Compiler: `b90f394cd44d1d1041493af512074eb606b33294202b053a2fe299ab8bde2e8f`.
  The manifest separately hashes 20 experiment/proof sources.
- Local CPython 3.14 wheel: `moxi_native_experimental-0.1.0-cp314-cp314-macosx_26_0_arm64.whl`,
  908752 bytes, SHA-256 `814a01d6560edb95cfae5a0e72b6f2860adf74d8415d04fc34689cea2af64ff5`.
  CPython 3.13 wheel: `moxi_native_experimental-0.1.0-cp313-cp313-macosx_26_0_arm64.whl`,
  908747 bytes, SHA-256 `bc67c746fe17ec42a16a4f70eb9cafad5b5336284887d6a686baa85b2f5e90a3`.
  The macOS 26 tags are local interpreter-derived tags, not a macOS 26 test claim.
- The probe uses `env -i`, Python `-I`, no Mojo executable on PATH and an audit
  hook rejecting process creation before Moxi import/render. This establishes
  the tested import/render path without a compiler or subprocess invocation;
  development tools remain installed on the build host.
- Both ABI logs are byte-for-byte copies of their own retained consumer logs,
  without shared temporary log names. The [portable summary](publication.json)
  retains both ABI results, input fingerprints and wheel/binary hashes. Raw
  source-verification reports retain full consumer paths locally and are
  excluded from publication.

## Fresh hosted consumer

The [matching hosted run](https://github.com/davidmashburn/moxi/actions/runs/45131806275)
completed successfully from `424126e12385c1cc74335e2384b6bc90fb084f9a` on fresh
macOS 15 ARM64 runners. CPython **3.13.17 and 3.14.10 each passed 48 native and
364 facade tests**, isolated import/render, dependency, architecture and signature
checks. [Run/job provenance](hosted.json) and actual consumer summaries:
[3.13](hosted-cp313.log), [3.14](hosted-cp314.log).

The packaging check previously exposed a universal2 tag and an invalid extension
signature. The repaired build selects arm64, labels the wheel arm64, verifies
all four Mach-O architectures and ad hoc signs the final extension. Inspector
failures retain tool diagnostics. The hosted workflow caches/uploads neither
wheels nor compiler environments and removes temporary bundled runtimes.
No wheel, object or runtime library is included in shared gallery artifacts.
This is validation evidence; the proprietary runtime redistribution review
remains open.

## Browser scenarios and direct observations

Pages were served on loopback port 8764 and captured in an isolated connected
Playwright context after preferred Chrome's browser access host was unavailable.
The actual browser is Chromium 158.0.0.0; its UA's Intel/macOS compatibility text
is not a host-architecture claim. All PNGs are unaltered CSS-scale 1400×1100
captures, DPR 1, from `2026-11-23T07:46:23.653Z`.
All referenced images loaded, every page fit the viewport, and there were no
page/console errors or failed requests. Per-frame timestamps, loaded resources,
viewport and observations are in [capture.json](capture.json). These are browser
evidence pages containing actual outputs/logs, not native application windows
or terminal screenshots. The import page displays consumer-relative module paths
and explicitly identifies the omitted absolute temporary-directory prefix. Full
unmodified probe reports remain local.

| Scenario | Exercise and expected result | Observed result | Outcome and evidence |
| --- | --- | --- | --- |
| Import | Import both installed wheels under isolation; expect compiled ABI/version, copied ownership and wheel-local runtime. | ABI 2, `abi3: false`, copy-per-call and consumer-relative module paths are complete and readable. Local source/binary binding checks pass. | **Pass**. [Frame](01-import.png), [page](01-import.html), [portable import/ABI records](publication.json). |
| Native scene | Render six samples and two line/scatter layers at 320×240 in four formats. Expect PNG decoded equal to native RGBA and vector PDF with selectable text. | Native SVG and PNG both visibly contain the title, both numeric axes outside the data clip and both legend labels. Independent tests establish exact PNG pixels, PDF text/fonts, vector strokes and no embedded page images. All output byte counts/hashes fit. | **Pass for the declared slice**. [Frame](02-render.png), [page](02-render.html), [exports](02-render.json), [native tests](native-tests.log). |
| Facade comparison | Export the same fixture through the existing facade; inspect all eight exports and both PNGs. | All eight exports are bound to current bytes. Native text, grid, background and layout visibly differ from the facade. Unaligned mean RGBA difference is 164.5243/255, a description without a parity threshold. | **Partial**: export contracts pass; visual/layout and scientific parity remain unestablished. [Frame](03-comparison.png), [page](03-comparison.html), [facade tests](facade-tests.log). |
| Rejection/recovery | Reject malformed inputs, recover valid rendering, exercise repeated calls and owned output lifetimes. | Three example exceptions and the 48-native/364-facade summaries are fully readable. Tests cover 500 successful renders alternating with 500 public failures and 500 Mojo-parser failures, GC/input mutation/destruction, and 40 calls from four threads with the GIL held. | **Pass within those bounds**. [Frame](04-recovery.png), [page](04-recovery.html), [errors](04-errors.json), [native tests](native-tests.log). |
| Packaging/timing | Inspect wheel tags, signatures, runtime notices/dependencies and loaded libraries; measure 30 calls/format after three warmups. | Arm64 wheel/hash, three runtime names, four timing rows and the open production gate are complete and legible. Includes validation/copies/native render/encoding; excludes build/install/import, initial warmup, file IO and screenshots. | **Partial**: tested host/ABI pairs pass; distribution approval and wider support are open. [Frame](05-packaging.png), [page](05-packaging.html), [portable wheel records](publication.json), [samples](benchmark.json). |

The final [native PDF](native.pdf) was also independently rendered by
pypdfium2 5.15.2 / PDFium 159.0.8149.0. Its complete 640×480
[page preview](native-pdf-preview.png) visibly contains the title, axes,
line/scatter geometry and both legend labels. [Viewer record](pdf-viewer.json).
Selectable text and vector structure are established separately by pypdf tests.

The [declared contract](../../../experiments/python-native/README.md#declared-rendering-slice)
remains bounded: 1–4 ordinary line/scatter layers, 1–8 numeric columns,
1–4096 rows, 64–1024 pixels per side, printable ASCII labels, constant mark
styles and copied numeric buffers/validity masks. Coordinates remain Float32.
Unsupported encodings, transforms, non-default scales, facets and richer scene
operations fail explicitly. This evidence does not establish a general renderer.

## Comparison, reproduction and retained proof

The locally retained previous manifest (`baseline/prior.json`) records source
`d7fa3ed563948860f4baf18bcc9f3eb279197135` and 135 build inputs. All four current
native export hashes differ; all four facade export hashes match its recorded
hashes. [Hash pairs](comparison.json). The previous output bytes were not
independently re-rendered or verified. This is not a before/after visual or
scientific regression measurement. All five browser frames were freshly captured.

Use the [build/capture recipe](README.md) and
[experiment prerequisites](../../../experiments/python-native/README.md#reproduce-locally).
`evidence.py verify` checks recorded native/facade inputs, object/wheels,
installed binaries/wrappers, all eight exports, proof sources, report hashes and
every referenced frame/page. Both retained consumer venvs and the local build
must remain available for that source-bound check. Raw build, packaging, import,
loaded-runtime and source-verification reports, verbose build/check logs, prior
manifest and ABI-specific raw directories stay local because they include machine
paths. Their hashes are identified as local-only in the manifest; they are not
links to published files. Wheel/object/runtime binaries are excluded.

The scoped ignore allowlist publishes the five captures, evidence pages, offline
gallery, selected actual exports and portable JSON/test summaries. A Git-only
copy can run `evidence.py verify-publication` without local wheels or consumer
venvs. This checks the published bytes and gallery provenance; it does not rerun
the native binary checks. Portable paired test output is retained for
[3.14 native](native-tests.log), [3.14 facade](facade-tests.log),
[3.13 native](cp313-native-tests.log) and [3.13 facade](cp313-facade-tests.log).

The [self-contained slideshow](index.html) was exercised with the network offline:
all ten embedded images loaded; 15 interactions verified next/previous,
wraparound, every contact-sheet jump, keyboard navigation and reload. Sixteen
states including the initial load pass with no browser errors. Its checked
index SHA-256 is pinned in [gallery-check.json](gallery-check.json).
Seven in-memory stale-evidence controls reject changed native fingerprints,
proof/export/image/page hashes, frame counts and outcomes without modifying
source or image bytes. [Negative controls](verification-tests.log).
A separate copy containing only the allowlisted files passed portable
verification without build binaries or consumer venvs. Its negative controls
rejected changed PNG bytes and a temporary-directory path, including when the
altered report's hash matched the manifest.
Four gallery-tool tests, three Mach-O-inspector tests and two notice-retention
tests pass. [Tooling output](tooling-tests.log). The common root gallery was not
regenerated by this E04-specific recipe.

Confidence is **high for these bounded local observations and the completed
two-ABI hosted matrix**.
Sanitizers/leak detectors, free-threaded Python, subinterpreters, other
architectures, Linux/Windows, abi3/universal support, broader visual/scientific
parity, production load, native-window usability and the full Mojo suite were
not checked by this work. VoiceOver remains paused. Runtime redistribution/legal
permission was not reviewed. Wider claims require those independent checks;
this wheel remains experimental.
