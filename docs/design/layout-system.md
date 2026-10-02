# Moxi layout system

Status: proposed architecture. A provisional [native paragraph slice](../native-paragraph-layout.md)
implements the first measurement/publication path; the complete API remains proposed. This design consolidates the
[content-layout work](../content-layout.md), [engine research](../layout-research.md),
[constraint research](../layout-constraints-and-graphs.md), and
[Kiwi experiment](../../experiments/layout-kiwi/README.md). API decisions and their
executable probes are recorded in the [API review](layout-api-review.md).

## Decision

Design the target from component composition and user-visible behavior, independently
of the current ColumnView representation. Build one retained layout system with
explicit container strategies, a common measurement protocol, and one geometry
publication boundary. Keep layout semantics
owned by Moxi. Use Kiwi for scoped linear relationships and evaluate Taffy for
flex/grid execution; neither defines the whole Moxi API. Do not translate all layout
into linear equations or pretend these engines are interchangeable.

The target is a complete desktop application layout system: flow, grids, forms,
resizable panes, overlays, scrolling and virtual collections, responsive composition,
and positioned canvases. Rich text is a measured content service. Pagination and
automatic graph placement have explicit extension boundaries, not an implied claim
that the first release implements a document publisher or graph editor.

The cohesive unit is a **component with a sizing contract**, not an engine.
A component can change its internal strategy without changing how its parent
measures or places it only if it preserves the full declared sizing, overflow,
baseline and dependency behavior, not merely the shape of a measurement result. Compatibility is a
migration concern, not a requirement that the new core inherit existing semantics.

## Architecture from first principles

The system has three independent structures:

- **Component tree:** application state, lifetime, event ownership and semantic order.
- **Layout regions:** who measures and places which boxes, including lazily realized
  collections. A region can span several transparent components.
- **Presentation tree:** transforms, clips, stacking, portals and animation.

A single mutable widget tree should not be forced to represent all three. Ordinary
components hide this distinction; portals, virtualization and adaptive reparenting
make it explicit internally. Accessibility derives semantic ownership from the first
structure and geometric information from the committed presentation of the second.
The accessibility tree is a derived semantic projection: grouping, merging labels,
and virtual collection metadata mean it is not a copy of the component tree.

The implementation taxonomy has six layout families: **Flow, Tracks, Relations, Layers,
Viewport, and Canvas**. Row/Column/Wrap are Flow constructors; Grid and table column
sizing use Tracks; ConstraintRegion uses Relations; Stack uses Layers. Scroll and
virtual collections use Viewport. Split is a stateful recipe over allocation and
interaction. Overlay is an attachment to a presentation layer. Adaptive selects
a policy over stable children. Authors use concrete containers and a small custom-layout protocol;
they do not select engine profiles or manage three trees. These conveniences must
not become a dozen independent execution frameworks.

The internal seam is deliberately small:

```text
Application state → keyed component description
                  → validated layout plan + measurement dependencies
                  → region execution / viewport realization
                  → committed geometry + presentation snapshot
                  → drawing, input, focus and accessibility
```

The layout plan records the selected semantics and dependency edges. It is not a
universal constraint matrix: flow, tracks and viewport realization retain their
own algorithms. Each family implements the common box protocol where it meets
another family; viewport-driven child production has an additional protocol.

Each versioned semantic profile specifies intrinsic queries, automatic minima,
growth/shrink rules, track participation, baseline export, overflow and dependency
behavior, and convergence policy. Backend replacement requires passing its
conformance corpus. A common result type alone does not establish equivalence.

The native host supplies paragraph shaping, surface scale and platform geometry.
It does not privately choose different control dimensions after Moxi has committed
layout. Where native controls impose a size requirement, that requirement enters
measurement before allocation.

Build a new core around these boundaries. Preserve old APIs through a separate
compatibility adapter only where useful; do not add more strategy branches to
ColumnView as the permanent architecture. A clean design can replace the existing
linear engine, node representation or synchronization model. Reuse proven math,
fixtures and host integrations only when they fit the new contracts.

## Existing evidence and migration inventory

| Existing surface | Preserve and evolve |
| --- | --- |
| `src/moxi/content_layout.mojo` | Opt-in rows/columns, stable-ID measurement retention, fixed/content/fill sizing; currently estimator-based text and list synchronization |
| `src/moxi/column_view.mojo` | Existing authoring, legacy container behavior, bounds consumers; route through an adapter during migration |
| `src/moxi/layout_primitives.mojo` | Scroll state, split/grid helpers, virtual recycler and measured item extents |
| `src/moxi/virtual_view.mojo` | Stable item identity and visible-item building; replace its post-layout bounds overwrite with explicit viewport ownership |
| `src/moxi/popup.mojo` | Popup state, owner/focus identity and placement; integrate positioning with committed transforms |
| `src/moxi/text_layout.mojo`, `text_shaping.mojo`, `scene_text.mojo` | Text services; establish a shared paragraph result for measurement and drawing |
| `src/moxi/scene.mojo`, `paint.mojo`, `accessibility.mojo` | Geometry consumers; migrate to one committed generation |

These foundations do not establish that the combined design already works.
Current content layout explicitly excludes several legacy modes. A legacy maximum
can override a conflicting minimum; the proposed API rejects contradictory ranges.
Those are compatibility differences to adapt explicitly, not silently change.

