# I19: native canvas and spatial consumers

Two bounded consumers complete the canvas/spatial acceptance scenario named in
the public I19 plan. They use the same versioned semantic command contract as
[`experiments/inspectable-interactions/interaction.mjs`](../../experiments/inspectable-interactions/interaction.mjs):
transient preview, explicit commit, one undo unit, exact revision and original
value preconditions, and monotonically advancing revisions even after undo.

The canvas mode moves card 1 along world X with `CanvasDocument`, `CanvasState`
and `CanvasSnapshot`. The spatial mode edits object 101's world X using
`SpatialViewport`'s projected X handle, native preview/manipulation, history and
experimental Metal composition. Both panes are independent Moxi documents.
No shared interaction framework or core API change is required.

## Run

Use macOS arm64 with Xcode command-line tools and the repository's pinned Pixi
environment. Provision that environment once with `pixi install`; building and
running then require no service, credential, customer data or network access.

```sh
bash examples/inspectable-transforms/build.sh
dist/inspectable-transforms/transforms canvas
dist/inspectable-transforms/transforms spatial
```

Replace **Exact X** to preview, or drag the card/red X handle. Dragging stays
within the displayed whole-unit constraint. Release leaves the preview visible.
Press Escape or Cancel to discard it; Enter or Commit accepts it once; Cmd-Z or
Undo restores the previous value in one step. These document shortcuts also
work while the native numeric editor has focus. Left/Right preview a step when
the canvas owns focus.

Commit makes a JSON command visible. Reproject / resize changes the copy's
camera and viewport without changing its document. Replay command applies the
record once to that copy. Replay again rejects the stale revision. Undo copy
restores X but advances the revision, so the same command remains stale.

## Contract and units

| Consumer | Operation | Stable target | Integer X units / range |
| --- | --- | --- | --- |
| Canvas | `canvas.move-x` | `canvas/card-1` | Canvas points, 0…360 |
| Spatial | `spatial.position-x` | `spatial/object-101/x` | Milliworld units, −1000…1000; 1000 = 1 world unit |

```json
{"version":1,"operation":"canvas.move-x","target":"canvas/card-1","revision":1,"from":80,"to":230}
```

The version-1 shape and transaction semantics come from the public signal cursor
consumer. Operation, identity and units belong to each new consumer. Commands
contain world values rather than screen positions or camera matrices. The
boundary requires the exact version, operation and target; integer numeric
fields; safe, nonnegative revision; values inside the consumer's range; and a
nonempty edit. Both revision and `from` must match before any preview or history
is touched. Invalid/stale commands also preserve an existing preview.

Canvas fixture creation advances its document to revision 1 without an undo
entry. Public spatial `replace_objects` advances its document to revision 2
**and** creates one native setup entry. The spatial adapter reserves that entry
behind the example's undo boundary: the displayed undo count starts at zero,
and Undo cannot remove the fixture. Captured observations expose both native
and consumer undo counts. If bounded native history evicts fixture setup, that
reservation is retired. Native revisions are never reset or substituted.

## Reproduce the evidence

```sh
python3 examples/inspectable-transforms/gallery.py
open examples/inspectable-transforms/evidence/i19-transforms/index.html
# Verify retained source/artifact hashes and rebuild only the offline deck:
python3 examples/inspectable-transforms/gallery.py --render-only
# Original I19 contract regression checks:
node --test experiments/inspectable-interactions/test.mjs
```

The gallery builds the actual executable and runs its two normal mode entry
points with `--replay OUTPUT_DIRECTORY`. Replay inserts into the native field
editor, dispatches keyboard NSEvents through AppKit, and invokes native pointer
callbacks. Those paths reach the ordinary event loop and app actions. Focus,
capture loss and cancellation fault events use the host's normal event queue.
Only malformed/stale boundary tests call the semantic consumer directly.

Each consumer has eight native window captures: initial state, numeric preview,
held-pointer Escape, released pointer preview, committed command, source undo,
changed-projection replay after an actual window resize, and stale rejection
after undo. Each frame has a JSON observation of committed/preview X, revision,
native/consumer undo depths, viewport, window size and display scale. The
manifest records steps, expectations, observations and outcomes; provenance
pins public base, capture revision, source/artifact hashes, toolchain and limits.
The HTML embeds every image and its controls, so it opens without a server or
network. Build/replay logs stay in `/tmp/moxi-i19-*.log`.

Additional assertions cover empty undo, repeat replay, stale rejection with an
existing preview, wrong consumer identity, mismatched original X, malformed
types/version/range/revision, invalid/fractional numeric entry, both range
limits, returning from an out-of-range drag, Enter commit, a later matched
revision, held-pointer focus/capture/resize cancellation, and the spatial
history limit's fixture-boundary eviction. Assertions check native
revision/history effects in the transaction scenarios; no screenshot alone
establishes the behavior.

## Evidence boundary

The source starts from public `origin/main`
`033596ddb576b09b48234733b45a283b4c3fecae`. The acceptance contract was checked
against `origin/project-planning:DEFERRED-IMPLEMENTATION-MASTER.md`,
`ideas/i19-inspectable-interactions.md`, and the I19 crosswalk in
`d1da7c0:artifacts/demo-slideshows/concept-scenarios.md`. This example does not
update those global planning or gallery indexes.

Verification is automated native integration on one macOS arm64 environment,
with synthetic fixtures and the experimental spatial renderer. It does not
establish physical input behavior, human usability, accessibility, IME support,
other platforms, performance, multi-object generality or persisted recording
recovery. VoiceOver stays paused. Repository-wide checks are skipped; the
scoped native replays and original I19 tests are the relevant checks.
