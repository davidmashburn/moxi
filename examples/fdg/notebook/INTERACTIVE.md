# Inline FDG notebook (P04)

This example runs the **actual Mojo FDG solver, `App[GraphApp]`, Moxi event
routing, view construction and SVG renderer** inside one Wasm64 instance per
output. JavaScript handles notebook integration, browser input and bounded comms;
it does not implement a substitute solver or graph scene. P01 remains unchanged.
P02 informs the latest-state queue and generation checks; this bounded local graph
does not need its million-point query server. P03's notebook and helpers remain
independent. There is no P05 general adapter or shared chart/canvas change.

## Run

Use the pinned P01 toolchain (Mojo 1.1.0 `8189361e`, Apple Clang 21.0.0
`clang-2100.3.34.2`, LLD 24.0.0) and memory64-capable Node/Chrome. Build scripts
reject other compiler versions. From the repository root:

```sh
uv venv --python 3.13 /tmp/moxi-p04-venv
uv pip install --python /tmp/moxi-p04-venv/bin/python \
  -r examples/fdg/notebook/requirements-interactive.txt
# Optional: export MOXI_PIXI_MANIFEST=/path/to/identical/moxi/pixi.toml
bash experiments/browser-moxi/build.sh > /tmp/moxi-p04-build.log 2>&1
python3 examples/fdg/notebook/prepare_interactive.py > /tmp/moxi-p04-prepare.log 2>&1
/tmp/moxi-p04-venv/bin/jupyter lab examples/fdg/notebook/interactive.ipynb
```

Use that environment's Python kernel. Run all three code cells. A uses the
77-node/254-link synthetic benchmark; B uses 256 nodes/1,024 links. Both use
`groups[i] = i % 6`, edge `i % n → (7*i+1) % n`, weight 1, from
`examples/fdg/tests/benchmark.mojo`. The initial view takes 100 real solver steps,
fits and pauses. P01's default graph is 36/71, so this example supplies both
benchmark graphs explicitly.

Drag nodes; drag empty graph space to pan; wheel to zoom; click Resume/Pause or
press Space over the output. Escape, lost pointer capture, browser blur and
pointer cancellation release a drag. Arrow keys select through Moxi. The notebook
controls and the Moxi Export SVG action download the current Moxi SVG. Unsupported
browser compilation/runtime paths show a diagnostic and retain the static view.

Use one `InlineFDG(slot="stable-cell-name")` per output and call `.show()`.
Rerunning the same slot closes its predecessor; a different slot creates isolated
state. Re-displaying the *same* widget object simultaneously is deliberately not
supported; it would need an explicit shared-state policy. Mutating Python's input
dictionary after creation does not update the view; rerun the cell. Recovery starts
a new settled graph, not an implicit checkpoint restoration.

## Widget choice and source investigation

The frontend is **JupyterLab 4.4.10**, retained from P03. The optional environment
pins anywidget **0.9.21**, ipywidgets **8.1.8**, and jupyterlab_widgets **3.0.16**.
The capture report records resolved transitive versions and source hashes.

| Choice | Evidence and decision |
| --- | --- |
| Raw kernel comm + HTML/JavaScript output | Needs a frontend-owned route to the kernel and explicit output disposal. Classic Notebook's `Jupyter.notebook.kernel` is not the pinned Lab frontend contract. Avoid dependence on `window.jupyterapp` in shipped widgets; that exposed app is used only by browser tests. |
| Custom ipywidgets `DOMWidgetModel`/`DOMWidgetView` | Uses the installed Lab widget manager, but a new frontend module requires its own packaging/registration. Suitable for a distributed adapter, unnecessary for this example-local spike. |
| anywidget on the same widget manager | Selected. Ships its Lab extension, accepts ESM as a synchronized string, supports `model.send`/`msg:custom`, and calls a render-returned cleanup on view removal. Assets travel through Jupyter's existing authenticated comm; no extra HTTP server, CDN import, kernel-local URL, browser compiler or WebSocket endpoint. |