## Invariants

1. A stable node key plus generation identifies a component instance. List indices,
   recycler slots, solver variables, and backend handles are private implementation
   details. Reusing a key after destruction cannot inherit old focus or measurements.
2. Every child has exactly one owner of its layout rectangle. A transform can change
   its presented position without giving a second engine permission to relayout it.
3. Component ownership, layout ownership, and presentation ancestry may differ.
   Portals change presentation ancestry; they do not change event or state ownership.
4. A parent's final allocation is an input to a child region. A child can report
   desired size and overflow; it cannot enlarge that allocation through a soft edit.
5. Measurement is free of externally visible mutations. It may populate versioned
   caches, but cannot update application state or publish partial geometry.
6. Paint, hit testing, focus reveal, and accessibility consume the same committed
   geometry generation, with their own documented visibility rules.
7. Unsupported semantics produce an explicit diagnostic. No silent engine switch
   or best-effort interpretation of an unknown container mode in the new API.
8. Required relationships are never silently weakened. Optional preferences are
   weighted costs, not promised lexicographic priority tiers.

### Identity and coordinate contracts

A component identity is `(owner_namespace, local_key, mount_generation)`. Transparent
layout wrappers do not create new state ownership namespaces. A data key identifies a
logical row independently of its current index or realized instance. A realized row
uses `(collection_identity, data_key, realization_generation)`; cell identities add a
stable column key. Remounting discards layout caches but preserves application state
stored by data key. Scroll state belongs to the owning Scroll identity. Backend
integer IDs are allocated from this identity map, never fabricated from slot indices
or arithmetic on widget IDs. Ordinary authors supply component/data keys and use
opaque handles; generations, source revisions and backend mappings are runtime
mechanisms. Low-level child-source integrations explicitly version their data.

Use distinct typed coordinate spaces: local border/content, scroll viewport, canvas
world, presentation layer and window. Conversions require a transform from a committed
snapshot. Native accessibility bridges additionally convert window to screen space.
An anchor is an identity, edge and source space, not an untyped stored Rect.

## Authoring model

Use a small family of explicit containers, composed with common sizing and spacing.
Backend names never appear in ordinary declarations.

| Container | Contract |
| --- | --- |
| `Row`, `Column` | Ordered one-axis flow; content basis, weighted growth, explicit shrink, gaps, cross alignment and baselines |
| `Wrap` | Greedy line packing in source order, followed by per-line flow allocation; explicit line gap and cross-line alignment |
| `Grid` | Shared tracks, spans, explicit/automatic placement, per-cell alignment; fixed, content and fractional tracks |
| `Stack` | Overlapping children aligned within one box; explicitly participating children determine intrinsic size |
| `ConstraintRegion` | Scoped linear equalities/inequalities over child boxes, edges and measured baselines |
| `Split` | Two or more panes and dividers, required minima, stored user allocation and keyboard/pointer resizing |
| `Scroll` | Finite viewport and separate content extent; controls clipping, offset, anchoring and reveal |
| `VirtualList`, `VirtualTable` | Viewport-driven realization with stable data keys, estimated extents and bounded active children |
| `Overlay` | Content anchored to committed geometry, placed in a named presentation layer |
| `Layout` / adaptive policy | Custom arrangement or environment-selected policy over the same keyed child slots |
| `Canvas` | Explicit world-space child placement and transforms; optional graph-placement provider |

`Form` is a recipe built from Grid or ConstraintRegion. `Dock` is a recipe built
from Split, Stack and tab state. They are not additional solvers. A data table is a
virtual collection with shared column tracks, not a requirement to instantiate a
large generic Grid. Layout widgets do not own application data or selection state.

Common box style includes logical padding, border, per-axis sizing, min/max,
aspect ratio, alignment and participation (`visible`, `hidden`, `collapsed`).
Hidden occupies space but does not paint or hit; collapsed does not participate.
Use container gaps and explicit spacers; no CSS margin collapsing. Start/end are
logical directions. Algorithms operate in inline/block axes; horizontal and vertical
writing modes affect measurement, text shaping, baselines and track contributions
before geometry maps to physical axes; vertical writing is not a final rotation. A backend lacking
a requested writing mode must report that capability before layout. Source order remains semantic/focus order unless the author
explicitly supplies an accessible ordering policy.

### Overflow policy

Every region declares per-axis `visible`, `clip` or `scroll` overflow; the default
is `visible`. Visible overflow propagates descendant overflow bounds and permits
paint and hit testing outside the box, subject to ancestor clips. Clip intersects
paint and hit geometry with the content box without creating a scroll range.
Scroll installs the single viewport owner described below. Accessibility retains
semantic children and reports projected bounds plus clipped/offscreen state;
clipping alone does not remove semantic children. Hidden and collapsed children
are excluded from interactive accessibility exposure.

Overflow does not retroactively enlarge final allocation or intrinsic contributions.
Intrinsic sizing includes children participating in the strategy's sizing algorithm.
Scroll extent includes declared content bounds and eligible visible descendant
overflow; clipped descendants do not extend it. Required solver containment is
independent: clipping cannot make infeasible equations valid.

### Sizing vocabulary and exact boundaries

