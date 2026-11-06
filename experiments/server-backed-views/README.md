# Million-point server-backed Moxi view (P02)

This local experiment renders a million-point density explorer using the actual
`App[Density]`, Moxi event dispatcher, scene renderer and accessibility snapshot
compiled from Mojo to Wasm64. Moxi owns camera/drag/zoom, aggregate selection,
exact-selection IDs and the visible pending/error state. JavaScript connects
`MoxiWebHost`, validates transport messages and schedules bounded data requests.
It does not replace Moxi with a JavaScript plot.

The preserved `probe.py` remains the independent, in-process 64×64 contract
probe. The interactive view uses **32×32** cells (1,024), with a 64KiB response
cap; exact records have a **separate 32-record cap**. The reducer scans all one
million deterministic points; this is not an indexed or production service.

## Build and run

From this checkout, use the pinned Pixi environment, or reuse an already installed
identical environment without modifying its sources:

```sh
export MOXI_PIXI_MANIFEST=/path/to/installed/moxi/pixi.toml
bash experiments/server-backed-views/build.sh > /tmp/moxi-p02-build.log 2>&1
python3 experiments/server-backed-views/server.py --port 8766 > /tmp/moxi-p02-server.log 2>&1
```

Open `http://127.0.0.1:8766/experiments/server-backed-views/` in a memory64-capable
Chromium browser. The build requires Mojo 1.1.0 (`8189361e`), Apple Clang 21.0.0
(`clang-2100.3.34.2`) and LLD 24.0.0. It reuses P01's **experimental** LLVM
retargeter, runtime allocator/handle registry and Moxi host unchanged. This is
not an official Mojo browser target or a general Moxi web backend. Missing
Wasm, unsupported memory64, transport errors and compiler failures stay visible.
No JavaScript rendering fallback is provided.

Drag A's grid to pan and wheel to zoom. Select 3000ms delay, pan, and observe the
previous grid move immediately while Pending remains visible. Release and wait
for Fresh reduction. Click a density cell, then Exact records to fetch up to 32
stable IDs/coordinates. The aggregate total is distinct from those IDs. Pan again:
exact IDs and the selected world rectangle persist for the unchanged revision.
Clicking any aggregate again clears its previous exact selection.

Disconnect simulates loss in A's local transport control. Reconnect / retry
resends its last operation. The browser check additionally disables the actual
browser network, producing a real failed fetch. Dispose tears down the Moxi
owner and transport; Restart view fetches current metadata and creates a new
session/handle with empty selection. B has a separate session and camera.
After a backend restart with unchanged data, retry works. Changed source bytes
produce a different revision and require Restart view; there is no implicit ID
migration across revisions.

The full-data baseline is `?route=full`: A fetches the same 20,000,000 source bytes,
verifies their SHA-256 in a worker and reduces them locally. It uses the same
Moxi component and gestures. B stays a server view; the measurement sweep disposes
B before collecting route-specific memory/timing samples. Full-data reducers
have no artificial network delay. See [EVIDENCE.md](EVIDENCE.md) for measured limits.

## Contracts and focused checks

```sh
python3 experiments/server-backed-views/probe.py > /tmp/moxi-p02-probe.log 2>&1
python3 experiments/server-backed-views/test_server.py > /tmp/moxi-p02-server-tests.log 2>&1
node experiments/server-backed-views/adapter-check.mjs > /tmp/moxi-p02-adapter.log 2>&1
```

`build.sh` also runs a native/Wasm fixture and 20 disposal/recreation cycles.
Native and Wasm SVG text/structure must match, geometry within 0.0002 pixels and
8-bit color channels within one unit (host floating-point contraction differs).
These are numerical rendering checks, not native-window or screen-reader tests.

Each adapter has at most one active operation and one replaceable pending
operation, shared by density and exact-detail requests. Cancellation posts a
real loopback request; the active slot stays occupied until the query resolves.
The server's delay wait wakes immediately and its reducer checks cancellation
every 4,096 records. A bounded 256-entry, 30-second tombstone map handles
cancel-before-start. The server allows eight concurrent sessions and one query
per session; no job/session registry grows forever. Worker reduction yields
every 16,384 records to service cancellation. Histories retain at most 120 samples.

Only matching session, immutable dataset SHA-256 revision, query UUID, generation,
kind, viewport and validated bounded payloads can replace the displayed result.
Camera changes run through Moxi and submit the transformed previous SVG before
starting asynchronous work. Latest request wins across details and grids. Stale
or failed operations never clear the retained grid. Source coordinates appear
only in the explicit full-source route and separately requested capped details.

The loopback listener rejects foreign Host/Origin values and exposes only this
experiment's static dependencies and local endpoints. It is not an authenticated
service, a public server, a notebook adapter, or a general query framework.

## Reproduce the real browser slideshow and measurements

Keep the server running. The repository's optional Playwright workflow uses an
installed Chrome, without adding dependencies to the project:

```sh
npm install --prefix /tmp/moxi-p01-tools playwright@1.56.1 --ignore-scripts
export MOXI_PLAYWRIGHT_MODULE=/tmp/moxi-p01-tools/node_modules/playwright/index.mjs
export MOXI_CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
node experiments/server-backed-views/browser-check.mjs > /tmp/moxi-p02-browser.log 2>&1
# P02-only gallery when other demos' ignored PNGs are absent:
mkdir -p /tmp/moxi-p02-gallery
ln -sfn "$PWD/artifacts/demo-slideshows/server-backed-views" /tmp/moxi-p02-gallery/server-backed-views
python3 scripts/demo_slideshows.py /tmp/moxi-p02-gallery --check
python3 scripts/demo_slideshows.py /tmp/moxi-p02-gallery
python3 tests/demo_slideshows_test.py
# Once all other captures are restored, build the shared root:
python3 scripts/demo_slideshows.py --check
python3 scripts/demo_slideshows.py
```

The script sends real browser pointer/wheel gestures and captures nine distinct
states: initial, pan pending with retained data, fresh result, aggregate selection,
capped exact records, actual network failure, retry recovery, disposal while
pending, and restart with two views. It also intercepts one real HTTP reply with
a wrong session to verify rejection. The 0/150/600/1800ms sweep uses fresh pages
and identical pan/zoom actions for both routes and asserts identical resulting
viewports and every grid count.

`artifacts/demo-slideshows/server-backed-views/manifest.json` uses the version 1
shared gallery schema. Its committed-source requirement remains an integration
gate until the parent commits and recaptures. `capture-provenance.json` records raw capture state,
source-input digest, Wasm hash and screenshot hashes separately. The manifest
explicitly labels this **uncommitted** implementation relative to the base commit;
the revision field is the integration base, not the implementation commit. The
parent must commit and recapture to satisfy committed-source provenance. `comparison.json` contains raw measurements, not a performance promise.
PNG/HTML files and `dist/` remain ignored local artifacts; reproduce them before
running gallery validation in a clean checkout. Full build and check logs are in
`/tmp`. Collaborative preview was used for inspection; repeatable timed captures
use the repository's documented scripted-browser workflow.
