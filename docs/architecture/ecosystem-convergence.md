# Ecosystem convergence boundary

Status: provisional architecture record, audited October 4, 2026.

This document is the implementation-side companion to the
[ecosystem convergence plan](../../../moxi-project-planning/ECOSYSTEM-CONVERGENCE-PLAN.md).
It records what Moxi owns, what remains an adapter, and which upstream
compatibility facts have been measured rather than assumed.

## Ownership

| Layer | Moxi owns | Deliberately does not own |
| --- | --- | --- |
| Product model | `PlotDataTable`, `PlotSpec`, `PlotRuntime`, stable row keys, selections, semantics, accessibility, and LOD policy | a foreign fluent plot object model |
| Scene | ordered `Scene`/`SceneCommand` values and `SceneRenderer` lifecycle | canvas-specific structs or native handles |
| Correctness renderer | deterministic software scene output and exact visual goldens | platform font pixels |
| Export/backends | SVG, AppKit, Metal, and the canvas adapter | one backend as the scene contract |
| Python | serialized specs and typed value/buffer inputs | borrowed Mojo object layout, windows, callbacks, or event-loop ownership |
| Upstream dataviz | reference output, algorithm provenance, and capability inventory | wholesale source or fluent API compatibility |

The software renderer remains the portable oracle until another backend has
semantic, structural, and output evidence for each command it claims.

## Python boundary

The first supported binding shape is intentionally narrow:

```text
render(spec_json, named_columns, width, height, format) -> bytes or RGBA
```

`spec_json` is the versioned `PlotSpec` representation. `named_columns` is a
value boundary: contiguous numeric buffers first, followed by explicit
validity, categorical, string, and timestamp encodings. A call owns all
temporary Mojo state in the initial proof; no Mojo object or renderer lifetime
escapes into Python.

The first Python product is now a clean-install headless package under
`python/moxi`. It exports `PNG`, `SVG`, `PDF`, raw `RGBA`, and optional NumPy
arrays without importing Mojo or requiring a compiler at runtime. Native
windows, callbacks, interactive event loops, and notebook widgets remain
separate work; the value-boundary API is the supported MVP and a future native
extension must preserve it.

## Canvas boundary

`canvas_mojo` is an implementation dependency for `CanvasSceneRenderer`, not a
replacement for `Scene`. The current adapter slice covers rectangles, rounded
rectangles, lines, linear gradients, transforms, rectangular clips, opacity,
raw RGBA, PNG, and BMP export. Text, typed paths, images, and true offscreen
layers need explicit follow-on contracts; string-path commands are reported as
fallbacks rather than being rasterized from an untyped string.

The compatibility audit now uses upstream `canvas_mojo` revision
`8fcb0c83966ef872248239f9dafd6baaba06204e` (`v0.42.0`, MIT), built with the
released Mojo `1.1.0` toolchain. The upstream package precompiles cleanly,
the Moxi suite passes all 71 files, and the published package-consumer test
builds and imports `canvas_mojo`, `moxi`, and `moxi_plot` together. Upstream
still keeps its task helper on the private `std.runtime._asyncrt` seam; that
is now an upstream compatibility watchpoint rather than a Moxi-maintained
fork patch.

The v0.42 rasterizer changes a small number of pixels in each reviewed
fixture, so the four Canvas goldens were re-reviewed and recorded in
[`tests/canvas_scene_checksums.tsv`](../../tests/canvas_scene_checksums.tsv).
Moxi pins that immutable upstream revision and exposes the bounded
`CanvasSceneRenderer` adapter from the package root. Focused tests cover pixel
probes, clipping, transforms, deterministic repeat rendering, raw RGBA, PNG,
BMP, stable input-error reporting, typed move/line/quad/cubic/close paths,
explicit text style metadata, isolated offscreen layers, and structural
comparison with the software and SVG renderers. `canonical_canvas_scene_fixtures()`
and `make_canvas_scene()` now drive the compact primitive, dark/light theme,
and plot line/point-overlap cases from one descriptor table; the reviewed
values are checked in at
[`tests/canvas_scene_checksums.tsv`](../../tests/canvas_scene_checksums.tsv).
The canonical plot scene is also exportable with `pixi run canvas-scene`, and
`pixi run canvas-benchmark` checks its reviewed checksum while reporting wall
time, peak RSS, PNG size, command count, and fallback count. The E3 scene
contract now makes typed paths and isolated layers portable; text and image
pixels remain explicit backend/resource lanes rather than guessed placeholders.

The workspace now publishes `canvas_mojo` and `moxi` together. The local
indexed-channel package-consumer test resolves the normal `canvas_mojo` run
dependency from that publish set and imports the installed Moxi package; the
remaining release action is uploading both artifacts to the chosen public
channel. Three macOS arm64 smoke runs for the 640x420 canonical plot scene
have a median of 2.12 s wall time and 298,582,016 bytes peak RSS; the PNG is
29,294 bytes and the reviewed checksum is `853858008`. These are host-specific
release measurements, not cross-platform limits. A floating checkout remains
disallowed.

## Dataviz convergence

The selected reference is `dataviz_mojo` tag `v0.8.0`, revision
`3fd5a7e7c622d6130c99a290b88c4fee039deab2` (MIT). It exposes a fluent `Plot`
plus more than forty convenience marks. Moxi's inventory is in
[`dataviz-capabilities.tsv`](../dataviz-capabilities.tsv).

Each capability must acquire, in order:

1. a Moxi schema/validation row;
2. scene output and software/SVG parity;
3. interaction, accessibility, and tabular fallback behavior;
4. Python exposure through the same `PlotSpec`; and
5. a reference scenario and benchmark.

The catalog promotion now has a row-oriented static lane. `PlotSpec` accepts
canonical names for every inventoried mark, Python exposes
`PlotSpec.add_catalog_mark`, Mojo preserves the corresponding numeric mark
identity through JSON, and `catalog_scenarios()` drives SVG/PNG/RGBA/PDF,
row-anchor hit testing, and repeated Python benchmarks for every mark. Common
interval, sector, edge, calendar, and sized-point families use native
row-oriented geometry while the inventory remains labeled
`compatible-static`/`implemented-static`/`implemented-anchor`; this keeps the
lane distinct from the richer nested-array layout algorithms in the reference
library. Static upstream output without those contracts is still reference
evidence, not an absorbed Moxi feature.

## Current evidence

- `pixi run check` includes the clean-wheel Python import, the Mojo/Python
  PlotSpec contract, the pinned dataviz reference check, and the capability
  wave inventory.
- `pixi run python-package-consumer` builds a wheel from a source-only staging
  tree and imports it in a fresh virtual environment.
- `tests/canvas_renderer.mojo` and `tests/canvas_scene_parity.mojo` pass under
  the exact pinned compiler; `pixi run canvas-scene` renders the canonical plot
  scene and reports explicit fallback counts.
- `pixi run benchmark-compare` passes all ten full-profile cases against the
  reviewed macOS arm64 baseline.
- `pixi run native-screenshot-check` remains the offscreen Metal tolerance
  gate; the visible AppKit lane has a fresh human-reviewed capture through
  `MOXI_RECORD_SECONDS=1 pixi run demo-record`.
- the portable Plot API now has a dedicated source-precompile and software
  renderer smoke in `tests/portable_plot.mojo`; the GitHub Actions Linux lane
  runs `pixi install --locked` and `pixi run headless-check`.
- `BACKEND_LINUX` still reports native-host unavailability: the Linux claim is
  limited to the portable headless package until a native host adapter is
  implemented and measured.