- `Fixed(points)`: preferred exact box extent, subject to a valid declared range.
- `Content`: natural extent under the offered opposite-axis size.
- `Fill(weight)`: participates in positive remaining-space distribution in flow;
  fills the offered axis in containers with no sibling distribution.
- `Fraction(ratio)`: fraction of a definite containing content-box extent. A query
  without that definite extent reports a dependency; it never multiplies infinity.
- `MinContent`, `MaxContent`, `FitContent(limit)`: explicit intrinsic queries for
  track sizing and advanced authors; Content remains the common case.
- `min`/`max`: legal nonnegative allocation range, with an explicit unbounded maximum.
  Contradictory ranges, negative weights and nonfinite values are declaration errors.

An axis has one primary sizing rule. Flex growth/shrink and constraint preferences
are container-specific options, not interchangeable aliases. A fixed child can
exceed its parent's available space: parent clipping/scrolling handles that overflow.
If a constrained region additionally requires containment, infeasibility is an error.

Flow computes bases, reserves gaps, and repeatedly freezes min/max-clamped items
while redistributing remaining space. Shrink is opt-in and weighted by basis; the
default preserves readable content and reports shortage. Wrapping uses those bases
to form lines before per-line distribution. Aspect ratio transfers a known dimension
to an otherwise unresolved one; it does not override two definite dimensions.

Tracks use the CSS Grid track-sizing algorithm for the documented subset, with
Moxi defaults translated explicitly. Support fixed tracks, `auto`, `min-content`,
`max-content`, `minmax` and `fr`; explicit placement, spans, named lines and stable
row-major auto placement. A bare fractional track has an automatic minimum; authors
use `minmax(0, 1fr)` when they want it to shrink below content. Spanning content
contributes through the track algorithm rather than assigning its entire minimum
to each spanned track. On an indefinite axis, fractional sizing follows intrinsic
track sizing rather than distributing imaginary available space. Resolve columns,
measure width-dependent cells, then resolve rows; advanced cross-axis dependencies
use the common cycle policy. This chooses an existing specified algorithm instead
of inventing another almost-grid.

Shared tracks across a component boundary are explicit subgrid participation:
the common Grid owner resolves their contributions. An ordinary nested Grid is
independent. Arbitrary constraints cannot cross that boundary. Dense packing is
opt-in and changes visual placement only; semantic order stays explicit. Masonry,
CSS floats, margin collapsing and browser style/cascade compatibility are not part
of this desktop layout profile. Unsupported profile features fail validation.

### Example (illustrative API, not compilable Mojo)

```text
Workbench(key="workbench"):
  Column(gap=12, padding=16):
    Wrap(key="toolbar", gap=8):
      OpenButton(key="open")
      SearchField(key="search", inline=Fill(1), min_inline=180)

    Split(key="body", axis=inline, initial_fraction=0.32,
          collapse_below=760, compact=ColumnLayout(gap=12)):
      SettingsForm(key="settings", min_inline=240)
      ResultsTable(key="results", inline=Fill(1), block=Fill(1), min_block=160)

  Overlay(key="column-menu", anchor=Anchor("columns-button", block_end),
          placement=[below_start, above_start], boundary=window_safe_area):
    ColumnMenu()
```

The pane children are declared once. The Split component owns their stable slots,
resize state and divider controls; its layout policy changes between split allocation
and compact column allocation. No child reparenting is needed. Compact mode removes
divider hit/focus targets, cancels divider capture, and moves divider focus to its
associated surviving pane. It retains pane sizes for returning to split mode.
A pane's editor, selection, focus and overlay anchor retain their identity while
its logical slot, key and component type remain compatible. A strategy change
invalidates strategy-dependent layout plans, not component state.
The divider publishes separator semantics, its current value and feasible range;
keyboard or pointer resizing updates controller state and schedules a transaction.
It never mutates committed rectangles directly.

For noninteractive arrangements, `Layout(key, policy=...)` can change from
`RowLayout` to `ColumnLayout` or a custom policy over the same children. A policy
is geometry logic, not a component constructor. Interactive chrome is owned by a
component/controller and staged before layout; it cannot be mounted by measurement.

Conditional composition with different child sets follows ordinary keyed lifecycle
rules. Matching text keys in different ownership scopes do not promise a move or
preserve state. Duplicate active keys fail validation; type replacement remounts.
Explicit moves across owners are advanced operations. If a native editor cannot
move during composition, defer that move until composition ends. The default
adaptive layout path requires no such native reparent operation.

Inside SettingsForm, authors can choose a compact constraint declaration:

```text
required(label_a.end == label_b.end, id="labels.align")
required(field_a.start == label_a.end + 12, id="fields.gap")
required(field_b.start == field_a.start, id="fields.align")
required(field_a.inline >= 80, id="field.minimum")
prefer(field_a.inline == field_a.measured.preferred_inline,
       strength=normal, id="field.preferred")
```

Provide helpers for alignment, equal dimensions, spacing and size resistance.
Raw equations remain available for linear relationships. Dynamic references are
validated against region membership and node generations before solving.

## Measurement and layout protocol

The core stores immutable declarations, mutable private caches and committed
snapshots. Engine adapters operate on a region-local view of that state. The core
schedules work; engines do not call each other through global mutable state.

