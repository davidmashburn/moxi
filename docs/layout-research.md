# Layout research and proposed direction

The proposed [unified layout system](design/layout-system.md) consolidates this
work into a target architecture and staged delivery plan. It is not yet implemented.

Research date: 2026-09-24. The original proposal is preserved below with the
recommendation updated after implementation and additional constraint-system
research. See [implementation results](content-layout.md) and the
[Cassowary/Kiwi/Enaml/xyflow evaluation](layout-constraints-and-graphs.md).
“State of the art” here is a quality target, not a measured claim.

## Recommendation

Build a content-aware, retained layout system with explicit sizing policies,
width-dependent text measurement, incremental invalidation, and inspectable
results. Preserve Moxi's declarative Mojo API and stable identities. Establish
the semantics and acceptance fixtures before choosing the implementation engine.

My provisional preference is a native Mojo core for the first content/fill/stack
slice. Compare it with a small Taffy adapter before committing to a full Flexbox
or Grid implementation. If the adapter satisfies packaging, measurement,
correctness, and performance requirements with less maintenance, use Taffy.
Do not spend months reimplementing CSS merely to keep the algorithm in Mojo.

Updated recommendation: also evaluate scoped Kiwi constraints before expanding
the custom engine. Enaml makes them relevant to ordinary forms and dashboards,
not only distant cross-tree relationships. The first Mojo slice remains opt-in;
its measured adapter overhead does not establish an engine winner. xyflow informs
a separate graph-canvas capability with pluggable graph placement/routing.
See the [additional evaluation and fixtures](layout-constraints-and-graphs.md).

Confidence: high that sizing and measurement contracts need improvement;
moderate on the proposed architecture; low on which engine will win. A Taffy
integration experiment and equivalent workload measurements could change the
implementation recommendation. There is no evidence yet for a speed advantage.

## Evidence from Moxi

The CSV consumer exercise added a count/mean row. It first pushed the final data
row below the minimum window; the first correction passed bounds tests but
visually clipped text. The final fix reserved 38 points plus an 8-point gap and
reduced the chart from 250 to 204 points. This demonstrates manual space budgeting
and inadequate child-content checks, not the need for every CSS feature.
See the local consumer's `docs/authoring-walkthrough.md`.

Moxi already has substantial layout infrastructure:

- [ViewNode](../src/moxi/view_node.mojo) has preferred/min/max dimensions,
  intrinsic flags, wrapping, bounds, and semantics. This is an evolution, not
  adding intrinsic sizing from scratch.
- [ColumnView](../src/moxi/column_view.mojo) has linear, stack, grid, split,
  portal, and scroll behavior. `layout_width`/`layout_height` use intrinsic sizes
  only when enabled and the preferred size is not positive. Simply switching on
  an intrinsic flag does not override the exercise's explicit heights.
- Its row algorithm divides remaining width equally among unspecified-width
  children; its column algorithm sums child heights. There is no equivalent
  general weighted remaining-height policy. Grid divides the area into equal
  cells, rather than sizing content-based or fractional tracks.
- `layout_group` and `intrinsic_group_size` repeatedly scan the flat child list
  for each parent. An adjacency index is a prerequisite for predictable scaling
  with deeply nested containers. This is a source-level concern, not a measured
  latency regression. `add`/`add_to` append declarations; they do not themselves
  run a full layout pass.
- [measure.mojo](../src/moxi/measure.mojo) estimates advances as font size × 0.56
  and line height as font size × 1.25, with greedy codepoint wrapping.
  [text_layout.mojo](../src/moxi/text_layout.mojo) and
  [text_shaping.mojo](../src/moxi/text_shaping.mojo) provide additional shaping
  boundaries, but the ordinary ViewNode intrinsic path calls the estimator.
  `ViewNode.intrinsic_size` chooses wrapping width from preferred/max width,
  rather than receiving the final parent allocation. Accurate height-for-width
  therefore needs an API change, not just a better character-width estimate.
- [ColumnRuntime](../src/moxi/column_runtime.mojo) retains widgets by identity
  and consumes already-computed bounds. Reconciliation reuse alone does not
  establish incremental measurement or layout. `AppRuntime.apply_scroll_offsets`
  runs layout both before and after restoring offsets
  ([implementation](../src/moxi/app_runtime.mojo)); a scroll optimization must
  address this execution path, not just add a cache to leaf measurement.
- [VirtualRecycler](../src/moxi/layout_primitives.mojo) already supports measured
  item extents and visible ranges. Preserve that work rather than materializing
  entire lists in a replacement engine. It is not yet integrated into ordinary
  ColumnView child layout; the benchmark exercises it separately. Each height
  mutation rebuilds the prefix array, so batch updates need an explicit API.

