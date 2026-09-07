# Ecosystem support matrix

| Surface | Status | Evidence | Policy |
| --- | --- | --- | --- |
| Mojo scene IR | stable | `pixi run test`, typed scene contract | backend-neutral contract; version changes require migration notes |
| Canvas raster/export | stable subset | `pixi run canvas-scene`, `pixi run canvas-benchmark` | typed paths and isolated layers are supported; text/images and legacy string paths report fallbacks |
| Software renderer | stable oracle | `pixi run test`, visual corpus | deterministic bounds/path oracle; it does not invent glyph or image pixels |
| SVG export | stable | `tests/svg.mojo`, scene parity fixtures | structural output is canonical for browser export |
| Metal scene renderer | stable native lane | native scene parity and screenshot checks | native glyph/resource pixels remain platform-dependent |
| Python package | stable MVP / extension lane experimental | `pixi run python-check`, `tests/python` | no Mojo compiler at import time; NumPy/pandas optional |
| dataviz_mojo overlap | core six implemented | `pixi run dataviz-parity`, `tests/python/test_python_api.py` | PlotSpec and core mark recipes are absorbed; reference-only waves stay explicit |
| dataviz_mojo full mark catalog | planned by wave | `docs/dataviz-capabilities.tsv` | no silent aliases; each promoted mark needs schema, scene, parity, and accessibility evidence |

## Version support

The Python package supports CPython 3.9+ and the current Mojo nightly pinned in `pixi.toml`. The Python lane is intentionally independent of the Mojo compiler runtime. Mojo package consumers resolve the pinned Canvas fork through Pixi; public-channel upload still requires release credentials.
