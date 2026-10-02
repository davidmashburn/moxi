# Constraint region candidate

`moxi.constraint_layout` uses the pinned Kiwi 1.5.0 C bridge from the layout
experiment. Run `pixi run constraint-layout-check`; its bootstrap verifies commit
`5e76d91fd77dc443cb0db36e7398fc13844a0524`. This remains an optional candidate
dependency, not a root API export or a claim of supported-target packaging.

Declare a region's stable child keys and immutable `LinearConstraint` values with
`model`. `coordinate(key, axis)` addresses x, y, width and height; parent width
and height have separate reserved IDs. Foreign variables are rejected. The region
adds required nonnegative coordinates and containment within its exact parent
allocation. Child constraints cannot grow that parent to hide a conflict.

`stage(size)` creates a tentative solver and rectangles. Failed required
constraints destroy that tentative solver and keep published rectangles intact.
Inspect optional `residuals`, convert the rectangles into retained placements,
stage the complete tree, validate the constraint plan, publish global geometry,
then `commit(plan)`. No callbacks or source mutations may intervene between the
validation and these commits. An unchanged model/allocation reuses the solver
without solver mutation. A changed pass rebuilds a bounded region instead of
accumulating retired variable or constraint IDs. Retained plans own their solver;
discard obsolete plans to release it.

Optional strengths are numeric weighted objectives; they are not lexicographic
priority levels. `REQUIRED` uses Kiwi's required threshold. Zero and finite
optional strengths are allowed, and required failures are reported as errors.
The native bridge contains exceptions; unexpected internal/OOM errors require
discarding that tentative context, which the wrapper's ownership already does.

Tests cover exact allocation, conflict rollback, unchanged model reuse, stale
plans, optional residuals and 1,000 rebuilds. Native IME/accessibility, composed
screen behavior and platform packaging are separate integration gates.