The investigation inspected installed `anywidget/widget.py` (`AnyWidget` extends
`ipywidgets.DOMWidget`, synchronized ESM and widget MIME model reference), and
`anywidget/nbextension/index.js` (`create_view` and `AnyView.remove`). In 0.9.21,
`remove()` aborts the view controller and `create_view` invokes returned cleanup,
including when rendering completes after an abort. The installed Lab extension
uses that same implementation. Capture metadata hashes both extension artifacts.
The [widget guide](https://anywidget.dev/en/jupyter-widgets-the-good-parts/)
explains the custom-message API and traditional-widget packaging difference.
The [current AFM specification](https://anywidget.dev/en/afm/) describes 0.11;
its newer `signal`/`host`/`exports` API was **not** assumed available in 0.9.21.

Confidence in this local choice is high: real Lab/Chrome comm, clear, rerun and
restart tests exercise the installed extension. A changed widget-manager cleanup
contract, frontend packaging requirement or measured SVG cost can change the
choice. No cross-frontend or remote compatibility claim follows from this test.

## Ownership, protocol and limits

The browser owns layout, selection, drag, pan/zoom, pause and rendering. Python
owns the output identity and a bounded interaction summary/lease, never a replayed
pointer stream. An acknowledged version-1 `hello` precedes runtime creation.
Messages contain `v`, random `session`, increasing slot `generation`, random
`view`, increasing `seq`, and a named `kind`: `hello`, `state`, `ping`, `dispose`,
`ack`, or `error`. Client state has only selected node, pause, pan, zoom, dragging
and cumulative release count. Python validates exact fields, finite ranges,
identity, type, sequence and monotonic releases before changing its summary.
Old output events cannot mutate a replacement; ACKs must match the outstanding
sequence and all identities. Frames never cross the kernel comm: the owning
runtime and render closure define their session/generation, with an epoch check
for asynchronous compilation and measurement callbacks.

Limits: 256 nodes, 1,024 links, P01's 64 MiB Wasm memory per output; scene dimensions
640–4,096 by 320–4,096 CSS units, scaled to the actual surface for hit testing;
4,096 bytes per custom message; 2 MB per startup asset; 20 Hz state sends; one
in-flight message plus one latest snapshot; one coalesced pointer move per browser
frame; 120 retained samples per metric. Cumulative release counts survive state
coalescing, and pointer-up consumes any final pending move synchronously. Every
release clears the real Mojo pin before transmission; backend dragging is only a
summary, not a resource owner. The Node channel check submits 10,000 updates while
an ACK is delayed and verifies the final release and two-slot bound.

The kernel heartbeat is 750 ms with a 4-second outstanding-message timeout.
Long-running kernel work beyond that interval intentionally stops the view; Retry
is explicit. Local gestures and SVG feedback continue immediately while an ACK is
pending. No unbounded pointer/event/frame history is buffered for later replay.
Hidden/background tabs may throttle timers; restart/failure detection is bounded
by browser scheduling plus that lease, not a hard wall-clock guarantee.

Clear output, view removal and explicit disposal cancel animation/measurement
callbacks, abort input listeners, disconnect the resize observer, release capture,
dispose the Wasm heap and unregister the custom-message callback. Rerun also
closes the preceding Python comm. Kernel restart closes comms or expires the
lease; backend failure stops the same runtime resources and exposes a Retry
control. `a.set_backend_available(False)` makes the real Python backend reject
messages; set it back to `True`, then Retry. No long-lived Mojo child process
exists. The fallback helper executes Node synchronously with a 30-second timeout
and reaps it before displaying the widget.

## Saved output and export

`.show()` emits the initial settled SVG as an independent HTML output, then the
widget output. Expand **Saved static SVG** even if the widget manager is absent,
the kernel is gone, or a saved notebook is reopened. This snapshot comes from the
same compiled solver/state/view via Node, at 1000×620. It is intentionally the
initial graph; use **Export current SVG** for the current selection/layout. The
fallback contains no executable script, local path or runtime asset URL. The
checked-in notebook contains no outputs or user data; executed notebooks,
WebAssembly, SVG downloads, paint traces, PNGs and HTML remain ignored/local.

## Verify and capture

```sh
/tmp/moxi-p04-venv/bin/python examples/fdg/notebook/check_interactive.py > /tmp/moxi-p04-python-check.log 2>&1
node examples/fdg/notebook/check_channel.mjs > /tmp/moxi-p04-channel-check.log 2>&1
/tmp/moxi-p04-venv/bin/python examples/fdg/notebook/capture_interactive.py > /tmp/moxi-p04-capture.log 2>&1
/tmp/moxi-p04-venv/bin/python examples/fdg/notebook/gallery_inline.py
```

The browser check starts an authenticated loopback-only Jupyter server on 8916
(`MOXI_NOTEBOOK_PORT` overrides it), opens installed Google Chrome in an isolated
headless profile, executes the actual notebook, and shuts down its server/kernel.
It extends P03's explicitly documented Playwright workflow. The T3 collaborative
preview is used first and contributes its own actual initial/selection captures;
the script supplies repeatable pointer-held, device-scale and Chromium trace tests.
No test substitutes DOM artwork or JavaScript solver results for the real app.
The capture-loss check establishes capture and sends a subsequent pointer event
after releasing it, following the [pending pointer capture rules](https://www.w3.org/TR/pointerevents/latest/#process-pending-pointer-capture).
A parent diagnostic observed no immediate loss event after release, then the real
`lostpointercapture` event and cleared Mojo pin on the next pointer movement.

[The manifest and evidence](../../../artifacts/demo-slideshows/fdg-inline-notebook/README.md)
record screenshots, source/binary hashes, versions, measured distributions and
limits. The gallery recipe checks source hashes before publishing local HTML.
Captures identify the source revision, scoped dirty state and content hashes, not an
invented implementation commit. Parent integration owns commits.

## Measurements and remaining gates

Report solver/layout dispatch, scene construction, SVG serialization, Wasm text
transfer, comm JSON serialization, actual comm roundtrip, DOM submission, Chromium
Paint trace events, input-to-DOM, and input-to-next-animation-frame separately.
Instrumented phase markers bracket P01's actual Moxi pipeline in generated local
source; shared P01 files are unchanged. Solver/layout includes frame dispatch and
Moxi invalidation. Scene includes control paint and graph scene assembly. SVG
serialization ends before semantics transfer. Paint is Chromium main-thread
`Paint` event duration, not GPU completion/display scan-out. Next-rAF latency is
also **not** a paint/compositor measurement. A local roundtrip includes browser,
Jupyter transport and Python handling; it does not isolate network-only latency.

**Remote gate remains unverified.** No real remote target was available and no
credentials were requested. To close it, run the optional Python/widget environment
and prepared assets on a genuinely separate kernel host, connect a memory64 browser
through that host's authenticated Jupyter frontend, and repeat all graph, delayed
comm, disconnect/retry, restart, saved-fallback and isolation checks. Record both
hosts, actual network topology/latency and a remote-session screenshot sequence.
A local server and separate localhost kernel process do not satisfy this gate.
The compiler build is currently validated only on Apple Silicon; use that validated
build's assets or establish new compiler evidence before claiming another build
platform. Other browsers, frontends, remote resource budgets and network behavior
are unverified. VoiceOver remains paused; physical input and independent usability
checks were not run. P05 extraction remains out of scope.
