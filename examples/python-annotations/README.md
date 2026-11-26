# Python annotation exports

Run from the repository root; the examples use the checked-in Wave B/C column
fixtures and E06 source-inspector inputs. No compiler or rendering dependency is
needed by the exporter.

```sh
PYTHONPATH=python python3 examples/python-annotations/render.py /tmp/moxi-labels/narrow --width 320 --height 240
PYTHONPATH=python python3 examples/python-annotations/render.py /tmp/moxi-labels/wide --width 960 --height 480
```

Use `--family sankey` (or another listed family) for one example. Each writes an
SVG, software PNG and vector PDF. All three share E01's seven-pixel text cells,
bitmap PNG glyphs and Courier/WinAnsi PDF text. SVG uses monospace text. Appearance
and antialiasing differ; this is content and placement parity, not font fidelity.
Characters outside the small bitmap font or WinAnsi still use the existing `?`
fallback in PNG/PDF. SVG retains the original characters.

Calendar weekday/month headers, Sankey node names, parallel dimension names,
bump ranks/stages and arc node names use existing SVG label anchors. Text is
fitted to the viewport and overlapping labels are sampled; full inputs and source
row identities remain in the table. Annotation ink does not add selection targets.

The Wave B mapping follows dataviz_mojo revision
`3fd5a7e7c622d6130c99a290b88c4fee039deab2`: category legends for pie/donut,
polar bar, nightingale and radialbar; indicator and series names for radar;
one-decimal measurement for gauge (including values outside the needle's clamped
range). Category/series legends use Moxi's bottom margin and palette, without
resizing the marks. There are no invented wedge percentages or numeric polar ticks.
The single-series polar fixture has no labels at the pin. Funnel and other catalog
families without existing visible SVG label anchors are outside this change.

Focused checks (verification-only dependencies):

```sh
python3 -m pip install pytest pillow pypdf pymupdf
PYTHONPATH=python python3 -m pytest -q tests/python/test_annotation_parity.py
```

The checks decode actual PNGs, inspect PDF text, independently rasterize PDFs
with MuPDF, compare geometry/selection and exercise narrow/wide exports. Optional
verification dependencies are skipped explicitly by pytest when unavailable.
These headless export checks do not establish native host or physical input parity.