### Custom layouts: two hooks, one placement owner

The public extension is `Layout(key, policy, children)`. Policies are immutable
configuration; interaction lives in components/controllers. Illustrative signatures:

```text
measure(context, proposal, children) -> BoxMetrics
arrange(context, final_size, children) -> PlacementPlan

context.measure(child, proposal) -> MeasuredChild
context.environment(metric) -> value
children[key].layout_value(name) -> value
PlacementPlan.place(child, local_rect, measured_child)
```

`measure` answers the parent's proposal or intrinsic query. `arrange` receives a
definite border-box size and produces one local rectangle for every participating
direct child. It may measure children at their final offers: banning measurement
here would make a parent-allocated width unusable for wrapped content. Neither hook
mounts children, publishes geometry, dispatches events or writes application state.
Plans are staged values; only the core arranges descendants and publishes them.
Committing a placement plan performs no measurement and calls no author hooks.

Child proxies expose measurement, baseline/alignment data and parent-specific layout
values (for example, grid placement). They cannot reach a sibling's internals,
mutate child bounds, or save a live child handle beyond the invocation. Repeated
measurement with the same proposal and dependencies reuses an immutable result;
different proposals are legal. Final placement must reference a result valid for
the allocated content dimensions. If width changes, a natural-width text result
cannot stand in for the final wrapped paragraph. Providers declare whether block
allocation also affects their measured content; otherwise the runtime conservatively
invalidates on either axis. This contract does not impose one measurement per child
on every algorithm, but it does impose one final placement owner.

The context records dependencies from measurement, environment and layout-value
reads, separately for measurement and arrangement. Configuration is an immutable
revisioned input. Arbitrary application-state reads inside a policy are unsupported:
capture those values into its configuration before layout. Cache validity includes
child identity/order, policy configuration and recorded dependencies. A reusable
plan may survive a presentation-only change; a text/font/width change cannot silently
reuse it. The runtime owns cache validity and lifetime. Policy-private scratch data
is optional, cannot carry application state, and may be discarded without changing
the answer. Custom authors do not manage revision vectors themselves.

Geometry dependencies and drawing payloads have separate validity. If edited text
still occupies the same tight box, the parent may reuse its allocation, but the
committed child must receive its new drawing/hit/caret payload. Reusing geometry
must never resurrect an old paragraph. Initially, conservative child-result
invalidation is acceptable; field-level dependency tracking is an optimization,
not a correctness prerequisite or an obligation on application authors.

All standard box layouts implement this contract. Intrinsic query support is declared;
an allocation-only policy rejects a content-sized parent use during validation.
The core rejects missing/duplicate/foreign placements, invalid dimensions and stale
measurement results before publication. Reentrant measurement cycles are errors.
Region adapters may maintain richer private plans for Grid or Kiwi, but must honor
these same boundary rules. Virtual realization uses the separate viewport protocol,
not hidden mount calls inside an ordinary layout callback.

### Shared data contracts

```text
MeasureRequest:
  inline, block                          # AxisProposal below
  direction, writing_mode, environment_epoch

IntrinsicMetrics:
  min/max/preferred contributions, first_baseline?, last_baseline?
  dependency_stamp

MeasuredChild:
  allocated_size, required_size, content_extent, overflow
  first_baseline?, last_baseline?, dependency_stamp
  render_payload                        # opaque final drawing/hit/caret result

LayoutOutput:
  node_key, local_border_box, content_box, baselines
  scroll_extent, overflow, diagnostics, render_payload

GeometrySnapshot:
  layout_generation, presentation_revision, layout_outputs
  transform_tree, clip_tree, presentation_order, realization_metadata
```

`AxisProposal` is `Exactly(points) | AtMost(points) | Unbounded | MinContent |
MaxContent | FitContent(limit)`. Zero is a real extent, never a sentinel. Exactly
requests a fixed box; AtMost offers a cap while allowing a smaller content-sized
box. An unavoidable minimum beyond that offer is reported separately as a required
contribution/overflow so the parent can allocate, scroll or reject deliberately.
Intrinsic queries return contributions, not final rectangles. Final arrangement
always supplies definite extents.

Intrinsic queries return `IntrinsicMetrics`; ordinary box proposals return
`MeasuredChild`. Public result types distinguish those roles even if a backend
shares storage. AtMost never returns an allocated box above its cap; larger natural
requirements are separate. A render payload is not a cache key. Its provider retains
it until every snapshot using it has retired, including in-flight rendering and
input reads. Authors never dispose native paragraph memory themselves.

Requests and returned box sizes use border-box units. Each component subtracts its
own border/padding exactly once when measuring content and adds it once on return.
Baselines are offsets in the local border box. Intrinsic queries are distinct from
final allocation. A baseline is a metric from
the measured text/control, never a guessed fraction of box height. A container
exports a chosen child baseline or reports none. An explicit alignment fallback
(start by default) handles baseline-less content.

A native paragraph service takes text, style/font fallback, locale, direction,
wrapping/break policy and offered width. It returns line boxes, baselines and an
immutable drawing/hit/caret result. Layout and rendering consume that same result.
Codepoint estimation remains a labelled headless fixture provider, not a production
substitute. Font loading, scale or fallback changes invalidate affected results.

