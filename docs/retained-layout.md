# Retained flow/grid candidate

`moxi.retained_layout` is an optional Mojo-owned module. Mojo owns declarations,
tree lifetime, flow/grid algorithms, measurement caches, staged geometry and
snapshot publication. CoreText supplies paragraph measurements and AppKit draws
the retained payloads; neither native service owns the layout tree. Kiwi remains
the separate constraint-region dependency.

Run `pixi run retained-engine-test` for portable geometry contracts, or
`pixi run retained-layout-check` on macOS for the CoreText integration. No Cargo
or Rust library is needed by either the macOS workbench or its consumers.
The former Taffy bridge in `native/retained_layout` remains an experimental
reference and is not linked by candidate builds.

The current profile supports nested rows, columns, greedy wrapping, a grid with
fixed/auto/min-content/max-content/minmax/fraction tracks, numeric placement and
spans, first baselines, stack participation, RTL, min/max clamping, explicit growth
and opt-in shrink. Fraction axis dimensions are containing-block percentages;
track fractions and `grow` allocate remaining space. A root receives an exact
parent allocation. Paragraphs have no padding: use a parent region for padding.

Grid rows share tracks through one grid owner, independent of component grouping.
Nested CSS subgrid, named-line authoring and last-baseline alignment are not yet
exposed. Unsupported enum values produce errors rather than approximations.
The paragraph intrinsic profile uses emergency cluster wrapping; min-content is
the widest composed cluster, max-content is the widest hard line. Float offers
are kept exact and geometry rounding is disabled.

Declare stable positive keys with `set_region`, `set_box` and `set_paragraph`,
attach ordered children, then call `layout(root, size)`. Children have exactly one
layout owner. Duplicate keys in a child list, cycles, orphaned nodes and excessive
depth (more than 256 regions) are rejected before publication. A declaration with
unchanged inputs does no mutation work. Each paragraph caches at most eight
query/width payloads; environment invalidation clears them explicitly.

For mixed strategies, `stage(root, size)` measures tentative geometry without
publishing it. Read the region allocation, solve its policy, then submit a batch
of `RetainedPlacement` rectangles local to that region. Custom placement removes
those children from flow and supplies exact sizes; it does not change their owner.
Stage the complete tree again and `commit(plan)`. Stale, foreign or conflicting
allocations reject without replacing the previous publication. A custom region
should have zero padding and no child margins so local coordinates are explicit.
Use `clear_placement` when a child returns to ordinary flow. A policy may inspect
its allocated region; it must not feed child size back into the parent allocation.

A snapshot owns its geometry, semantic metadata and native paragraphs. It remains
usable after cache eviction, declaration replacement, removal and context
destruction. Paint and hit testing use the same clipped rectangles. Accessibility
keeps logical geometry for clipped/offscreen nodes; hidden nodes participate in
layout but are excluded from paint, input and accessibility. Collapsed nodes are
excluded from layout as well. On removal the recovery snapshot immediately drops
the retired subtree. A subsequent failed layout leaves the remaining publication
intact; use `snapshot()` for recovery instead of retaining an obsolete frame.

Ownership is thread-confined. `RetainedEngine[P]` uses a small Mojo paragraph
provider trait; the native `RetainedLayout` wrapper supplies CoreText and semantic
metadata without making consumer code generic. `ArcPointer` retains immutable
geometry and paragraph payloads across cache eviction and context destruction.
Plans bind the owner, declaration revision and publication generation; expected
errors raise before publication. Request-local intrinsic/size/placement memoization
prevents repeated nested-grid traversal, and is discarded before a changed request.

This is a documented Moxi profile, not a complete CSS implementation or a claim
of equivalence with every Taffy behavior. Automatic grid placement is row-major;
definite cells reserve space before automatic cells. Grid track minima freeze
before remaining fractional space is distributed. Custom placements remain outside
normal flow. Resource guards reject more than 100,000 tracks, a span exceeding
1,000,000 cells, or an auto-placement search exceeding 1,000,000 positions.

`tests/retained_layout.mojo` exercises actual CoreText baselines, resize wrapping,
unchanged declarations, retained lifetime, grid spans and tombstone recovery.
Two shared geometry fixtures compare the retained adapter to the legacy engine
across 116 exact parent sizes. Approximate legacy text metrics are deliberately
excluded from that comparison. Native semantic keys must fit signed 32-bit IDs;
presentation rejects larger keys before publication.
`tests/retained_engine.mojo` covers allocation, fractional wrap boundaries,
clamp redistribution, opt-in shrink, RTL and alignment, intrinsic and nested-grid
sizing, ownership rejection, cache bounds, provider failure, clipping, depth guards,
stale/foreign plans and 1,000 remove/remount cycles. These are
candidate-profile checks. The [composed workbench](layout-workbench.md) integrates
collections, constraints, overlays and native editors. See the
[delivery ledger](layout-delivery.md) for current verification and promotion gates.
