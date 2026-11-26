# E05 · Cairo Scene export experiment

**Decision: keep Cairo experimental.** Direct Scene-to-PDF export preserves the triangle, rectangular clip, translated mark, basic glyph and two-color bitmap in this corpus. The four existing parity scenes still differ measurably from software. The probe adds a second command mapping and native dependency, and Moxi already exports PDFs through Python Figure. The potential gain is exporting arbitrary Scene content, particularly mixed vector and owned-image pages.

## Replay

From the repository root, run the following with Pixi, uv, Cairo (including its pkg-config metadata on macOS) and librsvg's `rsvg-convert` installed. Choose a fresh output directory. Pixi resolves the repository's Mojo environment and uv resolves the pinned Python tools.

```sh
bash experiments/cairo-scene/run.sh /tmp/moxi-e05-replay
```

The exporter constructs all four fixtures from the same registry and plot-aware factory as `tests/canvas_scene_parity.mojo`. Each Scene goes to software, Canvas and SVG, then its commands and owned RGBA bytes go to the Cairo adapter. The fifth Scene isolates the feature cells. Open `comparison.png` for the labeled rows. Read the columns from left to right as triangle, clipped rectangle, translated rectangle, text, owned bitmap and unresolved resource. Each fixture also yields the command stream, reference images, original SVG, Cairo PNG and PDF. The SVG reference is rasterized by librsvg, which itself uses Cairo. It compares two command translations on a shared raster engine.

## Observed result

The retained [comparison](evidence/comparison.png), [feature PDF](evidence/feature-cells.pdf) and [measurements](evidence/observed.json) came from macOS 27.2.1 arm64, Mojo 1.1.0 (8189361e), Cairo 1.18.6 and librsvg 2.63.2. The build used the same-revision main checkout's existing Pixi environment via `MOXI_PIXI_MANIFEST`, with the source include path pointing at this experiment's checkout.

| Canonical scene | Commands | Cairo RGB mean absolute error vs software | vs Canvas | vs SVG |
|---|---:|---:|---:|---:|
| Portable primitives | 10 | 18.240 | 31.233 | 31.071 |
| Dark theme | 7 | 7.478 | 11.448 | 8.704 |
| Light theme | 7 | 10.109 | 16.610 | 11.896 |
| Plot gallery | 67 | 3.300 | 4.164 | 1.922 |

The error averages absolute per-channel differences over the entire image on a 0–255 scale. It excludes alpha. The replay checks dimensions, command/fallback counts and both checksums against the repository's parity table. The canonical software-error ceiling of 25 is a regression guard calibrated on this run. In a negative control, replacing the feature stream’s transform with a reset made the replay exit nonzero on translation alone.

| Backend | Triangle | Clip | Translation | Text ink | Owned RGBA |
|---|---|---|---|---|---|
| Software | Bounds fill | Pass | Pass | Blank | Blank |
| Canvas | Pass | Pass | Pass | Blank | Blank |
| SVG via librsvg | Pass | Pass | Miss | Pass | Blank |
| Cairo PNG and PDF at 4× | Pass | Pass | Pass | Pass | Pass |

The PDF check uses MuPDF to extract drawings, text and an image, rasterize at four pixels per point and repeat the cell checks. It also compares diagonal edge detail against nearest-neighbor enlargement of the PNG. Resource ID 17 has no supplied pixels. Cairo reports that ID and leaves its cell blank. Text ink tests basic placement and visibility only. Font choice, multilingual shaping and text layout remain open.

## Cost and adoption gate

The 91 canonical commands plus 11 feature commands exercise 13 adapter opcodes. The experiment requires an 81-line Mojo command encoder (including its trailing separation) and a 133-line Python Cairo adapter, alongside the existing renderers. No existing renderer code was removed. One drawing function serves PNG and PDF. The five output sizes are recorded in the JSON. These are measured code and artifact costs, not estimates of engineering time.

Confidence is high for the observed cells and moderate for deferring integration. Revisit if a consumer needs a general Scene PDF and a maintained adapter can handle resource resolution, styled/shaped text, curve paths, offscreen composition and native dependency packaging on supported hosts. The path experiment covers move/line/close only. The typed encoder rejects unsupported Scene kinds, and replay fails on unimplemented path verbs. Linux, GPU/native display parity, throughput and production packaging were untested.
