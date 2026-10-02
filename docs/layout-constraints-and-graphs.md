# Constraint and graph layout evaluation

The proposed [unified layout system](design/layout-system.md) consolidates this
work into a target architecture and staged delivery plan. It is not yet implemented.

Research follow-up: 2026-09-24. This extends [the original research](layout-research.md)
and revises its treatment of Cassowary. This pass changes documentation only.

## Recommendation

Evaluate Kiwi as a serious alternative for form and dashboard layout before
committing to a broad custom Mojo engine. Enaml demonstrates that constraints can
support everyday widget layout through convenient helpers; they are not just an
escape hatch for distant relationships. Keep the current content/fill path opt-in
while making that comparison. Treat xyflow as a reference for a separate graph
canvas capability, with its own placement engine and interaction model.

This is a revised research recommendation, not a decision to ship three engines.
The current adapter's measured overhead is a reason to compare complete pipelines,
not evidence that Kiwi or Taffy will be faster.

| Candidate | What it contributes | Moxi evaluation role |
| --- | --- | --- |
| Cassowary | Incremental linear relationships with requirements and preferences | Constraint semantics and interactive editing reference |
| Kiwi | C++ Cassowary-family implementation with Python bindings | Native solver candidate through a small C ABI |
| Enaml | Declarative widget authoring, sizing preferences, and layout helpers | Primary reference for an ergonomic constraint API |
| xyflow | React/Svelte node-based UI libraries | Graph interaction, measurement lifecycle, grouping, and accessibility reference |
| Dagre / ELK through xyflow examples | Automatic graph arrangement; ELK also supports routing | Separate graph-layout candidates if Moxi adds a node editor |

## Cassowary and Kiwi

Cassowary handles incremental linear equalities and inequalities with required
constraints and hierarchical preferences. Its original model includes edit and
stay constraints, useful for dragging while preserving relationships and avoiding
unnecessary movement. Constraints can describe ordinary UI relationships such as
aligned field edges, equal button widths, and a chart minimum. The algorithm does
not supply a widget toolkit or a text shaper.
[Original paper](https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf).

