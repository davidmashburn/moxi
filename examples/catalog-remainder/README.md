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
```

Each linked offline gallery includes the original PNG captures beside its index. Captures use a synthetic fixture, macOS arm64, headless Chrome, a 1100 × 540 viewport at scale 1 and a 640 × 420 figure. The enclosing Git commit identifies the implementation revision. The comparison uses the checked-in SVG from dataviz_mojo revision `3fd5a7e7c622d6130c99a290b88c4fee039deab2`. The original reference driver is in `scripts/plot_catalog/reference.mojo`. Replays use dispatched pointer input and the native offscreen Scene. Physical input and other hosts remain unverified.

## Parallel coordinates

[Open the parallel coordinates slideshow](../../artifacts/demo-slideshows/e06-parallel/index.html). One source row represents one record. Set x to its identifier, y to its first dimension and series_fields to the ordered remaining dimensions. The fixture crosses at two positions. Both exports match the normalized upstream segment endpoints, and both record identities survive pointer selection. Constant dimensions map to the vertical midpoint. Python SVG and native Scene include dimension labels. The Python software PNG and PDF render geometry without text. Moxi uses its own margins, colors and legend treatment.
