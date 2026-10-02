# Retained flow/grid candidate

`moxi.retained_layout` is an optional native-backed module. It pins Taffy 0.14.0
and the transitive dependency lockfile, and uses CoreText paragraphs for both
measurement and AppKit drawing. Ordinary Moxi consumers do not need Rust or link
this bridge. Run `pixi run retained-layout-check` on macOS with Cargo installed.

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

A snapshot owns its geometry, semantic metadata and native paragraphs. It remains
usable after cache eviction, declaration replacement, removal and context
destruction. Paint and hit testing use the same clipped rectangles. Accessibility
keeps logical geometry for clipped/offscreen nodes; hidden nodes participate in
layout but are excluded from paint, input and accessibility. Collapsed nodes are
excluded from layout as well. On removal the recovery snapshot immediately drops
the retired subtree. A subsequent failed layout leaves the remaining publication
intact; use `snapshot()` for recovery instead of retaining an obsolete frame.

Ownership is thread-confined, including snapshot release. C callbacks are the
open provider boundary; region kinds are closed styles. Rust owns a concrete
Taffy tree and boxed C handles. `Rc` shares immutable measured payloads only
because snapshots must survive tree and cache destruction. `Drop` calls the
provider's release function. Expected errors return status plus a borrowed error
message; a caught internal panic requires discarding the context. No locks or
provider trait hierarchy are needed at the main-thread native boundary.

`tests/retained_layout.mojo` exercises actual CoreText baselines, resize wrapping,
unchanged declarations, retained lifetime, grid spans and tombstone recovery.
Rust tests cover allocation, fractional wrap boundaries, ownership rejection,
cache bounds, native-provider failure, clipping and invalid ABI inputs. These are
candidate-profile checks; composed workbench, collection, overlay, external
consumer, VoiceOver/IME and supported-target CI gates remain separate.
