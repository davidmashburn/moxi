# Mojo and Moxi in Jupyter

Status: proposed notebook integration; Python launch and SVG helpers implemented
in the FDG example. Observed October 27, 2026.

## Outcome and current evidence

Use a Python notebook for data preparation and orchestration, Mojo for compiled
computation, and Moxi for reusable scientific views. Begin with the force-directed
graph example; segmentation viewers are possible later consumers, not prerequisites.

Implementation baseline: `main` at [`875f714`](https://github.com/davidmashburn/moxi/commit/875f714bea2d27a8f00966dc3bd1bf024da281c1). The original standalone consumer was developed against
`feat/data-workbench` at `c8c7cbb`; that branch's additional host APIs are not
dependencies of the main-branch example. Unrelated workbench documentation and
authoring experiments are outside this proposal.

The implementation under `examples/fdg/` includes:

- `moxi_fdg.view_graph(graph)` and the original-style `fdg(nodes, links)` tuples:
  JSON over stdin to a separate compiled native process; nonblocking by default,
  with an optional wait and an explicit process handle.
- `render_svg(graph)`: a deterministic settled graph snapshot as SVG text, suitable
  for `IPython.display.SVG`. This is static output, not a live widget.
- A solver in `src/layout.mojo` that depends only on the Mojo standard library.
  It remains application-owned; notebook use alone does not justify a general
  math package or moving graph semantics into Moxi core.

See the [example and usage guide](https://github.com/davidmashburn/moxi/tree/875f714bea2d27a8f00966dc3bd1bf024da281c1/examples/fdg).
The Python bridge has real executable checks for native launch/exit, SVG,
Unicode, validation failures, and process errors. Notebook frontend rendering
has not been tested. The native binary currently requires macOS ARM64 and opens
on the kernel's machine; a remote kernel cannot open a window on the user's laptop.
Large JSON payloads can be slow in the current parser; the SVG helper has a
configurable timeout. Python mutations after launch do not update the viewer.

## Current Mojo notebook options

The versioned [Mojo 1.1 notebook documentation](https://mojolang.static.modular.com/1.1.0/docs/tools/notebooks/)
uses a Python kernel with `import mojo.notebook` and `%%mojo`. Each Mojo cell is
a complete program with `main()`. Do not promise persistent Mojo definitions or
state across cells based on that interface.

[Calling Mojo from Python](https://mojolang.static.modular.com/1.1.0/docs/manual/python/mojo-from-python/)
supports explicitly exported bindings and an import hook. It is documented as
beta. Evaluate this for in-process computational kernels when shared data or
repeated calls justify the binding work; it is not required for launching FDG.
These documentation claims were checked October 27, 2026; neither notebook
magic nor Python-to-Mojo bindings were executed as part of this work.

## Two complementary investigations (October 27)

Advance [browser execution](browser-execution.md) and
[server-backed reduced views](server-backed-views.md) independently. The first
establishes a full Moxi web target; the second establishes data placement and
bounded asynchronous updates. They can meet in the same application: local
interaction and rendering over a server-owned dataset. Browser-local feedback
remains preferred; a backend round trip must not be required for every gesture.

A local probe against main `875f714` executes the existing FDG solver in
Chromium through experimental LLVM-to-wasm64 retargeting. This establishes a
narrow feasible route, not a supported Mojo web target or an interactive Moxi UI.
The initial full-SVG round-trip design remains a comparison/fallback, not a
requirement imposed by server-owned data. Neither investigation waits for the
other or for a notebook transport choice.

## Ownership and design decisions

- Keep Python as the initial notebook host. Confidence: high for the current
  workflow, supported by the working process bridge and existing Python data
  ecosystem. Revisit if a supported persistent Mojo notebook runtime makes the
  user's actual data workflow simpler.
- Keep native GUI event loops in their own process. A normal local notebook can
  open that viewer without taking over the kernel's main thread. This is a
  useful standalone mode, not the remote-notebook solution.
- Reuse Moxi's scene/SVG path for initial inline output. The existing web host
  contract and demo are foundations, not evidence of a working notebook adapter
  or a complete browser runtime. Investigate local execution of shared Mojo
  interaction/application code before choosing a server-driven frame loop.
- A reusable web host owns browser presentation and input translation. A
  notebook adapter owns transport, mounting, session identity, backpressure,
  and disposal. Graph selection,
  simulation, and domain behavior stay in the application. Moxi core owns only
  reusable event, scene, and view contracts demonstrated necessary by the spike.
- Prefer browser-local immediate interaction where feasible. Data placement is
  a separate decision: Bokeh-style server-side reduction can outperform moving
  a large dataset into the browser. Develop a measured split design alongside
  the web target; neither assume round trips are negligible nor categorically slow.
- For a split design, evaluate bounded SVG frames or scene/data deltas against
  payload size, local interaction, stale-result rejection, and update frequency.
  Escape labels, avoid executable markup or a public listener, and use the
  notebook's established authenticated channel.
- Treat the widget backend as a separate decision from the force solver's
  eventual package home. A second distinct layout consumer is still the gate
  for extracting a reusable solver package.

## Independent delivery slices

### 0A. Extend browser execution toward a complete web target

Owner: a bounded implementation experiment under `experiments/browser-execution/`.
The solver checksum probe has passed; complete the persistent-state, per-node
parity, runtime/error-path, and minimal Moxi event-to-scene gates in the linked
findings. Keep compiler experiments out of normal Moxi build dependencies.
This track advances independently of backend data-placement work.

### 0B. Establish server-owned data with browser-local feedback

Owner: an independent experiment under `experiments/server-backed-views/`.
Use a large synthetic spatial dataset and bounded viewport reductions. Verify
query generations, coalescing, stale-result rejection, selection identity, and
continued local pan/zoom while updates are outstanding. Measure bytes, reduction
cost, memory, and input-to-feedback separately from time to fresh data. Begin
with an in-process transport harness, then exercise a real delayed transport;
a simulation must not be reported as network or notebook performance.

The eventual integration combines a browser-hosted Moxi view with this data
contract. Do not require full browser compilation to investigate reductions,
and do not require the server data path for a standalone browser application.

### 1. Verify the existing notebook entry points

Owner: FDG example. Add a small notebook under `examples/fdg/` with one graph
definition consumed by both helpers. Use a local Python kernel and the compiled
binary. Keep optional notebook dependencies out of Moxi core's normal build.

Acceptance: execute all cells from a fresh kernel; inline SVG is readable;
native launch leaves the kernel responsive; closing the window and repeated
invocations behave predictably. Invalid data produces actionable diagnostics.
Record exact Python, Mojo, JupyterLab, platform, and Moxi versions. Check notebook
outputs for local paths and user data before committing. A remote-kernel note
must explicitly distinguish native-window and inline-output behavior.

### 2. Build one interactive inline FDG spike

Owner: an example-local notebook adapter, initially under
`examples/fdg/notebook/`. First compare Jupyter widgets/comms options against the
supported JupyterLab version and select one using evidence from both investigations.
For a browser-local application, Python exchanges data/commands outside the
immediate interaction loop. For server-backed data, specify state ownership and
supervise any Mojo child process; browser-local application code and server data
can coexist. In either case, use a
versioned, bounded message protocol and verify a working round trip.

Acceptance:

- Mount a graph inline, forward selection, node drag/release/cancel, pan/zoom,
  and one control such as pause; display an updated frame from the same graph
  state, locally or remotely as appropriate; backend work must not block immediate gesture feedback.
- Associate events and frames with a session and generation so stale events from
  a replaced cell cannot mutate its successor. Two graph outputs remain isolated.
- Rerun, clear-output, disposal, kernel restart, and backend failure stop animation
  and release processes/listeners. Pointer capture loss releases a dragged node.
- Resize and device scale preserve hit testing. Rapid pointer moves and slow
  clients have bounded queues and frame coalescing; final releases are not dropped.
- Preserve a static SVG fallback/export for saved notebooks and environments
  without the live adapter. Show backend failures instead of a permanently blank view.
- Exercise a browser connected to a remote kernel with the required backend
  available there. Do not claim support merely because local notebook tests pass.

Measure the current 77-node/254-link and 256-node/1,024-link workloads, reporting
layout, scene construction, serialization, transport, browser paint, and input
latency separately. Existing solver timings do not establish notebook responsiveness.

### 3. Decide whether to generalize

Only after the spike passes, exercise a second view (for example a plot with
linked selection) before extracting a general Moxi notebook adapter. Identify
which pieces are application-specific and which belong in a reusable optional
package. Define keyboard focus and accessibility expectations, installation,
supported frontend versions, remote execution, and recovery behavior before a
public compatibility claim. Reconsider SVG if measured browser costs dominate.

## Non-goals and open questions

No new Mojo kernel, generic Python bindings for every Moxi type, JavaScript
template compatibility, public server, browser compiler, packaging release, or
segmentation implementation is authorized by capturing this plan. Do not add
notebook dependencies to the main project until a delivery slice needs them.

Decisions left to the spike: transport/widget library, backend process versus
in-process bindings for interactive computation, frame frequency and size caps,
frontend support range, and ownership of saved interactive state. Advance both
investigations, then validate the smallest notebook integration with their
measured execution and data-placement boundaries.
