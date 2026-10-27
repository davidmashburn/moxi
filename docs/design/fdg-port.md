# Native force-directed graph application

Status: first slice implemented as a Moxi example; follow-ups remain proposed.
Reconciled October 27, 2026.

## Outcome and evidence

Port the useful graph exploration workflow from
[`render_d3_fdg` at `09a37cd`](https://github.com/davidmashburn/render_d3_fdg/tree/09a37cdcffe21ba02977cf24fe9d9b3a4b92ff33)
to a standalone Mojo application using Moxi. Preserve stable node IDs, groups,
weighted edges, animated layout, node dragging, pan/zoom, selection, labels,
search, and neighborhood exploration. Own simulation and snapshot export in
the application rather than coordinating browser downloads and conversion tools.

Original design baseline inspected: `feat/data-workbench` at
[`c8c7cbb`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
The interactive fractal demonstrates the canvas/event foundation. Existing
uncommitted API/capability documentation and scoped-binding experiments are
unrelated and are not dependencies. The implementation and fresh verification
record below supersede the initial proposal for the first slice; they do not
refresh unrelated workbench evidence.

## Ownership decisions

- Keep the layout algorithm in an application-owned `layout` module with no
  Moxi, window, painter, clock, or file dependencies. It accepts graph values,
  owns positions/velocities/pins, and advances by explicit deterministic steps.
- Moxi owns widgets, events, geometry, scenes, rendering, and host integration.
  The application owns graph semantics, force parameters, viewport policy,
  selection, search, neighborhood filtering, serialization, and export commands.
- [D3 force](https://d3js.org/d3-force) is a reference for the separation between
  simulation and rendering. This port does not promise numerical D3 parity.
- Start application-local. Extract a standalone graph-layout/force package
  when another real consumer establishes the shared contract. A broad math
  package or Moxi core is not the initial owner. Reconsider if an existing
  maintained Mojo package satisfies the actual requirements.
- The proposed [canvas interaction framework](canvas-interaction.md) is related
  design work, not a prerequisite. Do not implement that framework to ship FDG.

## Implemented first slice

The standalone prototype is now `examples/fdg/` on `main` at
[`875f714`](https://github.com/davidmashburn/moxi/commit/875f714bea2d27a8f00966dc3bd1bf024da281c1).
The user chose to keep it as an example for now. Its solver remains
application-owned, with no Moxi dependency; the original browser project is
unchanged. The implementation uses main's host API without merging the
workbench branch. Rendering submits controls and graph together, then uses a
small native helper to flush the complete frame. The macOS custom-rectangle limit increases
from 64 to 1,024 to accommodate node halos and fills at the documented capacity.

Implemented: deterministic bounded layout, original nodes/links JSON, dragging,
pan/zoom, selection, labels, search, neighbors, pause/restart, controls, and SVG
export. Python `view_graph` and original-style `fdg(nodes, links)` launch the
viewer directly via stdin; `render_svg` returns a static SVG snapshot. See the
[usage and limits](https://github.com/davidmashburn/moxi/blob/875f714bea2d27a8f00966dc3bd1bf024da281c1/examples/fdg/README.md).

Fresh verification on macOS ARM64 with Mojo 1.1.0:

- `bash examples/fdg/scripts/check.sh`: layout, JSON, event routing, and SVG XML
  checks passed.
- `bash examples/fdg/scripts/build.sh`: executable and ad-hoc-signed app built.
- `bash examples/fdg/scripts/check-native-frame.sh`: 60 draws, zero blank frames,
  zero deferred frames, and no native command overflow.
- `python3 examples/fdg/tests/test_python.py`: real executable SVG, Unicode,
  validation, process failure, and async/blocking native launch checks passed.
- `bash examples/fdg/scripts/integration-check.sh --native`: deterministic
  256-node/1,024-link exports, oversized-file rejection, and native capacity
  smoke check passed.

The example README retains historical standalone manual-input/Save-dialog and
benchmark observations against `c8c7cbb`; these were not repeated on main.
The full Moxi suite, other platforms, screen-reader workflows, numerical D3
parity, and notebook frontend rendering were not verified in this integration.

## Delivery record and follow-ups

1. Delivered initially as a separate `moxi-fdg` consumer, then incorporated
   into `examples/fdg/` at the user's request. Keep the solver, graph loading,
   application, tests, and sample input together in that example. Root tasks
   `fdg-demo`, `fdg-demo-build`, and `fdg-check` support source-based use.
2. Delivered deterministic initialization, link attraction, repulsion, centering,
   damping/cooling, pin/unpin, restart, and pause. Bounded exact
   pairwise repulsion is implemented; measure before adding Barnes-Hut or parallelism.
3. Delivered links/nodes with stable identity. Includes node drag with temporary
   pinning, background pan, cursor-anchored zoom, fit/reset, labels, selection,
   search, and selected-node neighbor emphasis. Keep UI controls out of gestures.
4. Delivered the original nodes/links JSON shape with clear invalid-ID/edge errors.
   Deterministic settled SVG uses the same scene as the app. Neighborhood
   filtering and parameter controls are included;
   distinguish first-slice omissions from compatibility claims.
5. Python launch and SVG wrappers are delivered. Inline notebook interaction
   remains a separate [Jupyter proposal](jupyter-integration.md). Additional image
   formats, packaging, and an extracted solver require their own evidence.

## Acceptance and verification

- Pure tests run without a native host: empty/singleton/disconnected/coincident
  nodes, deterministic replay, finite positions, pinning, cooling, invalid
  references, and attraction/repulsion behavior on known small graphs.
- Interaction tests exercise transformed hit testing, drag release/cancel,
  zoom anchoring, selection, search misses, pause/restart, and fitting.
- Build and launch on macOS ARM64. Observe real controls, dragging, zoom, resize,
  and close; report automated replay separately from physical input inspection.
- Export parses as SVG and reflects the same graph geometry and selected state.
- Actual first-slice commands and results are recorded above; root
  `pixi run fdg-demo` builds and launches the example.
- Benchmark fixed node/edge counts with warmup, iterations, compiler/revision,
  and separate layout versus scene costs. Do not infer speed from Mojo alone.

## Non-goals and open gates

No generic math framework, D3 API compatibility, graph editor, GPU solver,
browser-runtime port, or million-node claim. Full original template/custom-JS
compatibility is outside scope. Package-only installation and non-macOS native
support require separate verification. Confidence is high in the ownership
boundary and the tested bounded workload, supported by the capacity and frame
checks above. Larger graphs or an independent solver consumer would require
new measurements and could change the implementation boundary. Nothing in
this plan depends on either segmentation port shipping.