Execution proceeds as follows:

1. Capture immutable declaration and child-source revisions. Validate keyed changes
   and identify dirty dependencies. Stage moves and initial virtual realization
   outside pure measurement.
2. Query intrinsic contributions where a container needs them, including the
   finite viewport contract for scrollable children.
3. In the acyclic height-for-width profile, allocate inline sizes, measure
   width-dependent content, then allocate block sizes. Engines may make several distinct intrinsic queries; identical requests
   must reuse cached results.
4. Arrange children locally. Constraint regions solve text-independent allocation,
   measure at the resulting widths, refresh block requirements, then solve placement.
   This staging applies only when block results do not feed back into inline sizes;
   cross-axis feedback involving intrinsic content uses the explicit cycle policy.
5. Resolve scroll extents, anchor compensation, sticky offsets and transforms.
   If more children are needed, yield to staged realization, then resume affected
   pure measurement against the same source revision. The viewport adapter has a
   bounded correction-work budget with an explicit pending/estimated status; it must
   never claim exact full-dataset geometry from partial measurement.
6. Resolve overlays from the resulting anchors, then atomically commit the snapshot.
   Input and rendering see the old generation until the new one is complete.

Do not quantize widths for cache keys across line-break thresholds. Apply device
rounding after logical layout, snapping shared edges consistently. Text measurement
and drawing retain the same logical width. Rectangular accessibility bounds are
conservative projections; hit testing can use richer transformed geometry.

### Dependencies and cycles

Duplicate keys, structural parent cycles and multiple layout owners are hard
validation errors and never candidates for numerical iteration. Standard containers
have directed measurement dependencies, rather than an
unbounded fixed-point loop. Adaptive selection reads the incoming available width,
not the width produced by its chosen branch. A scroll viewport's content does not
implicitly determine its own size along the scrolling axis: Content sizing there
requires a finite cap or explicit viewport preference.

Cross-axis linear relationships without intrinsic content can solve together.
A dependency cycle containing width-dependent text is rejected by the public
custom-layout protocol; break it with a definite allocation or an explicit sizing
policy. Built-in Grid executes its documented algorithm, including any specified
remeasurement; this is not permission for arbitrary callbacks to seek a fixed point.
General iterative regions are deferred research, not a public API or release gate.
Any future proposal must specify convergence, cancellation and failure semantics
against a concrete use case before adoption. A generic eight-pass limit is not a
layout algorithm.

On failure, retain the previous snapshot only while its identities remain valid.
If nodes were removed, atomically publish a recovery snapshot retaining surviving
geometry and tombstoning removed subtrees for paint, input and accessibility together.
Close their overlays, cancel capture and move focus to a surviving focus owner or
root; never dispatch to destroyed instances. First layout presents a bounded
diagnostic placeholder. Emit the dependency path and node IDs. Recovery is an
explicit committed generation, not consumer-specific filtering. Future automatic
cycle breaking requires explicit author consent.

## Strategy integration

### Flow and grid

Moxi owns the documented flow/track rules. Taffy is the preferred evaluation target
for richer flex/grid execution because those are its native algorithms; adoption
requires proving the supported Moxi profile maps correctly, including shrink and
minimum defaults. Translate declarations explicitly and test that profile. Do not
claim full CSS compatibility or silently substitute Kiwi for grid.

Keep the existing Mojo linear path during migration. Once the production adapter
passes gates, choose one default implementation per supported strategy/profile;
do not maintain several production engines for the same behavior without evidence
that the extra cost is justified. Taffy stays experimental until those gates pass.

### Constraint regions

Use pinned Kiwi behind the existing experimental C ABI initially. The region owns
solver lifetime, stable variable mapping and a bounded rebuild policy. Batch edits
and result reads in the production adapter if profiling justifies it. Failed edits
are evaluated in a candidate model or rebuilt from the last valid declarations;
C++ exception containment alone is not a transaction guarantee.

Parent bounds are required equalities, not edit suggestions. The author separately
chooses required containment versus allowed overflow for descendants. Preferred
sizes use documented weighted strengths; many lower-cost preferences may outweigh
one higher-cost preference. No promise of strict tiers. Constraints carry source
labels and node IDs; show rejected requirements and residuals of violated optional
preferences. A minimal conflicting subset is a diagnostic enhancement, not a solver
guarantee. Explicit stays can preserve user-moved geometry when desired.

Solver sharing across arbitrary components is excluded. A caller needing shared
relationships makes one explicit region containing the related boxes. Measured
children can contain other strategies; their internals remain opaque to the solver.

A region must also declare how it answers intrinsic queries. Standard form/row/
column helpers provide minimum and preferred size contributions. A free-form region
supplies an explicit sizing summary or a pure measurement callback; a general set
of equations does not automatically define a unique natural size. A region declaring
itself allocation-only rejects Content sizing from its parent with a useful error.
Within a definite allocation, helpers supply explicit position and size preferences;
user-controlled geometry can opt into stays at previous valid values. Source order
alone is not a mathematical tie-break. If multiple optimal placements remain,
no portable placement guarantee is inferred from
backend pivot order. General multiple-optimum detection is not supplied by the
adapter and is not a release gate. Diagnostics can flag missing helper declarations
without claiming to prove uniqueness. Raw equations accept backend-selected optima;
authors needing reproducible placement must supply sufficient relationships or use
a tested helper policy. Required infeasibility still fails transactionally.

