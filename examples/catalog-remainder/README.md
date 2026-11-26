# E06 source inspectors

Each directory contains a Mojo replay through PlotView. The browser replay displays a Python Moxi SVG and uses the same live Figure for pointer hit testing. Escape clears the source-table selection.

## Reproduction

From the repository root, with Chrome installed, create a Python environment with Playwright and pytest. Mojo uses the repository's pinned pixi environment. For each family, run the following with its name assigned to `family`.

```sh
family=parallel
root=$PWD
out=$(mktemp -d)
(cd "$out" && pixi run --manifest-path "$root/pixi.toml" mojo run -I "$root/src" "$root/examples/catalog-remainder/$family/main.mojo")
PYTHONPATH=python python examples/catalog-remainder/replay.py "$family" "$out/native.svg" "$out/gallery"
PYTHONPATH=python python -m pytest -q tests/python/test_catalog_remainder.py
PYTHONPATH=python python scripts/plot_catalog/check.py
pixi run mojo run -I src examples/catalog-remainder/legacy.mojo
```

Add `--inspect` to the replay command to explore the live chart and source table at the printed loopback URL. Ctrl-C stops the server.

The legacy checks exercise the default row layout, including nine native clicks across these three families. Each linked offline gallery includes the original PNG captures beside its index. Captures use a synthetic fixture, macOS arm64, headless Chrome, a 1100 × 540 viewport at scale 1 and a 640 × 420 figure. The enclosing Git commit identifies the implementation revision. The comparison uses the checked-in SVG from dataviz_mojo revision `3fd5a7e7c622d6130c99a290b88c4fee039deab2`. The original reference driver is in `scripts/plot_catalog/reference.mojo`. Replays use dispatched pointer input and the native offscreen Scene. Physical input and other hosts remain unverified.

## Parallel coordinates

[Open the parallel coordinates slideshow](../../artifacts/demo-slideshows/e06-parallel/index.html). One source row represents one record. Set x to its identifier, y to its first dimension and series_fields to the ordered remaining dimensions. The fixture crosses at two positions. Both exports match the ordered vertices of each upstream path, and both record identities survive pointer selection. Constant dimensions map to the vertical midpoint. The Python and Mojo checks also exercise opposite floating-point extremes and adjacent integers above 2⁵³. Python SVG and native Scene include dimension labels. The Python software PNG and PDF render geometry without text. Moxi uses its own margins, colors and legend treatment.

## Bump rankings

[Open the bump slideshow](../../artifacts/demo-slideshows/e06-bump/index.html). Use the same wide series rows as parallel coordinates. Each stage sorts scores in descending order, retaining input order for ties. The fixture exchanges ranks twice. Both normalized traces match the pinned geometry. The Mojo replay picks all four segments by stable key and repeats the ranking after a tie. The Python replay selects both original table rows. The Python test also separates adjacent integers above 2⁵³. SVG and native Scene include rank and stage labels. PNG and PDF cover geometry.

## Arc diagram

[Open the arc diagram slideshow](../../artifacts/demo-slideshows/e06-arc-diagram/index.html). Set x and x2 to named source and destination columns and y to nonnegative weight. Node order follows first appearance across the source column, then the destination column. Self-loops retain their table row and omit the edge. The fixture connects A→C, B→A and C→B. Both Moxi renderers approximate each semicircle with 48 line segments. The comparator checks every vertex against the reference circle and checks endpoints and stroke widths for all three edges. Native clicks at the three apexes return keys 10, 11 and 12. SVG and native Scene include node labels. The Python PNG and PDF exports contain unlabeled geometry.

[Browse all three galleries](../../artifacts/demo-slideshows/e06/index.html). Each capture directory includes the native and Python SVG, Python PNG and vector PDF, original screenshots and a capture manifest with the browser version, capture time and SHA-256 hashes of the replay and rendering sources.

## Verified fixture results

| Family | Geometry compared in both SVG backends | Native pointer replay | Browser source-table replay |
| --- | --- | --- | --- |
| Parallel | Two ordered, three-vertex traces | Four segment clicks, keys 10 and 11 | Selected East and West, then cleared with Escape |
| Bump | Two ordered, three-stage rank paths | Four segment clicks, keys 10 and 11 | Selected East and West, then cleared with Escape |
| Arc diagram | Three stroke weights and 49 circular vertices per edge | Three apex clicks, keys 10, 11 and 12 | Selected all three original edges, then cleared with Escape |

On macOS arm64, Chrome opened all three galleries from the local index with networking disabled. Each gallery displayed eight slides and supported thumbnail, button and keyboard navigation. Each Python PDF had one 640 × 420 page. Rasterizing it at 72 dpi and comparing saturated PNG trace pixels with PDF ink at the same coordinates gave 99.9% overlap for parallel and 100% for bump and arc diagram, rounded to one decimal place. This check covers ink placement for these fixtures. Text and antialiasing differ across export formats.
