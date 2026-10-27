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
  or linked browser runtime. Do not assume Mojo runs in the browser or require WASM.
- An interactive adapter owns notebook transport, frontend mounting, event
  translation, session identity, backpressure, and disposal. Graph selection,
  simulation, and domain behavior stay in the application. Moxi core owns only
  reusable event, scene, and view contracts demonstrated necessary by the spike.
- Start with a bounded full SVG frame and semantic/pointer events. Measure
  transport and redraw cost before choosing canvas rendering, binary scene
  commands, or incremental updates. Escape labels and avoid executable markup
  or a public listener; use the notebook's established authenticated channel.
- Treat the widget backend as a separate decision from the force solver's
  eventual package home. A second distinct layout consumer is still the gate
  for extracting a reusable solver package.

## Independent delivery slices

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
supported JupyterLab version and select one; do not commit to a frontend framework
without a working round trip. Keep any Mojo backend child process supervised by
Python and use a versioned, bounded message protocol.

Acceptance:

- Mount a graph inline, forward selection, node drag/release/cancel, pan/zoom,
  and one control such as pause; return an updated frame from the same graph state.
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
frontend support range, and ownership of saved interactive state. Start with
the smallest local notebook demonstration rather than promising all frontends.
