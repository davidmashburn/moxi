# E04 gallery review — November 20, 2026

Five regenerated browser frames were visually reviewed against the actual built
native extension: **3 scenarios pass, 2 are partial, 0 are blocked; all 5 visual
checks pass**. This certifies the bounded local evidence below. The experimental
native-extension production gate remains open.

The reviewed implementation is `d7fa3ed563948860f4baf18bcc9f3eb279197135`.
The acceptance basis is [planning section 2 at its inspected revision](https://github.com/davidmashburn/moxi/blob/2e46d93667166d077e47311277689c54d35942dc/PROJECT-PLANNING.md#2-certify-the-reviewed-integrations-demo-evidence).
No shared handoff, master index, project feature, commit, push or external system
was changed. The capture/provenance tool was updated separately from native and
facade inputs.

## Tested environment and provenance

- Build and clean consumer: Darwin 27.2.0 arm64, CPython 3.14.7, Mojo
  `1.1.0 (8189361e)`. The consumer uses NumPy 2.5.5, Pillow 13.0.0, pypdf 7.1.1
  and pytest 9.2.0. This is a fresh venv on the build host, not a fresh host.
- Actual backend: installed `moxi_native._core` CPython C extension → compiled
  Mojo PlotSpec/table/Scene → `SoftwareSceneRenderer` RGBA or `SvgSceneRenderer`.
  Python wraps the native pixels as PNG or raster RGB PDF. The unchanged `moxi`
  facade is installed from its own wheel for comparison.
- All 135 native build inputs match both the current checkout and the reviewed
  commit. Their aggregate SHA-256 is
  `96057c8f4856523dfa00d2fa3f9e76ab5f59ab62036b992c7ffc2c0f39b84937`.
  Facade wheel and installed source bytes match the corresponding commit inputs.
  Build metadata records `dirty: true`: capture-tool edits were present, while
  the verified native/facade inputs have no diff from that commit. The manifest
  separately hashes the experiment's 17 proof sources, including the updated tool.
- Native object SHA-256:
  `60985ea3942126696c0559eb5c74e2f3405f6f2a9295fc3ecc7eafc79f34f970`.
  Compiler SHA-256 was independently rehashed and matches
  `b90f394cd44d1d1041493af512074eb606b33294202b053a2fe299ab8bde2e8f`.
- Built wheel:
  `moxi_native_experimental-0.1.0-cp314-cp314-macosx_26_0_arm64.whl`,
  907300 bytes, SHA-256
  `f0e57d6637c9db613d4b2eecef455fc1a488b3b3ee27478cd68349083d15cbe4`.
  All 4 installed binaries match the inspected wheel. The loaded-image report
  locates all 3 Mojo runtime libraries in that installed wheel's `.libs`, with
  no Pixi image loaded. This does not establish portability of that tag.
- The probe runs with `env -i`, Python `-I`, no Mojo executable on PATH, and an
  audit hook rejecting process creation during import/render. It proves this
  import/render path does not invoke a compiler or subprocess; the build machine
  still has development tools installed.
- Browser evidence was served only on loopback at port 8764. Connected Playwright
  used isolated context `moxi-e04-d7fa3ed`, Chromium UA version 158.0.0.0,
  viewport 1400×1100 CSS pixels, DPR 1, unaltered CSS-scale 1400×1100 PNGs.
  The UA's Intel/macOS compatibility text is not a host-architecture claim.
  Final-frame captures span `2026-11-20T22:57:48.274Z` to
  `2026-11-20T23:01:57.495Z`; per-frame timestamps, image loads, dimensions,
  document bounds, errors and visual observations are in [capture.json](capture.json).
  Every page fits without horizontal clipping; all referenced images loaded.
  Final captures have no page/console errors or failed requests.
- T3 snapshot capture timed out twice after 15000 ms; preferred Chrome's browser
  access host was unavailable. Playwright supplied the successful replacement
  captures. These are browser evidence pages containing real outputs/logs,
  not native application-window or terminal screenshots.

## Scenarios and visual observations

| Scenario | Exercise and expected result | Observed result | Outcome and evidence |
| --- | --- | --- | --- |
| 01 import | Build/install both wheels in the retained clean consumer; import under isolation, report ABI/copy policy and actual paths. Expect compiled native module and wheel-local runtime. | Installed paths, ABI version 1, `abi3: false` and copy-per-call are legible; source and binary hashes agree. | **Pass**. [Frame](01-import.png), [page](01-import.html), [import report](01-import.json), [loaded images](loaded-runtime.json). |
| 02 native scene | Render the canonical six-row, two-layer line/scatter fixture at 320×240 through all 4 formats. Expect nonempty native scene, valid extents, PNG decoded equal to RGBA and PDF image decoded equal to native RGB. | Tests establish the stated native decoder checks. Both pictured images load. SVG shows title/legend; PNG omits their text and shows approximate line/corner pixels. Byte counts/hashes are fully visible. | **Pass within the declared rendering slice**. [Frame](02-render.png), [page](02-render.html), [exports report](02-render.json), [native tests](native-tests.log). |
| 03 comparison | Run the unchanged facade on the same fixture/dimensions; compare returned bytes and inspect both PNGs. Expect explicit renderer/export limits rather than equality. | All 8 current exports are hashed. Images visibly differ in background, axes, grids, legend swatches and endpoint margins. Unaligned mean RGBA byte difference is 168.5723/255, descriptive only. Native decoder checks are labeled as such; native PDF remains raster. | **Partial**: local export contracts pass; visual, text/layout and scientific parity remain unestablished. [Frame](03-comparison.png), [page](03-comparison.html), [facade tests](facade-tests.log). |
| 04 recovery | Reject 3 malformed examples, then render valid input. Run 500 successful renders alternating with 500 public failures and 500 native-parser failures, retained outputs/GC/mutation checks, and 40 calls from 4 threads under the GIL. Expect recovery and owned output bytes. | All 46 native and 315 facade tests pass. Three exception reports, test summaries and bounded claims are readable without clipping. | **Pass for the tested bounds**. [Frame](04-recovery.png), [page](04-recovery.html), [errors](04-errors.json), [native tests](native-tests.log), [full consumer log](clean-check.log). No sanitizer/leak or parallel-execution inference. |
| 05 packaging/timing | Inspect wheel dependencies/tags/runtime notices and loaded runtime; measure 30 calls per format after 3 warmups. Expect honest same-host scope and an open deployment gate. | Bundled/system dependency inspection passes; wheel tag/hash, 3 runtime names, 4 timing rows and the open production gate are complete and legible. Timings include validation/copies/native render/encoding, exclude build/install/import/initial warmup/file IO/capture, and have no facade speed comparison. | **Partial**: same-host inspection passes; ABI/host portability, sanitizer evidence and runtime redistribution review are absent. [Frame](05-packaging.png), [page](05-packaging.html), [wheel inspection](packaging.json), [timing samples](benchmark.json). |

The [native contract](../../../experiments/python-native/README.md#declared-rendering-slice)
is intentionally bounded: 1–4 ordinary line/scatter layers, 1–8 numeric columns,
1–4096 rows, 64–1024 pixels per side, ASCII labels, constant styles and bounded
JSON/SVG. Numeric buffers are copied synchronously with explicit validity masks;
scene coordinates remain Float32 even for Float64/Int64 input. Category, string,
timestamp, strided buffers and richer rendering features are unsupported.
Neither screenshot similarity nor the format containers establish the facade's
text/layout/visual fidelity, vector PDF behavior or scientific equivalence.

## Comparison with previous evidence

The preserved [previous manifest](baseline/prior.json) reports dirty revision
`8c7014763753f6fe9fb07f01654b4b1dcd39293a`, 133 build inputs and aggregate
`405b47aa2fbb84da7a505de42b67b10a3e19bb173900dbc83c09f434eaeb6a10`.
It is not evidence for the current source without regeneration. The compiler
hash is unchanged, but current native object and wheel hashes differ.
All **8 current native/facade export hashes equal the previous manifest's
recorded hashes**. The [comparison report](comparison.json) retains those pairs.
Previous PNGs, pages and reports were absent in this checkout: old image bytes
could not be checked and a side-by-side visual comparison was not possible.

All five current screenshots have new hashes, reflecting the current source
header, evidence, wording and capture environment. The old recorded DPR 2 and
1280×1006 PNG dimensions were replaced by observed DPR 1 and 1400×1100 outputs;
the difference is not a rendering-regression measurement. No current screenshot
has been resized or edited after browser capture.

## Reproduction and retained artifacts

Use the portable [capture/build recipe](README.md), the
[experiment prerequisites](../../../experiments/python-native/README.md#reproduce-locally)
and these repository-root commands:

```sh
# Optional: MOXI_E04_MANIFEST=/path/to/an/installed/moxi/pixi.toml
bash experiments/python-native/build.sh > /tmp/moxi-e04-build.log 2>&1
bash experiments/python-native/check.sh > /tmp/moxi-e04-clean-check.log 2>&1
python3 experiments/python-native/evidence.py pages
# Capture/review the 5 HTML pages as described in README.md; retain capture.json.
python3 experiments/python-native/evidence.py finalize
python3 experiments/python-native/evidence.py verify
python3 tests/demo_slideshows_test.py
python3 experiments/python-native/test_build_notices.py
git diff --check
```

The actual build reused the already-installed Pixi environment at
`<environment-checkout>/pixi.toml` through `MOXI_E04_MANIFEST`; it compiled this
worktree's absolute source path, not that other checkout's sources. That path is
an environment-specific observation, not a reproduction prerequisite. The
retained consumer for this run is `/tmp/moxi-e04-consumer.4qjnjr`; paths in the
import report are diagnostic and will change on a rerun.

`verify` rehashes all native/facade inputs, the object/wheels and installed
binaries/wrappers, all 8 exports, 17 proof sources, recorded evidence artifacts,
and every referenced PNG/page. It rejects stale fingerprints, artifacts and
frames. It requires the local build and retained consumer to remain available.
The common gallery validator is also invoked on this gallery alone; the common
root index is not rebuilt. The self-contained [slideshow](index.html) embeds all
5 PNGs and is checked locally with the network offline: every frame, next/previous,
wraparound, contact-sheet jumps, keyboard navigation and reload are exercised.
The [slideshow check](gallery-check.json) and [verification checks](verification-tests.log)
record results; native/facade test logs retain their original run output.
The local check totals are 46 native tests, 315 facade tests, 4 gallery-tooling
tests and 2 notice-retention tests passing, plus 15 offline slideshow interactions
and 7 rejected in-memory stale-evidence controls. The latter deliberately alter
the native fingerprint, proof-source hash, export hash, referenced PNG/page hash,
frame count and scenario outcome; they do not modify source or image bytes.
See [tooling test output](tooling-tests.log). Final verification covers 36 hashed
gallery artifacts; the self-contained index is separately pinned by the
slideshow check.

Tracked/reviewable changes are this review, [README.md](README.md),
[manifest.json](manifest.json) and the necessary
[capture/provenance tool](../../../experiments/python-native/evidence.py).
The review is newly untracked until integrated; nothing was staged or committed.
The **5 PNG frames, 5 HTML pages, self-contained index, 8 exports, JSON/log
reports and baseline manifest are ignored local files**. All remain under this
gallery directory for integration: 37 ignored gallery files in total. The native object and two wheels also remain
ignored under `experiments/python-native/dist/`. Preserve those local artifacts
with the manifest when moving the evidence; a Git-only checkout lacks them.

Confidence is **high for these local, bounded observations**. No fresh-host,
other-Python/OS/architecture, abi3/universal, sanitizer/leak-detector, free-threaded
Python, broader rendering/scientific parity, production-load, full Mojo suite,
remote CI, native-window usability or VoiceOver check was performed. VoiceOver
remains paused. PDF image data was independently decoded, but no separate PDF-page
viewer/visual check was performed. Redistribution/legal permission was not reviewed. Broader support
would require the relevant independent host/ABI installs, sanitizer/lifetime
evidence, parity reference tests and a runtime redistribution review; these
captures do not supply them.
