# Compositional plot instruments

Status: speculative idea, captured October 22, 2026. Not scheduled work.
Origin: discussion of composition in lambda calculus, regex, and APL/J/K,
followed by the connection to Bret Victor's inspectable, live systems.

## Experience

Let someone assemble a data instrument from a small vocabulary of transforms,
marks, layouts, and selection relationships. A useful composition becomes a
named phrase that can be applied to another compatible field or dataset.
Compact notation, an expandable explanation, intermediate data, and the live
result expose the same construction at different levels of detail.

For example, a reusable distribution explorer could show a histogram and ECDF
of a supplied field, share selection between them, and highlight the selected
rows in a table. Applying the phrase to another field preserves those
relationships without manually wiring every panel again. Repetition across
fields, groups, or facets is a candidate operation, subject to explicit data
and scale semantics.

The goal is semantic compression: a small expression captures a substantial,
understandable behavior. Terse symbols alone do not provide that benefit.

## Composition and inspection

- Compose pure data transforms separately from marks and spatial arrangement.
  Selecting a transform reveals its input and output before geometry is made.
- Treat selections as values that can be combined by union, intersection, or
  exclusion, then used to filter, summarize, or highlight data in another view.
  Distinguish filtering rows from highlighting rows in their full context.
- Require compatible row identity for direct selection composition. Linking
  different datasets needs an explicit key relationship and handling for
  missing or duplicate matches.
- Make relationships inspectable: a panel can explain that it shows rows
  selected in A and excluded by B. Preserve explicit update ownership rather
  than introducing hidden global propagation.
- Let structural edits preview their consequences. An optional agent adapter
  could propose a field replacement, layer, or link as a concrete edit; the
  capability bus governs applying mutations, not pure expression evaluation.

Algebraic laws would make compositions dependable: name which substitutions
preserve results and which change ordering, scale domains, row identity, or
interaction behavior. Optimization follows only where those laws hold.

## Foundations and evidence boundary

Documentation inspected on October 22, 2026: implementation branch `main` at
`fa42c7b2ab1683db084347e4d2dd88babda69f40`.
[Plotting contracts](https://github.com/davidmashburn/moxi/blob/fa42c7b2ab1683db084347e4d2dd88babda69f40/docs/plotting.md)
describe serializable `PlotSpec`, pure statistical recipes, stable row keys,
explicit `PlotLink` propagation, localized updates, and shared Scene consumers.
[Architecture](https://github.com/davidmashburn/moxi/blob/fa42c7b2ab1683db084347e4d2dd88babda69f40/ARCHITECTURE.md)
documents the capability policy boundary and application-owned mutation.
These are documented ingredients, not verification of the proposed integration.

The implementation checkout has unrelated edits to `pixi.toml` and untracked
demo artifacts; this idea does not depend on them. No source-behavior audit,
build, test, benchmark, or usability study was performed for this capture.
The remote was not refreshed, so the baseline identifies the local commit.

## First question to test

Can an author reuse one linked distribution explorer for a second field and
correctly predict the effect of changing a transform or selection relationship?
Use one dataset with stable row keys, histogram/ECDF/table views, and one
inspectable selection expression. Expose intermediate rows and derive all
presentations from the same bounded construction.

Evidence to collect: duplicated wiring avoided, ability to explain selected
rows, preservation of row identity through transforms, and predictable updates
after replacing the field. Check equivalent expressions against the same
headless scenario where an equivalence is explicitly claimed. General-purpose
language design, automatic cross-dataset joins, arbitrary code reload, and a
full authoring studio are outside the first experiment.

Confidence: **Moderate**. Existing declarative and stable-key boundaries make
this a plausible experiment. Successful reuse by a second author would raise
confidence; substantial hidden state, bespoke wiring, or confusing selection
semantics would favor a narrower reusable recipe. If basic component assembly
is the larger user burden, prioritize the companion UI-composition experiment.

Related: [composition of the UI itself](compositional-ui-language.md),
[invented notations](v03-invent-notations.md),
[investigations becoming tools](i10-investigations-become-tools.md), and
[coordinated representations](i18-coordinated-representations.md).
Return to the [idea collection](README.md#composition-experiments).
