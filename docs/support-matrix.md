# Ecosystem support matrix

| Surface | Status | Evidence | Policy |
| --- | --- | --- | --- |
| Mojo scene IR | stable | `pixi run test`, typed scene contract | backend-neutral contract; version changes require migration notes |
| Canvas raster/export | stable subset | `pixi run canvas-scene`, `pixi run canvas-benchmark` | typed paths and isolated layers are supported; text/images and legacy string paths report fallbacks |
| Software renderer | stable oracle | `pixi run test`, visual corpus | deterministic bounds/path oracle; it does not invent glyph or image pixels |
| SVG export | stable | `tests/svg.mojo`, scene parity fixtures | structural output is canonical for browser export |
| Metal scene renderer | stable native lane | native scene parity and screenshot checks | native glyph/resource pixels remain platform-dependent |
| Python package | stable MVP / recipe wave | `pixi run python-check`, `tests/python` | no Mojo compiler at import time; NumPy/pandas optional |
| Moxi recipe wave | implemented value-boundary transforms | `tests/python`, `pixi run python-benchmark` | histogram, density, ECDF, regression, hexbin, and error bars; native interaction/accessibility promotion remains explicit |
| dataviz_mojo overlap | core six plus histogram recipe | `pixi run dataviz-parity`, `tests/python/test_python_api.py` | PlotSpec and core mark recipes are absorbed; reference-only waves stay explicit |
| dataviz_mojo full mark catalog | row-native static catalog lane | `pixi run dataviz-parity`, `tests/python`, `docs/dataviz-capabilities.tsv` | all catalog names share PlotSpec, static scene/export, row anchors, and benchmark evidence; common interval/sector/edge families have deterministic geometry; nested upstream layouts remain a separate promotion lane |

## Version support

The Python package supports CPython 3.9+ and the current Mojo nightly pinned in `pixi.toml`. The Python lane is intentionally independent of the Mojo compiler runtime. The Mojo workspace resolves `osx-arm64` and `linux-64`; `pixi run headless-check` is the portable package lane, while native Linux host support remains unavailable. Mojo package consumers resolve the pinned Canvas fork through Pixi; public-channel upload still requires a chosen channel and release credentials. `pixi run release-preflight` checks both target packages without uploading.
