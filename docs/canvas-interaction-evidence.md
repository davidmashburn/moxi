# D03 implementation evidence

Local implementation and parent integration, 6 November 2026. The gallery manifests
record the exact source revision, scoped dirty state, individual source hashes
and PNG hashes. The native presenter extends instance-owned ordered painting
with bounded custom slices; no renderer payload is shared between windows.

Both real Moxi demos run. The reusable C0–C4 mechanisms are implemented and the
focused contracts pass. **The plan's native/human exit criteria and large-graph
performance budget are not satisfied.** Do not mark D03 fully accepted from
this evidence alone.

## Checked behavior

| Area | Executed evidence |
| --- | --- |
| C0 ordinary component composition | TextInputState, Button and SliderControl own real state/events; clipboard and synthetic composition arbitration; button-driven extent changes republish ports; zoom anchor/inverse tolerances; no camera-induced child builds or root fallback |
| C0 native geometry | Both native windows compile and run; same live NSTextField identity survives 0.8 zoom and parent scroll; editor frame, ancestor clip and font checked against projected control geometry; clipped accessibility publication checked |
| C1 manipulation/history | Pointer threshold, captured release, foreign-pointer rejection, move/cancel/undo, keyboard repeat coalescing, resize/ports, stale revision rejection, bounded autopan preserving the grabbed screen point |
| C2 graph geometry | Straight/cubic shared paint/hit geometry, offscreen crossing paths, screen-sized port tolerance at 0.1/1/4 zoom, target hysteresis, duplicate/self/capacity rejection, retained old edge during invalid reconnect, valid reconnect/undo, removed-port/cache invalidation |
| C3 composition/commands | Groups move selected descendants once; ungroup preserves world position; create/delete/undo; minimap pan; command/object search; keyboard source/target/edge selection; platform Primary mappings and conflict checks; application bindings win in idle scope while text/session ownership wins within its scope |
| Application semantic hooks | Destination preview/cancel/one-unit commit/undo and no-op rejection; mind-map-compatible Tab/Shift+Tab/Space/structural arrows/Escape command delivery, without implementing D04 |
| C4 independent package | `moxi` and `moxi_canvas` precompiled; clean temporary-directory consumer imports only these packages and runs (`Public consumer: 18 7`) |
| Shared-core regression | Existing `layout`, `component`, and native `retained_layout` tests pass with `ColumnView.published_geometry` defaulting off |
| Galleries | Eleven actual AppKit content-view bitmap renders per demo; separate version-1 manifests validated/rendered by the established gallery module; PNG/HTML remain ignored |

The four behavioral test sources are `tests/canvas_contract.mojo`,
`tests/canvas_graph_contract.mojo`, `tests/canvas_keyboard_contract.mojo` and
`tests/canvas_geometry_contract.mojo`. The latter also checks analytic native
line/rectangle clipping. These are executable assertions, not screenshot-only
acceptance. Native captures replay events in the actual app; they do not emulate
physical devices or prove input-source integration.

Rich-probe replay recorded 6 content builds for the edited node and 1 for the
untouched node, over 53 parent publications. Graph replay recorded 5 and 1,
over 57 publications. Whole-tree publication still happens; retained child
content is the locality claim. The parent-scroll fixture uses a Moxi parent
offset and ancestor clipping, not an NSScrollView.

## Measured CPU costs

Apple M4, arm64, macOS 27.0.1 (26A434), Mojo 1.1 environment. Forty samples per
operation, nearest-rank percentiles; p99 equals maximum with this sample count.
The timer includes view publication and Scene construction. Published geometry
is consumed into a printed checksum after timing to keep the output observable.
Native submission, display/presentation, allocations and GPU costs are excluded.
These are local diagnostic measurements, not comparative renderer claims.

