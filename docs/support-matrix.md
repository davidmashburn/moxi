# Ecosystem support matrix

| Surface | Status | Evidence | Policy |
| --- | --- | --- | --- |
| Moxi core package | installable | `pixi run package-consumer`, `pixi publish` | Mojo package for the `moxi` core; release versions stay aligned with sibling packages |
| Moxi Plot package | installable provisional | `pixi run package-consumer`, `pixi publish --path packages/moxi_plot/pixi.toml` | Separate package depending on the published `moxi` and Canvas packages; plotting remains provisional |
| Moxi Demo package | source-only | `pixi run demo`, `pixi run demo-browser` | Showcase sources are not part of the installable compatibility surface |
| Mojo WebAssembly package | blocked by pinned compiler target set | `pixi run web-package-check`, `pixi run web-package-required` | The host lifecycle/ARIA harness is real; do not label it a Mojo Web runtime until a Mojo WASM target and package ABI are available |
| macOS AppKit host distribution | source-only | Native demo build tasks compile `native/macos_window.m` | Installing the Mojo packages alone does not supply the Objective-C host; external native consumers must explicitly obtain and link a matching host source or object |
| Linux GTK4 retained host | source-only, provisional | `pixi run --locked linux-layout-check`, `pixi run --locked linux-layout-workbench`; Ubuntu VM native contracts, app compilation and synthetic X11 interactions | GTK4/Cairo present retained labels, buttons, single-line editors and canvas leaves; Pango owns paragraph shaping/bidi while Mojo owns layout and retained state. Stable Mojo 1.1.0 VM GUI checks passed. AT-SPI proxies and the desktop clipboard are implemented and checked through an external client; spoken screen-reader traversal, legacy widget parity, rich text, GPU acceleration and incremental rendering remain unverified or unavailable |
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

The Python package supports CPython 3.9+ and is intentionally independent of the Mojo compiler runtime. The Mojo workspace resolves `osx-arm64` and `linux-64`; `pixi run headless-check` is the portable package lane. The source-only Linux retained workbench uses GTK 4.14+ with Cairo/Pango and the pinned Kiwi solver. Its native contracts, app compilation and synthetic X11 checks passed in an Ubuntu 24.04 x86-64 VM with stable Mojo 1.1.0. External AT-SPI and Unicode clipboard checks also passed; these do not certify spoken screen-reader navigation. The GTK host supports X11/Wayland display selection, but the guest GUI lane targets X11 and does not establish Wayland acceptance. Mojo package consumers resolve the pinned upstream Canvas revision through Pixi; public-channel upload still requires a chosen channel and release credentials. `pixi run release-preflight` checks the core and plotting package publish plans without uploading. The demo package remains source-only.

Linux setup, commands and guest evidence are recorded in
[VM validation](vm-validation.md) and [the layout workbench guide](layout-workbench.md).

## Desktop host evidence

Implementation capabilities and acceptance evidence are separate. The optional
retained profile remains a candidate until its manual promotion checks pass.

| Lane | Portable contract | Host build | Linked runtime | Accessibility evidence | Input evidence |
| --- | --- | --- | --- | --- | --- |
| Headless | Frame/semantic publication, deadline driver and exact event replay pass | No toolkit required | Software form/collection/chart oracle passes | Stable semantic snapshots and action round trips | Normalized replay; no OS IME |
| macOS AppKit/CoreText | Shared frame/controller | Host and ARM64 VM compile | Candidate and independent installed consumer pass | Native AX hierarchy/flags; semantic-only publication does not present | Native field-editor contracts; VoiceOver, Japanese IME and physical horizontal scrolling remain manual gates |
| Linux GTK4/Cairo/Pango | Shared frame/controller | Ubuntu 24.04 x86-64 VM compile | Actual X11 workbench and native contracts pass | External AT-SPI hierarchy, text/caret/selection, focus, bounds and actions pass; Orca speech unverified | GTK input/scale/lifecycle and cross-process clipboard pass; real IME evidence recorded separately in VM validation |
| Linux Wayland | Same portable contract | GTK host supports display selection | Not exercised | Not exercised | Not exercised |
| Windows | Portable descriptor | Native backend absent | Not exercised | Not exercised | Not exercised |

The [host/frame ADR](architecture/adr-005-host-frame-contract.md) records ownership.
[VM validation](vm-validation.md) records source provenance and distinct GUI,
IME, service and performance observations. Linux TCG timings are a descriptive
VM baseline, not a native 60 Hz performance claim.
