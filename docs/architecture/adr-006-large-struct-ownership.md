# ADR-006: Retain the current large-struct ownership boundaries

Status: accepted for the current view, plot and demo contracts.

## Decision

Keep `ColumnView`, `ColumnRuntime`, `Plot`, `PlotSpec` and `DemoBrowserState`
whole. This settles the S2 extraction decision without changing public names,
state ownership or behavior. Their size remains a review cost; the earlier
file split did not eliminate it.

The review at `fa42b6f` traced state access, representative callers and failure
paths, and inspected the tests listed below. It compared moving methods into
functions that receive the whole struct with introducing a smaller delegated
owner. The former preserves the existing coupling while adding navigation;
the latter needs a useful contract beyond reducing file size. The current
evidence does not justify either change in this slice. Confidence is moderate:
this is a source-based design judgment, not a measured reviewer-productivity
result or a claim that future extraction cannot help.

## Per-struct assessment

### ColumnView

`children` is the shared flat declaration tree used by builder methods,
intrinsic measurement, layout, scrolling and hit testing. `layout()` tries
`_layout_content()` and falls back to `layout_group()` when the content layout
path cannot support a declaration. Both publish bounds onto the same nodes;
`point_is_visible()` follows their parent links and overflow state. The layout
solver already has a separate owner in `LayoutTree`.

Keep the declaration-to-layout adapter here. Moving it out would still require
the child tree, sizing overrides, root settings, scroll offsets and publication
back into the declaration. A separate mutable layout owner would introduce a
synchronization contract before there is an independent consumer for it.
The many short builders are locally reviewable; changes to geometry require
reading the shared layout and visibility paths together regardless of file.

### ColumnRuntime

`reconcile()` owns stable widget storage and active order, rejects an invalid
view before replacing retained state, and repairs focus, hover and press
identities after reconciliation. `paint()` reads that state and advances
`previous_commands`; clipping and scrollbar emission depend on the same
retained ancestry and overflow calculations used for visibility.

Keep reconciliation, interaction identity and paint history under one owner.
Extracting a painter is plausible, but passing the entire runtime would leave
the coupling intact. Giving a painter its own history or retained snapshot
would add a frame-order contract. Review `paint()` with the reconciliation and
visibility invariants, particularly command identity `(kind, id)` and old/new
invalidations. Small independent helpers such as `_indexed_changed()` already
have an appropriate free-function boundary.

### Plot

This is the strongest extraction candidate: `build_scene()` and
`build_render_packet()` contain substantial projection logic (720 and 356
physical lines respectively at the review baseline). They share series,
screen transforms and sampling helpers with hit testing, while having distinct
output responsibilities. The scene contains chrome and fallback marks; the
packet contains supported dense marks. `plot_render_bridge.mojo` composes
`build_scene(False)` with the packet or chooses the complete scene fallback.

Retain the methods for now. Moving each whole body into a function accepting
`Plot` would shrink the struct without shrinking either difficult review unit.
A useful extraction would instead define a smaller mark-projection contract
that preserves ordering, clipping, sampling and the complete-scene fallback.
That contract has not been demonstrated by this inspection. Existing
`PlotSeries`, `PlotScale`, `Scene` and `PlotRenderPacket` already separate data,
coordinate policy and output representations. Accept the concentrated review
cost explicitly; adding another backend alone does not require another owner
inside `Plot`.

### PlotSpec

The struct owns one versioned grammar: layers, encodings, transforms, scales,
interactions and annotations. Builder methods update related records, and
`validate()` checks their cross-references. `validate_data()` adds field
availability checks against transforms and a concrete table.

Keep its serializer with the grammar for this slice. `to_json()` is a 180-line
method, not the remainder of the 1,658-line file: the parser
`plot_spec_from_json()` and compiler `plot_from_spec()` are already top-level
functions. Record types, names and parsing helpers already live in separate
modules. Extracting serialization could isolate a future wire-version policy,
but today it would pass essentially every grammar collection to another owner
or pass the whole spec. Wire changes would still require joint review of the
records, serializer, parser and compatibility tests.

### DemoBrowserState

The browser owns selection, search, tabs, task status and child lifetime.
Actual demo behavior is delegated through typed `ComponentSlot` values.
`build_demo()`, `update()` and clipboard routing select those same slots;
reset handling defers authoring replacement until `finish_input_batch()` so
queued input cannot target a replacement page prematurely.

Keep that coordination together. Extracting only shell construction would
move substantial visual declaration but leave routing, selection and lifetime
coupling unchanged. Extracting the page registry would need a shared dispatch
and reset contract across heterogeneous slots. This review found no second
browser consumer requiring that abstraction. The long shell and routing
methods remain a cost, bounded by reviewing the affected page's build, event,
clipboard and reset paths together.

## Review evidence and reopening criteria

Existing tests provide focused review paths; their presence is not evidence
that they were executed for this documentation-only decision:

- View geometry and fallback: `tests/content_layout_view.mojo`,
  `tests/layout_primitives.mojo` and `tests/clipping.mojo`.
- Retained identity and paint: `tests/diff.mojo`, `tests/paint_index.mojo` and
  `tests/input_routing.mojo`.
- Plot projections and sampling: `tests/plotting.mojo`,
  `tests/plot_render.mojo` and `tests/portable_plot.mojo`.
- Spec validation and compatibility: `tests/plot_spec.mojo` and
  `scripts/plot_spec_contract_check.py`.
- Browser coordination: `tests/demo_browser.mojo` and
  `tests/demo_authoring.mojo`.

Reopen the affected boundary when a concrete change demonstrates repeated
divergence between projections, duplicated ownership logic in another
consumer, or a review defect attributable to these coupled responsibilities.
An extraction proposal should identify the state it owns, the reasoning it
removes and the new contract callers must understand. Preserve public names
and observable behavior, and run `pixi run test` plus affected targeted tests
after each extraction. A line-count increase alone is not that evidence.

This decision changes only documentation. Prose-artifact and whitespace checks
validate the new artifact; no compiler, behavior suite, benchmark, native GUI
session or reviewer-effort experiment is required or claimed for this change.