### Scrolling and virtualization

Exactly one `ViewportOwner` owns each scrollable axis of a viewport. Scroll constructs
it; VirtualList and VirtualTable construct the same owner with a virtual child source.
Do not wrap those conveniences in Scroll for the same viewport. Compose virtual
content through the child-source API; independently nested viewports require their
own finite boxes. Box-style `overflow=scroll` lowers to this same owner.

The owner alone publishes extent, offset, visible range, anchor correction, clipping,
sticky/frozen transforms and scroll chaining. Sources provide extent estimates,
measured corrections and children; they never apply offsets themselves.

A Scroll owns a viewport rectangle, content extent, offset and clipping. Content
rectangles remain in content coordinates. Each snapshot carries its viewport box, full
content extent, clamped offset, content transform and viewport clip. Offset changes
affect transforms, sticky placement and visible ranges; they do not invalidate otherwise identical text
measurements. Pure scrolling still publishes a complete presentation revision.
The default wheel policy lets the deepest eligible scroll owner consume its available
delta and bubbles the remainder to ancestors. `contain` explicitly stops chaining;
overscroll visuals do not alter layout extents.

Authors compose one-dimensional content as sections in one viewport:

```text
Scroll(key="report"):
  BoxSection(key="summary"): Summary()
  ListSection(key="results", source=rows, estimate=RowEstimate(28))
  BoxSection(key="footer"): LoadMoreStatus()
```

`VirtualList` is a convenience for a viewport containing one ListSection. Sections
are layout participants, not nested scrollers. An ordinary box becomes a BoxSection;
it needs no knowledge of scroll offsets. Custom section providers implement a
separate protocol because a box's desired size cannot describe partial realization:

```text
SectionRequest:
  cross_extent, local_visible_interval, local_cache_interval
  preceding_extent, viewport_extent, source_snapshot

SectionPlan:
  content_extent, extent_quality         # estimated or measured
  placements_in_section_coordinates, realization_requests
  paint_bounds, hit_bounds, sticky_requests, anchor_lookup
```

The owner converts its visible/cache intervals into section coordinates, prefixes
section origins, and applies the viewport offset exactly once. A section may read
the local interval to choose items, but its ordinary placements remain in content
coordinates. Sticky requests are resolved by the owner into presentation transforms;
they do not alter section extent. Paint/hit bounds are clipped by the owner.
`SectionPlan` is staged against one source snapshot, not published independently.
Realization requests yield to the lifecycle phase before measurement resumes.

Addresses are `(section_key, item_key)`; BoxSection has a single logical item.
Reordering sections or rows does not change those addresses. Anchor lookup and
focus reveal use these addresses, not flattened indices. A removed anchor chooses
the next surviving address in the previous committed order, then the previous;
if none survives, reset to the beginning. Clamp within-item position when the
anchored item shrinks. For an anchor point at the viewport start, correction is
`offset = item_content_start + within_item_offset`, followed by range clamping;
the within-item offset is not the item's screen position. Apply correction to the transaction's captured scroll intent;
new input invalidates an unfinished correction rather than being overwritten by it.
Commit validates both the source snapshot and the base viewport transaction;
an unchanged data revision does not make an old scroll plan current.

The collection section uses a separate child-source protocol:

```text
item_count/revision, key_at(index), index_of(key)
estimated_extent(key, cross_extent), realize(key), release(key)
```

Realization is a lifecycle phase, never a measurement callback. Each transaction
reads one immutable source revision and stages new instances privately before pure
measurement. Mount notifications, input exposure and releases occur at commit;
old instances remain alive until their published snapshot retires. Aborted staging
is disposed without mount events. Source changes cancel stale work and schedule a
new transaction. Async results carry source and instance generations and are discarded
when stale. Application-visible effects belong in commit callbacks, not constructors.

Source revisions atomically replace the key-to-index mapping, so a permutation
cannot temporarily create duplicate identities. Full content extent comes from the
extent index or estimates, never from the union of realized children.
The viewport requests a range plus bounded overscan; it does not build all items
before measurement. A prefix-extent index supports offset lookup and measured
extent changes. Preserve the anchor as `(item_key, within_item_offset)` through
resize/insertion; if removed, choose the next surviving item, then the previous.
Width/font changes invalidate dependent heights while retaining estimates.

Tables share column-track state across visible rows, support horizontal as well as
vertical virtualization, and derive frozen columns/sticky headers from the same
track boundaries, published as one track snapshot used by headers, cells, hit
testing and accessibility. Exact content-width fitting over an entire dataset is an explicit
scan operation; default fitting uses declared widths or a labelled sample. Do not
pretend viewport measurements establish a global content maximum.

VirtualTable is a two-axis specialization, not a flattened ListSection. Its internal
contract carries separate row and column ranges, stable `(row_key, column_key)`
cell addresses, and one shared track snapshot. Frozen regions derive transforms
from that snapshot; cells never own a second offset. A table in a mixed vertical
viewport may expose a TableSection with the outer owner controlling vertical scroll
and a coordinated table owner controlling horizontal scroll. It must not silently
create a second vertical viewport. This adapter remains an implementation gate;
the one-dimensional section probe does not validate it.

