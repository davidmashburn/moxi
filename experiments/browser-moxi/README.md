# Actual Moxi browser runtime experiment

This P01 experiment compiles the existing FDG `App[GraphApp]`, solver, Moxi event
dispatch, view/paint pipeline, SVG renderer, and accessibility snapshot to
Wasm64. JavaScript supplies runtime imports and connects the existing
`MoxiWebHost`; it does not implement the graph solver or scene.

The [shipped contract and measured limits](../../docs/browser-moxi-runtime.md)
define the experimental subset. This is **not** an official Mojo web target.
The earlier independent solver probe in `experiments/browser-execution` remains
separate and unchanged; this experiment can run without that directory.

## Build and check

Run from the repository root on Apple Silicon with the pinned environment:

```sh
pixi install
bash experiments/browser-moxi/build.sh > /tmp/moxi-p01-build.log 2>&1
cat experiments/browser-moxi/dist/check.json
cat experiments/browser-moxi/dist/runtime-check.json
```

Required tools are Mojo `1.1.0 (8189361e)`, Apple Clang
`21.0.0 (clang-2100.3.34.2)`, LLD `24.0.0`, Python 3, and a memory64-capable
Node (validated with `26.10.0`). `build.sh` refuses unvalidated compiler versions.
It records the direct-target failure separately, emits host LLVM, audits and
retargets it, links the actual application, generates independent native
fixtures, and runs runtime and application checks. Artifacts are in ignored
`dist/`; compiler-target logs remain available even when the direct target fails.

To reuse an already installed identical environment, set
`MOXI_PIXI_MANIFEST=/absolute/path/to/other/moxi/pixi.toml`. The script still
compiles this checkout's sources. No installation or source copy into the
other checkout is needed.

## Run and reproduce the screenshots

In one terminal:

```sh
python3 experiments/browser-moxi/serve.py --port 8765
```

Open `http://127.0.0.1:8765/experiments/browser-moxi/` in a memory64-capable
Chromium browser. Both panes start paused after 100 actual solver steps and Fit.
Use Moxi's Resume/Reheat controls to animate. Select and drag a node, drag empty
canvas to pan, wheel to zoom, and use arrows to change selection. Click the
Moxi search field, type `node-12`, and press Enter. The visible HTML search
helper also forwards text/actions into Moxi. Resize, dispose, and recreate A
using the host buttons. Verify runs the same native parity/lifecycle fixture
inside a separate Wasm module. `?unsupported` forces a clearly labeled feature
failure, not a successful fallback.

For deterministic captures and assertions, install the optional automation tool
outside the repository, then run against that server:

```sh
npm install --prefix /tmp/moxi-p01-tools playwright@1.56.1 --ignore-scripts
MOXI_PLAYWRIGHT_MODULE=/tmp/moxi-p01-tools/node_modules/playwright/index.mjs \
MOXI_CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
node experiments/browser-moxi/browser-check.mjs > /tmp/moxi-p01-browser-check.log 2>&1
```

`MOXI_CHROME` selects an installed Chrome executable; without it, Playwright
requires its separately installed Chromium. `MOXI_DEMO_URL` can override the
loopback URL. Automation launches a fresh headless profile, not the user's
logged-in browser. Captures use 1440×1100 CSS pixels at scale 1 and include the
full document. Assertions inspect actual Mojo state after real browser inputs.

Open the [gallery index](../../artifacts/demo-slideshows/index.md) and generated
[self-contained slideshow](../../artifacts/demo-slideshows/browser-fdg/index.html).
The eight original PNGs and raw `paint-trace.json` stay alongside it. The compact
manifest and evidence JSON are reviewable repository files. The script records
the base source revision plus working-source and Wasm hashes; uncommitted
implementation evidence is labeled explicitly rather than assigned a fake
commit. See the [capture notes](../../artifacts/demo-slideshows/browser-fdg/README.md)
for the collaborative-preview fallback and each scenario.

## Files and integration

- `browser.mojo`: bounded exported application ABI, input validation, lifecycle,
  Moxi scene and semantics transfer.
- `runtime.mjs`: handle registry, bounded allocator, audited imports, feature
  gate, trap poisoning, and JS owners.
- `retarget.py`, `test_retarget.py`, `runtime-check.mjs`: narrow IR conversion
  and independent executable tests of the new compiler/runtime operations.
- `native.mojo`, `verify.mjs`, `check.mjs`: independent native oracle and the
  same state/render/lifecycle checks in Node and browsers.
- `demo.mjs`, `index.html`, `browser-check.mjs`: actual host wiring, interactions,
  measurement, and reproducible captures.

No core, native host, FDG, notebook, or server transport code is changed. Reuse
commits `ea99901` and `d642bff` can be integrated independently; this does not
overwrite their probes or supersede their independent measurements.
