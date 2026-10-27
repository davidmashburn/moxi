# Native force-directed graph application

Status: proposed; first implementation is authorized. Observed October 27, 2026.

## Outcome and evidence

Port the useful graph exploration workflow from
[`render_d3_fdg` at `09a37cd`](https://github.com/davidmashburn/render_d3_fdg/tree/09a37cdcffe21ba02977cf24fe9d9b3a4b92ff33)
to a standalone Mojo application using Moxi. Preserve stable node IDs, groups,
weighted edges, animated layout, node dragging, pan/zoom, selection, labels,
search, and neighborhood exploration. Own simulation and snapshot export in
the application rather than coordinating browser downloads and conversion tools.

Moxi implementation inspected: `feat/data-workbench` at
[`c8c7cbb`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
The interactive fractal demonstrates the canvas/event foundation. Existing
uncommitted API/capability documentation and scoped-binding experiments are
unrelated and are not dependencies. Source inspection is not a native runtime
or performance verification of this proposed application.

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

## Independent delivery slices

1. Establish a separate `moxi-fdg` consumer with `src/layout.mojo`, graph loading,
   `src/graph_app.mojo`, `src/main.mojo`, tests, build tasks, and sample input.
   Preserve the original project's browser implementation. Use an explicit
   Moxi source/revision during development; document source-based builds honestly.
2. Implement deterministic initialization, link attraction, repulsion, centering,
   damping/cooling, pin/unpin, restart, and pause. Begin with bounded exact
   pairwise repulsion; measure before adding Barnes-Hut or parallelism.
3. Render links/nodes with stable identity. Support node drag with temporary
   pinning, background pan, cursor-anchored zoom, fit/reset, labels, selection,
   search, and selected-node neighbor emphasis. Keep UI controls out of gestures.
4. Accept the original nodes/links JSON shape with clear invalid-ID/edge errors.
   Export a deterministic settled SVG from the same scene used by the app.
   Add neighborhood filtering and parameter controls with explicit semantics;
   distinguish first-slice omissions from compatibility claims.
5. Validate native behavior, document limits and measured workload sizes, then
   decide whether Python convenience wrappers, image formats, packaging, or
   an extracted solver deserve subsequent slices.

## Acceptance and verification

- Pure tests run without a native host: empty/singleton/disconnected/coincident
  nodes, deterministic replay, finite positions, pinning, cooling, invalid
  references, and attraction/repulsion behavior on known small graphs.
- Interaction tests exercise transformed hit testing, drag release/cancel,
  zoom anchoring, selection, search misses, pause/restart, and fitting.
- Build and launch on macOS ARM64. Observe real controls, dragging, zoom, resize,
  and close; report automated replay separately from physical input inspection.
- Export parses as SVG and reflects the same graph geometry and selected state.
- Proposed commands: `bash scripts/check.sh`, `bash scripts/build.sh`, and the
  built executable's `--export` mode. Record actual commands after implementation.
- Benchmark fixed node/edge counts with warmup, iterations, compiler/revision,
  and separate layout versus scene costs. Do not infer speed from Mojo alone.

## Non-goals and open gates

No generic math framework, D3 API compatibility, graph editor, GPU solver,
browser-runtime port, or million-node claim. Full original template/custom-JS
compatibility is outside scope. Package-only installation and non-macOS native
support require separate verification. Confidence is high in the ownership
boundary, medium in initial workload capacity until measured. Nothing in this
plan depends on either segmentation port shipping.