Kiwi exposes C++ and Python APIs for adding/removing constraints, suggesting edit
values, and publishing results with `updateVariables()`. Edit suggestions cannot
be required constraints. Therefore a hard viewport boundary must not silently
become a soft resize suggestion; our adapter needs to represent the distinction.
[Kiwi usage](https://kiwisolver.readthedocs.io/en/latest/basis/basic_systems.html).

Three differences matter for Moxi:

- Kiwi uses numeric strengths rather than Cassowary's lexicographic ordering;
  enough weak preferences can outweigh a medium one. Do not promise strict
  dominance between optional strength levels without testing or another policy.
- Kiwi omits native stay constraints. Stable drag positions need explicit weak
  equalities or maintained edit suggestions.
- Removed constraints can leave retained variable entries. Long-lived editor
  workloads need a measured reset/rebuild policy.

These are documented properties, not bugs discovered in Moxi.
[Kiwi internals](https://kiwisolver.readthedocs.io/en/latest/basis/solver_internals.html).

For a native experiment, use Kiwi's C++ core behind opaque handles and status
returns, with exceptions contained inside the wrapper. Python bindings can serve
as a reference harness; they need not become an application runtime dependency.
Kiwi's repository is BSD-3-Clause licensed; preserve applicable notices if code is
vendored. This bridge and its cross-platform packaging have not been built.
[Kiwi repository](https://github.com/nucleic/kiwi),
[license](https://github.com/nucleic/kiwi/blob/main/LICENSE).

## What to learn from Enaml

The current projects are under Nucleic. Enaml began at Enthought and was forked
into Nucleic in 2013; its license preserves both histories. Enaml itself is a
Python UI framework, so adopting its authoring ideas does not imply embedding
the framework in Moxi.
[Project](https://github.com/nucleic/enaml),
[history and license](https://github.com/nucleic/enaml/blob/main/LICENSE).

Enaml gets preferred dimensions from the underlying toolkit and expresses how
strongly a widget should keep them: `hug` prefers equality, `resist` opposes
compression, and `limit` opposes expansion. Its helpers let authors work with
rows, columns, and alignments instead of writing every equation. This offers a
richer authoring model than treating every natural size as an inflexible minimum.
[Constraint layout guide](https://enaml.readthedocs.io/en/latest/get_started/layout.html),
[helper API](https://enaml.readthedocs.io/en/latest/api_ref/layout/layout_helpers.html).

Enaml also scopes solvers: containers normally own separate solvers, with explicit
`share_layout` enabling relationships across container boundaries. Some widgets,
including scroll areas and notebooks, impose boundaries constraints cannot cross.
This is a concrete alternative to one global tableau for the whole application.
[Container contract](https://enaml.readthedocs.io/en/latest/api_ref/widgets/container.html).

For Moxi, prototype one explicitly owned constraint region. Its parent allocates
the region; the region owns descendant geometry. Do not let two algorithms write
the same bounds. Preserve stable identities and publish the result through the
existing paint/hit/accessibility geometry boundary. These are proposed Moxi rules,
not claims about Enaml's implementation.

Width-dependent paragraph height remains external to a linear solver. Measure
text at an allocated width, update the relevant size constraints, and test any
repeat-measure/solve loop for termination and stability. Breakpoint decisions and
line breaks cannot simply be encoded as one linear equality. An explicit overflow
or adaptive-layout policy is still required for a window smaller than its content.
Native text parity remains a prerequisite, regardless of solver choice.

## What to learn from xyflow

xyflow supplies React Flow and Svelte Flow plus a shared `@xyflow/system` package.
The shared package is JavaScript/TypeScript with dependencies including D3 drag
and zoom; it is not a native C layout library. Direct use would introduce a web
runtime boundary. For Moxi's native path, study the contracts first.
[Repository](https://github.com/xyflow/xyflow),
[system package](https://github.com/xyflow/xyflow/blob/main/packages/system/package.json).

React Flow explicitly delegates automatic layout to external engines. Its guide
covers Dagre, D3 hierarchy/force, and ELK and separates node placement from edge
routing. It also flags a Dagre limitation involving subflows connected to external
nodes. Cassowary can enforce chosen alignments or separations, but does not by
itself choose a graph's ranks, node ordering, or obstacle-avoiding edge routes.
[Layout guide](https://reactflow.dev/learn/layouting/layouting).

The useful contracts for a Moxi graph canvas are:

- Measure node content before placement; React Flow exposes a node-initialization
  signal once dimensions are known. Moxi should version measurements so stale
  asynchronous placement results cannot overwrite newer content.
  [Measurement lifecycle](https://reactflow.dev/api-reference/hooks/use-nodes-initialized).
- Keep parent-relative positions and movement bounds explicit. React Flow's
  `parentId` establishes relative positioning, while confinement is a separate
  option; grouping is not equivalent to ordinary markup nesting.
  [Subflows](https://reactflow.dev/learn/layouting/sub-flows).
- Design keyboard selection/movement, focus reveal, and announcements alongside
  pointer interaction. React Flow documents these features; they are a reference,
  not proof that a Moxi implementation would be accessible.
  [Accessibility](https://reactflow.dev/learn/advanced-use/accessibility).

The libraries are MIT licensed; paid examples and services have separate terms.
This research uses public documentation and does not depend on a Pro example.
[xyflow licensing model](https://xyflow.com/open-source).

## Next experiment and decision criteria

Build an isolated Kiwi C++/C-ABI experiment before changing production layout:

1. Reproduce the CSV summary insertion and resize fixtures with the same measured
   leaf sizes and overflow policy as Moxi/Taffy. Define weighted-fill behavior
   explicitly; a soft ratio equation alone need not reproduce clamp/redistribute.
2. Add an aligned form: labels of different natural widths share a trailing edge,
   fields share a leading edge, and buttons prefer equal widths. Resize through
   preferred-size compression and a required-minimum conflict. Report both violated
   preferences and the rejected requirement using author-facing node IDs.
3. Add a splitter/drag case with edit suggestions, stable unrelated positions,
   repeated add/remove, and many weak preferences competing with one medium rule.
   Verify the documented priority semantics and retained memory behavior.
4. Exercise wrapped text across line-break thresholds and font changes. Record
   measurement/solve iterations, convergence, overflow, and final geometry.
5. Measure creation, constraint edits, solve, measurement, bridge, publication,
   memory, and unchanged passes separately and together. Compare identical
   workloads, not upstream speed claims or the unrelated Taffy arena timings.

Choose Kiwi only if authoring improvements, correctness, diagnostics, packaging,
and end-to-end cost justify it. If scoped constraints succeed but ordinary trees
remain cheaper elsewhere, evaluate a hybrid; do not assume that outcome upfront.

A graph-canvas experiment is a separate follow-up: a small DAG with differently
sized nodes, a nested group, an edge crossing the group boundary, and a user-moved
node. Test placement/routing, preservation of user intent, coordinate transforms,
and keyboard focus. ELK is a candidate for that comparison, not a replacement for
measuring controls within each node.

Confidence is high about the separation of these responsibilities and moderate
that scoped Kiwi constraints would improve Moxi authoring. The aligned-form and
resize experiments, especially text convergence and integration costs, could
change that recommendation. No Kiwi/Enaml/xyflow code was installed, executed,
benchmarked, or integrated in the original research pass. Existing runtime tests were not
rerun because only documentation changed; production behavior is unchanged.

The follow-up [Kiwi experiment](../experiments/layout-kiwi/README.md) contains
a pinned C++ solver, a C ABI, native correctness fixtures, and a paired Mojo
comparison. It remains isolated from production layout.
