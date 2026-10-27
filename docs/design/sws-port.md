# Native SeedWaterSegmenter application

Status: proposed; planning only. Observed October 27, 2026.

## Outcome and evidence

Replace the wxPython/Matplotlib interaction layer with a Moxi application for
image-stack navigation, cell-seed editing, watershed previews, and inspecting
segmentation results. Preserve scientific results and existing data before
expanding the interface.

Source baseline:
[`SeedWaterSegmenter` at `45bd4bf`](https://github.com/davidmashburn/SeedWaterSegmenter/tree/45bd4bf22184f3daae3add27f7b2d2136c1573de).
The current application combines Python/NumPy/SciPy/mahotas algorithms with
wxPython and Matplotlib interaction, and uses ImageContour and EllipseFitter.
Moxi inspected at
[`feat/data-workbench`, `c8c7cbb`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
Local documentation/scoped-binding edits are unrelated and not dependencies.
These observations come from source inspection; no representative stack was
loaded and no segmentation-equivalence or throughput benchmark was run.

## Ownership and scope

The application owns images, cell/seed IDs, segmentation commands, edit history,
file formats, scientific algorithms, and coordinate conventions. Moxi owns
native controls, input, scene presentation, and narrowly demonstrated reusable
image/canvas capabilities. Keep Python algorithms initially behind an explicit
request/result boundary. Choose in-process interop or a worker process after a
small measured experiment; Moxi's Python plotting interface is not an existing
native Python widget binding.

Commands carry dataset/frame identity and generation. A result must not replace
a newer dataset or newer edit state. Undo/redo records scientific edits, not
arbitrary UI widget snapshots. Keep image pixels, label IDs, and display colors
distinct; display contrast changes must not alter segmentation input.

## Independent delivery slices

1. Capture a small redistributable or synthetic stack, seeds, saved state, and
   expected labels using the existing implementation. Document axes, spacing,
   intensity range, cell/background IDs, connectivity, and file-version behavior.
2. Build an external Moxi viewer with frame navigation, contrast controls,
   nearest-neighbor label overlays, pan/zoom, pixel-to-cell inspection, and
   stable selection. Measure raster uploads and overlay alignment before editing.
3. Connect existing watershed computation through the explicit boundary; test
   changed frames, errors, cancellation, and stale-result rejection. Reuse
   existing Python kernels before considering Mojo algorithm ports.
4. Add seed placement/movement/deletion and required polygon operations, with
   undo/redo and save/reopen round trips. Keep original files recoverable;
   introduce a versioned native format or a verified lossless adapter.
5. Add linked cell measurements and contour inspection where actual editing
   tasks need them. ImageContour/IBFI integration is optional follow-up, not a
   dependency for a correct segmentation workflow.

## Acceptance and verification

- Golden segmentation tests compare label partitions and cell identity under
  explicitly recorded parameters; arbitrary color or label renumbering must not
  hide meaningful scientific differences.
- Synthetic asymmetric images expose transposition, off-by-one pixels, origin,
  scaling, and overlay errors at multiple zoom levels.
- Replay seed edits, frame changes, undo/redo, save/reopen, and delayed results.
  Verify failed computation does not silently discard valid prior results.
- Record request latency, upload bytes, frame latency, memory, image dimensions,
  stack length, hardware, compiler, and backend on representative workloads.
- Native macOS build/launch, actual editing, resize, and closing must be checked
  separately from headless contracts. Linux/Windows support requires its own
  host verification and should follow user-platform needs.
- Establish project-owned test/build commands with the first prototype; do not
  claim Moxi's generic suite proves scientific equivalence or image performance.

## Non-goals and next decision

No simultaneous scientific-kernel rewrite, full GUI feature parity in the first
slice, 3D volume renderer, collaboration service, or generic scientific framework.
The first decision gate is a responsive, correctly aligned image/label viewer
on a real stack plus a reproducible legacy segmentation fixture. Confidence is
high in the application fit and medium in migration cost; Python environment
reproducibility, image transport, and actual user platforms could change scope.

This plan can proceed without FDG or [SWS4D](sws4d-port.md). Shared components
should be extracted from demonstrated overlap, not imposed as prerequisites.
