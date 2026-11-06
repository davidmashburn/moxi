# Linked plot notebook — P05 experiment

A distinct second consumer: assay dose/response scatter plot, linked record
selection, details, filtering and a keyboard-accessible table. The executable
builds real Moxi `PlotDataTable`, `PlotSpec`, `PlotRuntime`, `PlotSelection`,
`Scene`, accessibility snapshot and `SvgSceneRenderer` output. It has no FDG
imports, solver or renamed graph. JavaScript presents the returned SVG and
translates browser input; it does not calculate plot geometry or emulate Moxi.

## Run and install

Notebook dependencies remain optional and separate from Moxi core. Build on the
validated Apple Silicon Mojo environment; no public package or binary release is
implied. The Python wheel contains the example widget, not a compiler or native
binary. The binary is an explicit application asset; its build platform must
match the kernel host. A browser does not need Mojo, Node or Wasm64 for this plot.

```sh
# From repository root; MOXI_PIXI_MANIFEST may name an existing identical env.
sh examples/linked_notebook/build.sh > /tmp/moxi-p05-build.log 2>&1
uv venv --python 3.13 /tmp/moxi-p05-venv
uv pip install --python /tmp/moxi-p05-venv/bin/python \
  -r examples/linked_notebook/requirements-capture.txt build pytest
/tmp/moxi-p05-venv/bin/python -m build --wheel examples/linked_notebook
uv pip install --python /tmp/moxi-p05-venv/bin/python \
  examples/linked_notebook/dist/*.whl
export MOXI_LINKED_BINARY="$PWD/examples/linked_notebook/dist/moxi-linked"
/tmp/moxi-p05-venv/bin/jupyter lab examples/linked_notebook/linked.ipynb
```

Run the notebook in that environment's Python kernel. Both outputs have separate
state and identities. The public surface of this **example package** is small:

```python
from moxi_linked_notebook import LinkedPlot, sample_rows
view = LinkedPlot(slot="my-cell", rows=sample_rows(), binary="/path/to/moxi-linked")
view.show()
view.update(sample_rows()[:6])     # atomic replacement; new data generation
view.set_backend_available(False)
view.set_backend_available(True)  # then use Retry in the output
view.close()
```

A row has exactly `label`, `x`, `y`: 1–64 records, labels of 1–80 printable
characters, numeric finite coordinates within [0,100]. Booleans, NaN, infinity,
unsupported schemas, extra fields and out-of-range values are rejected. Keys are
input row indices and survive a filter. Replacing data assigns new keys in a new
data generation and clears selection. Titles and labels are text, never markup.
Direct CLI inputs have independent schema/range validation before Float32
conversion. Values are rendered with Moxi's existing Float32 precision.

## Ownership and bounded work

Python owns the output session, slot generation, dataset generation and applied
snapshot. The frontend owns the comm lease. A short-lived Mojo process reconstructs the application from
that snapshot, applies stable-key selection and a declarative filter, builds its
scene and reports the authoritative visible/selected keys. Python derives record
details from that key. Filtering away a selected record clears its details. A
failed update leaves the previous frame and data in place. No persistent Mojo
process, native window or extra network listener exists.

Each request uses the authenticated widget comm. Version 1 envelopes contain
`v`, `session`, `generation`, `view`, `seq` and a named `kind`. State adds exactly
`selected`, `minimum`, cumulative `finals`, and `dataVersion`. The backend rejects
unknown fields, stale identity/version/data, non-increasing sequences, regressing
final counters, pre-hello state and a second view of the same widget. ACKs carry
the matching identity/sequence and data generation. Old or pending-obsolete frames
cannot replace a newer frame. Create separate objects/slots for separate displays.

The client holds at most one outstanding request and one latest desired state.
Intermediate selections are deliberately coalesced, not replayed. The final
selection/filter and cumulative final-action counter survive coalescing. Requests
are at least 50 ms apart, heartbeats 750 ms, and an outstanding request expires at
4 seconds. Background browser scheduling can extend detection; this is not a hard
wall-clock guarantee. An unresponsive kernel fails the lease; Retry
reconciles the backend’s last applied state. Unsent pending input is dropped; an
already-sent request can still apply after the lease expires. Short busy
periods preserve final intent. IPykernel may handle comms concurrently while
executing user code, so a long execution alone does not imply a timeout. The local
integration test pauses its own kernel process to exercise a genuinely
unresponsive backend, then resumes it in `finally`. Each native invocation has a 2-second deadline;
`subprocess.run` kills and reaps the direct child on timeout. Client messages are
capped at 4 KiB, frames at 128 KiB, and timing samples at 120 per phase.

The browser owns immediate pointer preview and keyboard focus. Plot geometry and
acknowledged selection remain Moxi-owned. Preview circles use Moxi's returned
screen coordinates. Pointer up commits a final selection; pointer cancel/lost
capture/blur release the preview without selecting. There is no pan, zoom, brush,
dragged record, animation loop or stream of queued pointer events in this consumer.
SVG uses a fixed 720×360 viewBox scaled by the actual CSS rectangle, so picking
uses CSS coordinates independently of DPR. Narrow layouts stack details and wrap
controls; the table scrolls independently. SVG fragment IDs are scoped per output
and per saved copy to prevent document-global clip collisions. Existing Moxi
plot scenes clip axis labels to the data area; this consumer widens that scene
clip to its application canvas before SVG rendering. Its bounded coordinates
and lack of pan/zoom make that local presentation adjustment sufficient. All
geometry and semantic nodes still come from Moxi; shared plotting is untouched.