Row-height policy is explicit too: fixed/declared height, measurement of all relevant
cells in a row, or estimated height with correction and anchor preservation.
Measuring only visible columns cannot establish a row's maximum content height.
Horizontal scrolling that reveals a taller cell must follow the declared correction
policy, not silently change the table's vertical geometry. Full-row measurement
may avoid mounting offscreen controls, but its measurement cost still counts.

Selection and focus live in the data/component model. Recycling a slot cannot
transfer them to another key. Focus reveal materializes an offscreen key before
moving focus. Retain an active editor/IME session until explicitly committed or
cancelled, with a bounded pinned-item policy. Accessibility exposes logical counts,
indices and supported navigation/realization actions; it cannot simply equate the
currently painted rows with the entire dataset.

### Overlays, stacks and transforms

Stack children share a box and explicit presentation order. Their intrinsic sizing
includes only participating children; positioned decorations do not inflate it.
Overlay content lives under an explicit presentation root while retaining its
component owner. Anchor lookup uses committed key/generation plus coordinate space.

Placement tries ordered candidates, chooses the first fit, otherwise the candidate
with least overflow (stable declaration-order tie break), then shifts within safe
bounds. Oversized content is constrained and remeasured or given a scroll viewport.
An overlay cannot affect its anchor's measurement. If the anchor is removed or no
longer realized, default to closing; keeping it open requires an explicit pinned
anchor policy. Reposition after scroll, resize, scale or content changes.

An overlay record names its identity, component owner, anchor generation/source
space, presentation layer, candidate list, clipping and interaction policies.
Scrollbars use a viewport decoration layer with fixed viewport geometry and explicit
input precedence over content. Clip escape is permitted only through a named overlay layer. Modal layers manage
focus containment and restoration through the existing popup/focus system, not
through z-order alone. Invert transforms for pointer input; singular transforms
are non-hittable and diagnosed. Sticky presentation never changes normal-flow size.

### Adaptive layouts, animation and canvas

Adaptive policy selection uses incoming size, locale/direction,
accessibility text scale and explicit application state. Optional hysteresis for
interactive pane changes is declared state, not hidden solver history. Preserve
keys, focus, text selection and scroll anchors across strategy changes on the same
child set. Different child sets use explicit lifecycle rules, not automatic state transfer. Collapsing
a focused subtree moves focus through an explicit fallback.

Layout animation interpolates presentation transforms/geometry between committed
targets. A presentation tick publishes a derived snapshot with the same layout
generation and a new presentation revision. Drawing, pointer input and accessibility
bounds follow that presented geometry; focus-reveal planning uses the target bounds
to avoid chasing moving intermediate positions. Reduced motion bypasses interpolation.
Content changes that affect intrinsic size still trigger actual layout.

Canvas owns world-space placement, pan/zoom and spatial lookup. Its nodes can contain
ordinary Moxi layouts. A graph provider receives measured node sizes and pinned
positions and returns placement/routes with an input revision. Stale results are
discarded. Ranking, obstacle routing and pagination remain specialized algorithms;
Kiwi does not supply them automatically. Rich documents supply paragraph/inline
measurement; a future paged flow returns fragments rather than overloading one Rect.

## Retention, invalidation and observability

Authors may rebuild lightweight declarative descriptions or use retained builders.
Both lower to keyed incremental changes (`insert`, `remove`, `move`, `update_style`,
`update_content`); the layout core must not resynchronize every declaration list
on every frame. Application state is stored by component identity independently
of the transient declaration representation.
Dirty categories are structure, intrinsic measurement, allocation, placement,
presentation and semantics. Propagate only to consumers of the changed output.
A color change does not invalidate measurement; a scroll does not resize siblings;
a width change invalidates only width-dependent measurements and their ancestors.

Cache keys include node generation, content/style revision, request dimensions,
font/environment revision, scale, locale, direction, writing mode, wrap policy
and measurement provider. Evict caches when
nodes die and bound auxiliary intrinsic-query entries. Native allocations and solver
state belong to region lifetimes. Instrument retained bytes/entries and rebuild cost;
choose thresholds from churn tests rather than embedding an arbitrary constant.

Each node diagnostic reports strategy, incoming request, measured size/baselines,
allocation, overflow, cache hits, dependency cause and layout generation. Constraint
regions add named residuals/errors; virtual containers add realized count, estimated
extent and anchor corrections. A debug overlay displays boxes, clips and anchors.
Keep these details out of normal product UI.

Measure declaration updates, measurement, engine edits/solve, arrangement,
publication and presentation separately, plus end-to-end frame cost. Record backend
versions and workloads. Existing tiny Kiwi timings are feasibility evidence, not a
reason to claim an application speedup.

## Delivery and acceptance