There is also a renderer contract to change: the Metal CoreText texture path
derives font size from the supplied text-box height (height × 0.80), then draws a
CTFrame inside that box ([macos_metal.m](../native/macos_metal.m), near line 960).
Merely giving text a larger box can therefore change the font it renders with.
Carry font metrics/style independently of allocated box size through the scene
and native bridge before claiming measurement/rendering parity. The existing
[native text parity test](../tests/native_text_parity.mojo) explicitly does not
compare widths or glyph IDs; it is not a geometric-parity acceptance test.

The B summary's omission from the automation accessibility tree remains an
unresolved observation. This research does not establish that layout caused it.

## What established systems teach us

| System | Relevant evidence | Lesson for Moxi |
| --- | --- | --- |
| Flutter | Parents send constraints; children return sizes; parents choose positions. Clean subtrees can reuse layout with unchanged constraints. Viewports have a distinct sliver protocol. | Make dependency direction and viewport behavior explicit. Do not promise all advanced layouts are one-pass. [Architecture](https://docs.flutter.dev/resources/inside-flutter) |
| Jetpack Compose | Measurement and placement are separate steps; intrinsic queries supply information before ordinary child measurement. State reads can invalidate different phases. | Separate measure, place, and paint dirtiness. Prevent accidental recursive remeasurement. [Intrinsics](https://developer.android.com/develop/ui/compose/layouts/intrinsic-measurements), [phases](https://developer.android.com/develop/ui/compose/phases) |
| SwiftUI | Custom layouts answer size proposals, including minimum/ideal/maximum queries; placement is separate. ViewThatFits chooses a fitting alternative. Layout caches are optional. | Support width-sensitive measurement and adaptive alternatives without exposing the solver to authors. Cache only with complete keys and measured benefit. [Sizing](https://developer.apple.com/documentation/swiftui/layout/sizethatfits(proposal:subviews:cache:)), [custom layouts](https://developer.apple.com/documentation/swiftui/composing-custom-layouts-with-swiftui) |
| Yoga | Dirty nodes propagate to ancestors; clean nodes can be skipped under unchanged parent constraints. External measure callbacks handle content; callers must invalidate changed content. Defaults differ from browser CSS. | Adopt explicit invalidation and document defaults. A Flexbox engine does not supply font measurement. [Incremental layout](https://www.yogalayout.dev/docs/advanced/incremental-layout), [measurement](https://www.yogalayout.dev/docs/advanced/external-layout-systems), [defaults](https://www.yogalayout.dev/docs/styling/) |
| Taffy | Implements Block, Flexbox, and Grid. Its high-level tree owns caching; its low-level API supports a caller-owned tree. Text enters through measurement. README lists C bindings as work in progress. | Strong reuse candidate and reference implementation; Mojo integration and shipping cannot be assumed. [Project](https://github.com/DioxusLabs/taffy), [API](https://docs.rs/taffy/latest/taffy/) |
| Clay | Exposes fit/grow/fixed/percent sizing and an interactive layout debugger. | Small, intelligible sizing vocabulary and first-class diagnostics are valuable independently of algorithm choice. [Primary documentation](https://github.com/nicbarker/clay) |
| Cassowary | Incrementally solves prioritized linear equalities and inequalities. | Useful for ordinary form relationships as well as cross-tree alignment/editor constraints. Evaluate scoped Kiwi solvers and Enaml authoring helpers; text measurement remains external. [Original paper](https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf) |

These systems do not share a single interchangeable algorithm. SwiftUI proposals
are not Flutter's hard constraints; intrinsic queries are not ordinary placement;
Flexbox shrink behavior is not equal division of leftover space. Moxi needs one
documented contract rather than a mixture of familiar names with different rules.

CSS is especially useful as a precise reference for flexible allocation and
track sizing. Flexbox includes content-based automatic minimums and iterative
flex resolution; Grid includes track sizing and subgrid relationships. Select
and test a declared subset before claiming conformance. Full CSS parsing,
cascade, browser formatting, and subgrid are not requirements for the initial
consumer fix. [Flexbox specification](https://www.w3.org/TR/css-flexbox-1/),
[Grid specification](https://www.w3.org/TR/css-grid-2/).

## Proposed contract

### Author-facing sizing

Use explicit per-axis values rather than overloaded zero dimensions and several
interacting booleans. Proposed names below describe semantics, not existing APIs:

- `content`: use the measured content extent, including container padding.
- `fill(weight)`: share available space, respecting minimums and maximums.
- `fixed(points)`: request an explicit border-box extent.
- Minimum/maximum bounds are independent modifiers; aspect ratio and percentages
  require explicit resolution rules before being introduced.

Labels normally hug their measured text; containers normally fit children;
plot/canvas regions can explicitly fill remaining space. All dimensions use
logical points. Padding belongs inside the border box and gap exists only between
participating siblings. Fixed requests larger than available space produce the
chosen overflow policy and a diagnostic; they do not silently shrink readable
controls. Empty, hidden, and collapsed nodes need distinct documented semantics.

For the CSV app, the intended declaration is conceptually:

```text
Column(gap=8, height=fill)
  Header(height=content)
  ImportControls(height=content)
  SummaryRow(height=content, children=[A, B])
  Chart(height=fill, min_height=160)
  RowInspector(height=content)
```

Adding the summary changes the chart's allocation automatically. When minimum
content cannot fit, a declared viewport scrolls or an adaptive layout stacks the
controls. No system can guarantee all content fits every window without such a
policy. The chart minimum above is illustrative, not a measured product decision.

### Measurement and placement

Define a pure measurement boundary with available width/height, definite versus
unbounded axes, and a query kind for natural/minimum content when needed. Return
size, baseline information, overflow, and text-layout identity where applicable.
Zero available space must be distinct from unconstrained space.

Allocate row widths before measuring wrapped heights. Resolve weighted space
with a clamp-and-redistribute algorithm so maxed-out siblings do not strand free
space. Define minimum conflicts and overflow instead of hiding them with zero
clamps. Some flexible/intrinsic layouts require multiple bounded queries; count
these explicitly and cache repeated identical queries. Do not advertise universal
single-pass or linear complexity before proving it for each supported algorithm.

Text measurement and rendering must agree on font, fallback, scale, locale,
direction, wrapping, and line breaks. Reuse measured text layouts where the
backend permits; otherwise test metric parity. Integrate existing shaping
adapters, retaining an explicitly labeled deterministic estimator for headless
fixtures. Baselines, CJK, combining marks, emoji, and RTL are acceptance cases,
not something an estimated codepoint width establishes.

Do not assume selecting the existing native text-layout mode supplies native
metrics: the ordinary `layout_text` path reports an estimator fallback. The
separately linked CoreText adapter currently shapes one line. Paragraph wrapping
and shared line-layout results still require integration work.

### Retained execution and shared geometry

Keep an indexed arena with stable handles and parent/child adjacency. Declarative
construction remains cheap. Reconciliation updates retained layout inputs;
measurement, placement, and paint have distinct invalidation reasons. Cache keys
include constraints/query kind, content/style revisions, text backend/font
generation, scale, and direction. Content changes propagate only through actual
size dependencies; changed parent constraints invalidate affected descendants.

Publish one layout snapshot containing content/border bounds, baselines, overflow
extents, clipping, and transforms. Paint, hit testing, scrolling, focus reveal,
and accessibility consume that snapshot. Preserve semantic reading order even
when visual placement changes. Snap edges consistently at the presentation
boundary so adjacent siblings do not accumulate pixel gaps.

Scrolling moves a viewport without remeasuring unchanged content. Virtualized
containers measure visible items plus overscan, update estimates in batches,
and preserve a stable scroll anchor when measured heights change. Portals need
explicit coordinate-space and clipping ownership. These are integration
requirements whether the engine is Mojo, Taffy, or Yoga.

Diagnostics should answer “why is this 24 points high?” with the node ID, input
constraints, measured content, padding, allocation, clamp/overflow reason, and
cache status. Include a machine-readable trace and an optional visual overlay.

## Build versus adopt

| Path | Main benefit | Cost or unresolved risk | Position |
| --- | --- | --- | --- |
| Native Mojo | Direct integration with existing storage, packaging, and capability boundaries | We own algorithm correctness and every future feature | Provisional first-slice preference |
| Taffy via a narrow C ABI | Reuse established Flexbox/Grid behavior | Rust build artifact, wrapper ownership, callbacks, packaging for each target, and possibly duplicated storage | Required comparison spike before broad engine commitment |
| Yoga via C API | Existing C-facing flex engine and incremental contract | Still needs native packaging and text integration; Grid is not established by the reviewed API | Fallback if the Taffy boundary proves impractical and flex is sufficient |
| Clay | Small sizing vocabulary and diagnostic precedent | Adopting its full model alongside Moxi's retained pipeline needs separate evaluation | Design reference, not preferred replacement |
| Scoped Kiwi / Cassowary-family solver | Preferred sizes, aligned forms, and editable relationships; Enaml supplies authoring precedent | Width-dependent text, strength semantics, conflict diagnostics, C++ bridge, and lifecycle costs | Add a comparison spike before broader engine commitment |
| xyflow design / graph engines | Node-editor interaction and pluggable graph placement/routing | Web runtime for direct reuse; separate native graph and accessibility integration | Graph-canvas reference, independent of ordinary control layout |

For Taffy, prototype only create/update/remove, layout, external leaf measurement,
and bulk result extraction. Keep ownership explicit and prevent exceptions/panics
crossing the ABI. Compare retaining its tree with marshaling a flat snapshot;
measure callback and copying costs instead of assuming they dominate. Use pinned
upstream revisions. Audit license notices if reusing code or fixtures.

Taffy's published benchmark table excludes tree creation and compares particular
revisions on one machine. It is useful methodology context, not evidence that
either engine is faster for Moxi. Include bridge, measurement, reconciliation,
and publication costs in our comparison. [Benchmark scope](https://github.com/DioxusLabs/taffy#benchmarks-vs-yoga).

## Implementation sequence and acceptance

| Slice | Deliverable | Exit criterion |
| --- | --- | --- |
| 0: executable contract | Shared geometry fixtures; legacy baseline; counters for actual node visits and measurements | Reproduce the summary insertion problem and distinguish text clipping from outer bounds |
| 1: competing vertical slices | Minimal Mojo content/fill row/column path and minimal Taffy adapter over the same fixtures | Both exercise wrapped text, min/max redistribution, insertion, resize, and unchanged rerun; record packaging and end-to-end costs; choose an engine |
| 2: integrated core | Retained measure/place pipeline, backend text measurement, shared geometry, diagnostics | CSV exercise needs no manual chart-height adjustment; native glyphs, hit regions, and AX frames agree |
| 3: migration | Opt-in new layout policy with compatibility adapter; migrate CSV consumer and workbench | Existing fixed-layout fixtures remain stable; package-only consumer install/build passes; selection, focus, scrolling, and input survive |
| 4: advanced layout | Wrapping/adaptive rows, baseline alignment, content/fractional grid tracks; viewport integration | Mixed-language forms and dashboard fixtures pass with large text, narrow windows, nested scroll, and dynamic content |
| 5: release qualification | Property/differential tests, reproducible benchmarks, native interaction evidence, authoring walkthrough | Documented feature coverage and measured budgets; no unsupported “SOTA performance” claim |

Do not change legacy zero/min/max interpretation silently. Map old declarations
through an explicit compatibility policy; new defaults apply only to the new
API. During migration, declare whether `bounds_for` requires a finalized layout
snapshot so callers cannot accidentally inspect stale geometry.

Correctness fixtures must include weighted siblings reaching different limits,
zero/unbounded axes, padding larger than space, width-dependent wrapping,
empty/hidden children, deep nesting, font changes, fractional scales, and RTL.
Check padding exactly once, finite nonnegative published sizes, repeatability,
and consistency of paint/hit/AX geometry. Differential tests use only semantics
shared with the chosen reference; browser defaults must be set explicitly.

Benchmark 100/1,000/10,000-node wide and deep trees, text-heavy forms, the actual
CSV/workbench screens, and a large virtual list. Separate cold layout, unchanged
rerun, one-leaf text edit, sibling insertion, resize, scrolling, and font changes.
Report repeated-run median/p95, allocations or retained capacity, measurement
calls, visited nodes, cache hits, changed geometry count, checksums, compiler,
hardware, and backend. Time tree build, layout, text, and bridge/publication
separately as well as together. Derive numerical budgets from measured baselines;
do not assign a guessed percentage speedup.

The first behavioral performance targets are zero leaf remeasurement for a clean
unchanged rerun and zero content remeasurement for a pure viewport translation.
A width or font change is allowed to trigger substantial remeasurement. Compare
real operation counts; existing aggregate frame counters are not proof of
incremental work.

## Research limits

This review used primary framework documentation, specifications, a research
paper, and local source. Taffy's API page identified version 0.14.0 when read;
GitHub/default documentation pages are moving references and must be pinned for
an implementation experiment. No external engine was installed or benchmarked,
no native prototype was run, and no existing test suite was rerun for this
documentation-only change. The prior exercise supplies the live failure evidence.
Cross-platform delivery, full text-layout parity, and the accessibility omission
remain unverified. No commit, push, issue, or shared-system update was made.

## Implementation follow-up

The first opt-in content/fill slice and a pinned Taffy comparison now accompany
this research. See [content layout](content-layout.md) for the shipped contract
and validation scope, and the [Taffy experiment](../experiments/layout-taffy/README.md)
for its isolated measurements. The research limits above describe the original
research pass; implementation results are recorded separately.