Rerun of the same slot closes the prior comm; clear output and view removal cancel
listeners, capture, timers and the message callback. Explicit disposal does the
same. Kernel restart closes/expires the old session; rerun creates a new one.
A failed backend preserves the last plot and shows Retry. A running native request
is bounded by its deadline even if the frontend disappears before it returns.

## Keyboard, semantics and saved output

Tab reaches the filter, controls, plot group and one table record. Arrow keys,
Home and End move the table's roving focus without selecting. Enter/Space selects;
Escape clears. Acknowledged redraw restores focus to the same visible key or the
first remaining record. Removing all records moves table focus to the plot group.
Selection is exposed through the table button's `aria-pressed`, textual details,
SVG image label and live status. The selected-record details verify Moxi's actual
selected semantic node. This is a bounded semantic projection, not a general
translation of every Moxi accessibility role.

`.show()` emits a separate script-free initial SVG **and full visible record
table** before the widget. This persisted HTML MIME output remains useful without
a widget manager or kernel. It is the initial frame for that display, not an
implicit save of later interactions. Saved fallback testing reads the actual
notebook output and reopens it offline with JavaScript disabled. The source
notebook contains no outputs, paths, tokens or user records.

## Extraction decision

**General adapter extraction is deferred.** P04's remote-host gate remains open.
The exercised second consumer supports a concrete candidate seam: versioned
identity, one-flight/latest-state scheduling, heartbeat/retry, widget mount and
cleanup, and independent saved output. P04's browser-owned runtime sends bounded
state summaries; this consumer's kernel-owned runtime returns bounded full frames.
Their ACK/state payloads, recovery semantics and resource ownership differ. Sharing
those policy decisions now would obscure an unverified compatibility contract.

Application-owned here: assay rows, limits, PlotSpec, stable-key selection,
filtering, details/table projection, native executable and snapshot reconstruction.
Application-owned in P04: graph solver and gestures, Wasm64 heap, browser event
routing and graph summary. The optional wheel is a **locally installed example
consumer**, not a reusable Moxi adapter or public cross-frontend support claim.
No P01/P02/P03/P04 or shared plotting geometry files are changed. A future
extraction needs real remote evidence and a second ownership-aware adapter review.

## Verification and evidence

```sh
MOXI_LINKED_BINARY="$PWD/examples/linked_notebook/dist/moxi-linked" \
  /tmp/moxi-p05-venv/bin/python -m pytest -q examples/linked_notebook/tests
node examples/linked_notebook/tests/check_channel.mjs
```

The reproducible source-free workflow assembles a local consumer directory,
installs the wheel in a fresh environment and starts Jupyter there. The macOS
ARM64 bundle includes the executable and its three Mojo runtime dylibs, relocates
the executable rpath, ad-hoc signs that copy, and verifies actual dynamic-loader
paths. No source checkout or compiler is used by the installed consumer. This is
local runtime validation, not a reviewed binary distribution/release format.
Use Python `-I` for the capture driver so its directory cannot shadow the installed
package. The driver checks installed JS and runtime hashes. To co-display the
unchanged actual P04 FDG for isolation regression, prepare its existing assets:

```sh
python3 examples/fdg/notebook/prepare_interactive.py
/tmp/moxi-p05-venv/bin/python -I examples/linked_notebook/prepare_consumer.py \
  > /tmp/moxi-p05-bundle.log 2>&1
uv venv --python 3.13 /tmp/moxi-p05-clean
uv pip install --python /tmp/moxi-p05-clean/bin/python \
  -r examples/linked_notebook/requirements-capture.txt \
  /tmp/moxi-p05-consumer/*.whl
/tmp/moxi-p05-clean/bin/python -I examples/linked_notebook/capture.py \
  > /tmp/moxi-p05-capture.log 2>&1
/tmp/moxi-p05-clean/bin/python -I examples/linked_notebook/gallery.py
```

The capture runner uses its own loopback Jupyter server on port 8918 and shuts it
down in `finally`; change `MOXI_NOTEBOOK_PORT` if occupied. For an interactive
source-free notebook, launch from `/tmp/moxi-p05-consumer` with
`MOXI_LINKED_BINARY=/tmp/moxi-p05-consumer/moxi-linked` and run
`/tmp/moxi-p05-clean/bin/jupyter lab linked.ipynb`.

T3 collaborative preview is exercised first. The documented P03/P04 Playwright
workflow supplies repeatable installed Chrome headless captures, held-pointer
checks, DPR emulation, real kernel busy/restart and browser Paint traces. Tests
label synthetic pointer cancellation and emulated DPR; they are not physical-input
or human acceptance. [Evidence and slideshow](../../artifacts/demo-slideshows/linked-notebook/README.md)
record source/binary/wheel/screenshot hashes, exact versions, measured limits and
capture types. Browser Paint event durations are main-thread work, not GPU
completion, display latency or compositor timing.

Remaining gates: actual remote kernel/frontend host and network, screen reader
(VoiceOver paused), physical input, independent usability, other frontends and
browsers, Linux/Windows build/runtime, and public compatibility. Local success
closes none of those gates. No public package, push, PR, planning or shared-ledger
write is part of this implementation.