| Milestone | Deliverable | Required evidence |
| --- | --- | --- |
| 1. Shared contracts | Keyed store, request/result types, geometry generations, legacy adapter and real paragraph provider | Same paragraph used for measure/draw; font/width invalidation; unchanged pass makes zero leaf measurements; paint/hit/AX geometry agrees |
| 2. Composed workbench | Flow + Kiwi form + existing virtual recycler + popup through common ownership | Resize, scroll, summary insertion, popup following anchor, required conflict rollback, narrow arrangement and focus preservation |
| 3. Flow/grid profile | Wrapping, baselines, track spans, shared tracks and Taffy candidate adapter | Named profile fixtures, differential geometry tests, intrinsic/indefinite cases, packaging and full pipeline timings |
| 4. Collections and overlays | Variable-height/two-axis virtualization, frozen tracks, candidate placement and modal integration | Large dataset with bounded realization, scroll anchoring, offscreen focus, nested clipping, RTL, active editor/IME retention |
| 5. Release hardening | Diagnostics, cache/solver lifecycle, documentation and migrated consumer | Long churn, fault injection, supported platform builds, accessibility/IME manual checks, representative frame budgets |

Milestone 2 uses existing collection/popup functionality through the new contracts;
Milestone 4 expands their capabilities. Each slice must be usable and verifiable;
this is not a prerequisite to rewrite the whole toolkit before showing a screen.

The canonical acceptance screen has a wrapping toolbar, resizable constraint-based
settings form, virtualized results table, chart with a readable minimum, and anchored
column menu. Below a declared width it stacks the form and results. Exercise long
localized labels, mixed font baselines, RTL, text scaling, empty data, 100,000 rows,
variable row heights, summary insertion, nested scrolling and an active editor.

Correctness gates include:

- Fixed/content/fill clamping and wrap thresholds, spans and indefinite track sizing.
- Width-dependent text, font fallback updates, baseline alignment and pixel rounding.
- Constraint rejection without partial publication; optional residuals; numeric
  strength semantics; valid removal/rebuild after sustained churn.
- Overlay movement under nested scroll and zoom, clipping escape, oversized menus,
  anchor removal, modal focus restoration and escape dismissal.
- Stable row identity through sorting/insertion, measured height anchor correction,
  offscreen keyboard navigation and active composition during virtualization.
- Stable pane instances and editor state across adaptive policy changes; divider
  focus/capture correctly retires, and changing actual child sets follows lifecycle rules.
- Cycle diagnostics and first-frame failure behavior, including stale async results.
- Removal plus layout failure agrees across paint/input/AX; cancelled realization
  neither leaks instances nor fires premature lifecycle effects.
- Each viewport applies its offset once; overflow and intrinsic sizing remain
  consistent across strategy boundaries.

Performance gates are workload-specific and established before optimization. At
minimum: unchanged layout has zero measurement/solver mutation work; pure scroll
only realizes newly needed items; active realization is proportional to viewport
plus overscan/pinned items; timing includes synchronization and publication. Track
metadata may be proportional to dataset size—bounded realization does not imply
constant total memory. Set measured frame-time budgets on declared reference
hardware and test increasing node counts/churn; do not invent a universal latency
number from seven microbenchmark samples.

Public API promotion requires the full repository suite, relevant native checks,
external consumer authoring exercise and CI on supported targets. VoiceOver and
Japanese composition require explicit verification; earlier passes do not certify
this new integration. Migrate screen by screen, keeping legacy behavior opt-in until
each supported mode has an explicit adapter or diagnostic.

## Sources, confidence and unresolved choices

The architecture and proposed APIs above are Moxi design decisions. References
inform particular mechanisms; they do not establish that Moxi implements them:

- [Taffy](https://github.com/DioxusLabs/taffy): tree-oriented block/flex/grid execution.
- [Kiwi internals](https://kiwisolver.readthedocs.io/en/latest/basis/solver_internals.html): weighted strengths, variable retention and stay emulation.
- [Enaml containers](https://enaml.readthedocs.io/en/latest/api_ref/widgets/container.html): scoped solver ownership and explicit sharing boundaries.
- [CSS Grid](https://www.w3.org/TR/css-grid-2/): track sizing and subgrid algorithms for the declared Tracks profile.
- [CSS sizing](https://www.w3.org/TR/css-sizing-3/): intrinsic versus definite sizing vocabulary; reference, not a claim of CSS conformance.
- [Positioned layout](https://www.w3.org/TR/css-position-3/): flow versus positioned/sticky geometry.
- [Writing modes](https://www.w3.org/TR/css-writing-modes-4/): logical axes and direction.
- [Flutter scrolling](https://docs.flutter.dev/ui/layout/scrolling/slivers): viewport-oriented composition as a separate layout protocol.

This is a full target architecture; the staged delivery plan limits implementation
risk rather than limiting the design to today's widgets.

Confidence is high in single-owner geometry, stable-child policy switching and the
separation of measurement, arrangement and publication. The
[API review](layout-api-review.md) records executable counterexamples and the
limits of that evidence. Confidence is moderate in selecting Kiwi and
Taffy as eventual production dependencies. The composed authoring exercise, native
paragraph integration, cross-platform builds and representative cost measurements
can change those backend choices without changing the ownership model.

Unresolved implementation decisions are deliberately bounded: the exact Mojo trait
versus tagged-dispatch representation, native paragraph handle lifetime across host
backends and measured solver/cache
rebuild thresholds. They must be resolved in their corresponding milestone before
public API promotion. The contract probes are isolated Python reference models;
they are not production Mojo implementation, native UI tests or performance evidence.
No native benchmark rerun or CI run is claimed by this document.
