# Native SWS4D slice-based segmentation application

Status: proposed; planning only. Observed October 27, 2026.

## Outcome and evidence

Provide synchronized XY/XZ/YZ views of 3D-plus-time images, with shared crosshair,
seed editing, segmentation overlays, and time navigation in a native Moxi app.

Source baseline:
[`SWS4D` at `aea8ee3`](https://github.com/davidmashburn/SWS4D/tree/aea8ee3d8c46aa7273c9522bdcbf63609431c126),
also available in the public [Bitbucket repository](https://bitbucket.org/davidmashburn/sws4d/).
`SeedWaterSegmenter4D` inherits `ArrayView4DVminVmax`; `ArrayView4D.make_plots`
constructs three orthogonal 2D slices using Mayavi image-plane widgets. Volume
rendering is an additional path, not a requirement for the central slice editor.
The application uses mahotas watershed, sparse seed/mask changes, and undo/redo.

Moxi inspected at
[`feat/data-workbench`, `c8c7cbb`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
Uncommitted API/capability docs and scoped-binding experiments are unrelated.
Source inspection did not verify a runnable legacy environment, 4D memory
behavior, scientific equivalence, or native image-upload performance.

## Ownership and boundaries

Keep volume storage, axis/spacing metadata, slicing, seed and label identity,
watershed connectivity, history, and persistence in the application/domain
layer. Moxi presents 2D raster/overlay scenes and controls. Declare the internal
axis convention (legacy arrays are indexed time, z, y, x), and centralize all
voxel-to-screen transforms, including anisotropic z spacing and transposition.

Start with existing Python scientific kernels behind explicit typed requests
and results. Frame, volume, and edit-generation identity prevents stale results
from replacing current state. Slice caching and worker ownership must bound
memory use; a display slice should not copy the entire 4D dataset.

## Independent delivery slices

1. Recover a runnable reference or capture reproducible golden outputs. Use an
   asymmetric synthetic 4D volume with known cells and anisotropic spacing.
   Document seeds, masks, 2D versus 3D watershed connectivity, and serialization.
2. Build an independent three-pane viewer with linked crosshairs, x/y/z/time
   controls, contrast, labels, opacity, pan/zoom, and voxel readout. Verify each
   plane's orientation and selections across all panes.
3. Support seed edits in each plane and a single-frame 3D watershed round trip.
   Keep input and result panes consistent, including masks and stable cell IDs.
4. Add undo/redo, save/load, frame changes, and loading/caching policies grounded
   in actual volume sizes. Recover cleanly from worker or loading failures.
5. Evaluate volume rendering only after the slice workflow is useful. If users
   need it, assess an optional specialized renderer through the separately
   proposed [3D interaction boundary](3d-interaction.md); do not expand Moxi
   core into a scientific volume engine as part of this port.

## Acceptance and verification

- Every orthogonal pane identifies the same known voxel/cell; transforms round
  trip correctly with nonunit spacing, zoom, pan, and edge coordinates.
- Seed editing and label overlays agree with golden reference results, with
  explicit 2D/3D connectivity tests and background/mask semantics.
- Undo/redo and save/reopen preserve seed/mask/label identity and frame state.
- Delayed computation cannot apply to a newer volume/frame/edit generation.
- Benchmarks record volume shape/type, memory peak, slice extraction/upload,
  time-scrub latency, watershed latency, backend, hardware, and compiler.
- Native macOS interaction and window lifecycle must be exercised separately
  from headless contracts. State unsupported hosts and untested volume sizes.
- Define reproducible test/build commands in the new application once the
  legacy fixture/environment is established; no generic Moxi test establishes
  the scientific acceptance criteria above.

## Non-goals and next decision

First delivery excludes ray-cast volume rendering, surfaces/meshing, a complete
Mayavi replacement, GPU watershed, and unbounded out-of-core processing.
Confidence is high that slices avoid a mandatory 3D renderer; migration effort
remains uncertain until the legacy kernels and volume transport are exercised.

This plan is independent of [SWS](sws-port.md) and FDG. It may reuse proven image,
coordinate, history, and transport components, but does not wait for either
application or a generalized framework to ship. The next gate is the linked
three-pane viewer plus a scientifically checked single-frame watershed result.