| Fixture and operation | p95 ms | p99 / worst ms |
| --- | ---: | ---: |
| 100 simple nodes / 200 edges: pan | 2.617 | 2.680 |
| Same: selection | 0.527 | 0.613 |
| Same: move preview | 0.863 | 1.479 |
| 1,000 visible simple nodes / 2,000 edges: pan | 29.210 | 34.356 |
| Same: selection | 8.578 | 8.745 |
| Same: move preview | 5.729 | 5.959 |
| 100 rich nodes / 200 edges: pan | 2.058 | 2.101 |
| Same: selection | 0.473 | 0.542 |
| Same: move preview | 0.632 | 0.719 |

The smaller fixtures use a 1,200×800 root and include culling. The 1,000-visible
fixture uses a 7,000×4,000 root to include every node at the allowed scale;
this is a CPU workload, not a claim of native presentation at that size.
It publishes 3,015 view nodes and 8,441 Scene commands. Cold setup/publication:
1.910 ms simple-100, 25.118 ms simple-1000, 1.631 ms rich-100. Transaction commit:
0.113, 0.525 and 0.100 ms respectively. Selection causes zero object-index writes;
unrelated component measurements remain zero in all three fixtures.

The 10,000-object / 20,000-edge high-degree stress case retains 20,000 cached
paths: 153.456 ms cold fixture-plus-geometry and 16.023 ms hot publication, with
20,000 route-cache hits. It is a geometry stress check, not an interactive claim.
Full document/index copies and scans, screen-space path invalidation on camera
movement, and full history snapshots remain significant. One 1,000-node commit
retains 2,000 object records in its before/after history pair; the history limit
is 100 transactions. Allocation count/bytes and resident memory were not measured.

The proposed 8 ms p95 budget already fails before native submission. The current
native ordered-paint capacity of 1,024 commands also prevents presenting this
large fixture. A capacity increase alone would not resolve the CPU cost.

## Open acceptance and integration work

- Physical IME at non-unit zoom, candidate-window/caret placement, actual
  selection/focus through unrelated native updates and clipping, non-US keyboard
  layouts, repeated hardware keys, trackpad feel and capture loss need human
  native sessions. Synthetic tests are not substitutes.
- VoiceOver remains paused. Accessibility bounds are checked structurally;
  real assistive-technology behavior and announcement quality are unverified.
- End-to-end 60/120 Hz input-to-presentation latency, allocations, GPU time,
  device variation, cold install/environment provisioning and non-macOS native
  hosts were not tested. The existing environment was reused.
- Large native scenes need a reviewed shared renderer capacity change. Parent
  integration resolves edge/control ordering with two instance-owned custom
  slices. Dense reconnect labels can still overlap. The D03 adapter bounds
  per-command clipping locally; partially clipped edge labels are omitted.
- Review the six-line `ColumnView.published_geometry` seam with N01/F02. Default
  behavior is unchanged, and baseline layout tests pass. Both demos link the
  existing native ABI with Cocoa and QuartzCore. No math integration is needed.
- The public graph is an editable processing graph, not a processing engine.
  D04 topology/layout and application semantics stay with its consumer.

Confidence is high in the tested functional paths and moderate in native
integration quality. Physical input/assistive testing or renderer changes that
invalidate the geometry assertions would change that assessment. Performance
acceptance requires a new passing end-to-end benchmark, not extrapolation from
these CPU measurements.

## Reproduce and review

Follow [the run/capture recipe](canvas-interaction.md#run-and-reproduce).
Review the [rich-node manifest](../artifacts/demo-slideshows/canvas-rich-node/manifest.json)
and [graph manifest](../artifacts/demo-slideshows/canvas-graph/manifest.json).
The parent reruns captures after the source commit to bind the gallery to that
revision. These are `offscreen-render` captures of real AppKit content, not
compositor window screenshots or evidence of physical device input.

Worker logs remain local under `/tmp/d03-*.log`; parent logs use
`/tmp/moxi-d03-parent-*.log`: four `canvas_*contract` logs,
`consumer-clean`, `package-core`, `package-canvas`, native build/capture logs,
`benchmark`, `gallery`, and `baseline-{layout,component,retained}`. Earlier failed
experiments also remain in `/tmp`; use the final logs and asserted results above.
No commits, pushes, shared messages or planning edits were performed.
