# Mathematical notation as compositional UI

Status: speculative idea, captured October 22, 2026. Not scheduled work.
Origin: connecting the compositional plotting and UI discussions to Moxi's
native math-editing proposal and Bret Victor-style inspectable interaction.

## Experience

Use mathematical notation as a concrete proving ground for compositional UI.
Fractions, radicals, scripts, and matrices form a small language whose
expressions are also interactive interfaces. Each construct contributes child
roles, layout, caret navigation, selection behavior, hit testing, and accessible
meaning. Nesting constructs should combine those local contracts into coherent
global interaction without special handling for every surrounding expression.

In the math proposal's illustrative text form, `frac(a, sqrt(b))` combines the
fraction's numerator/denominator roles with the radical's body and entry/exit
positions. The question is whether a new construct can define its own local
rules and compose with existing ones predictably. Compact spelling alone is
not the goal; understandable construction and manipulation are.

## Contexts with holes as an editing vocabulary

Selecting `a + b` and wrapping it in a radical creates the context `sqrt(□)`
and fills its hole with that selection. Fraction insertion, superscripting,
and function application suggest related structural operations: wrap, fill,
extract, replace, duplicate, and unwrap.

The same method could inform UI authoring through contexts such as `scroll(□)`
or `row(label("Speed"), □)`. These spellings are hypothetical, not implemented
Mojo APIs. Share a structural-editing approach only where it proves useful;
math slots and UI slots retain domain-specific compatibility, ownership, and
lifetime rules. Moving math across a binding boundary can capture a formerly
free variable, so structural validity alone does not establish preserved meaning.

## Keep notation, interaction, and algebra distinct

The existing math proposal's authoritative lossless notation tree and bounded
semantic projection remain separate. Preserve explicit grouping, spelling,
holes, and incomplete states during ordinary editing. Layout and navigation
compose over notation; computation interprets a supported, disambiguated
selection with explicit bindings and assumptions.

A structural operation changes the construction. An algebraic rewrite makes
an additional claim about mathematical meaning. For example, distributing
`x * (a + b)` to `x*a + x*b` requires an interpretation where that law applies;
replacing `x/x` with `1` requires an appropriate domain and a nonzero assumption.
A generic tree rearrangement cannot establish either claim. UI wrapper
reordering likewise cannot assume preserved appearance or behavior.

An eventual rewrite interaction could show the proposed result, applicable
assumptions, and correspondence between source and result before applying one
undoable transaction. Bind results to the source revision and preserve the
proposal's stale-result rejection. A useful live view could expose a selected
subexpression's role, compatible wrappers, available transformations, and
previews without requiring a CAS for ordinary editing.

## Foundations and evidence boundary

Planning material reviewed October 22, 2026:
[native mathematical typesetting and editing](../docs/design/math-editing.md)
on `project-planning`, whose committed baseline is
`5d0786a60fbce4af339b904cdf1aec419e7aec44`. It already proposes stable notation
IDs, explicit child roles, holes, two losslessly corresponding editable forms,
structural transactions, and a separate semantic adapter. These are proposed
contracts, not verified implementation behavior.

The companion [UI-composition](compositional-ui-language.md) and
[plot-composition](compositional-plot-instruments.md) briefs are local,
uncommitted captures from this discussion. This idea depends on their framing,
not on implemented APIs. No source-behavior audit, build, test, benchmark,
symbolic-backend verification, or usability study was performed for this capture.
No remote refresh or external Bret Victor source review was performed.

## First question to test

Can locally defined construct rules produce predictable editing through nested
fractions and radicals without accumulating parent-specific exceptions?
Exercise one journey: select, wrap, navigate into and out of nested slots,
unwrap, then undo. Check restored content and selection, unchanged-node
identity, consistent drawing/hit-test geometry, keyboard focus, accessibility
structure, and lossless text/2D correspondence, including holes.

Record the amount of construct-specific glue and whether another author can
predict navigation through unfamiliar nesting. Introduce symbolic rewrite
previews only as a later experiment with explicit semantic preconditions.
A universal expression representation shared by math and UI, automatic algebra
during typing, a general CAS, and a full UI authoring studio are outside this
probe. It does not replace or expand the math proposal's release sequence.

Confidence: **Moderate**. The proposed notation and transaction boundaries
make this a useful shared experiment. Predictable unfamiliar nesting and less
special-case code would strengthen it; growing parent-specific exceptions,
fragile focus, or forced semantic unification would favor narrower reuse.

Related: [composition of the UI itself](compositional-ui-language.md),
[compositional plot instruments](compositional-plot-instruments.md), and
[invented notations](v03-invent-notations.md).
Return to the [idea collection](README.md#composition-experiments).
