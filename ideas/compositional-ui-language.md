# Composition of the UI itself

Status: speculative idea, captured October 22, 2026. Not scheduled work.
Origin: discussion of lambda calculus, regex, and APL/J/K composition applied
to Moxi's interface construction, with a Bret Victor-style live editing horizon.

## Experience

Make the interface itself an inspectable composition. A small vocabulary
combines individual controls and whole compositions, while recurring shapes
become reusable phrases. An author can move between a compact expression,
expanded structure, and its live interface.

Four useful families of operations are spatial arrangement (beside, below,
over), transformations (padding, constraints, clipping, scrolling, styling),
repetition across collections, and behavioral connections to state, actions,
focus, and selection. They need explicit semantics; they need not become one
universal operator system.

Hypothetical notation, not a proposed or implemented Mojo API:

```text
scroll(
  column(
    map(settings, setting =>
      row(label(setting.name), editor(setting.value))
    )
  )
)
```

The recognizable shape is a repeated labeled editor arranged vertically in a
scrolling region. Naming it `property_editor` could make the same relationship
usable for preferences, plot configuration, and object inspection. Metadata
can supply labels, ranges, and editor choices with explicit exceptions.

## Compose relationships as well as appearance

A slider and numeric editor should share one authoritative value. A
master-detail composition should connect selection in one child to the content
of another. Candidate phrases such as `paired_editors` and `master_detail`
capture state connections and interaction expectations as well as layout.
Their implementation must expose mutation ownership and resource lifetimes.

Operation order matters. Under ordinary wrapper semantics,
`pad(background(view))` paints behind the original view before adding exterior
space; `background(pad(view))` paints behind the padded region. Scrolling a
whole column differs from making one child scroll independently. The author
should be able to inspect those differences immediately.

Identity is part of meaning: two instances of a reusable child need distinct
identities, and rebuilding an instance must retain its state. Repetition needs
stable keys through insertions and reordering. Wrapping, extraction, and
regrouping must specify whether they preserve focus, event routing, state,
accessibility order, clipping, and layout behavior; equivalence is not assumed.

## Possible Moxi boundary

Explore a compositional authoring layer that lowers to the existing flat
`ColumnView`/`ViewNode` representation. Reuse `ComponentSlot` namespacing and
the retained runtime where their contracts fit. A new authoring surface does
not require replacing the renderer or reconciliation model.

A later structural editor could select a region, wrap it, reorder modifiers,
extract a repeated phrase, or expand a named composition with immediate visual
feedback. Transformations require their own preservation rules; distributing
a wrapper across children is not generally equivalent to wrapping their parent.
Keyboard access, cancellation, undo, and accessible alternatives remain part
of the experience. This editor is a horizon, not a prerequisite for a probe.

## Foundations and evidence boundary

Documentation inspected on October 22, 2026: implementation branch `main` at
`fa42c7b2ab1683db084347e4d2dd88babda69f40`.
[Architecture](https://github.com/davidmashburn/moxi/blob/fa42c7b2ab1683db084347e4d2dd88babda69f40/ARCHITECTURE.md)
describes value-based components, flat view declarations, stable reconciliation
identity, and typed child composition through `ComponentSlot`.
[API ergonomics](https://github.com/davidmashburn/moxi/blob/fa42c7b2ab1683db084347e4d2dd88babda69f40/docs/api-ergonomics.md)
identifies compile-time and diagnostic burden as existing concerns.
These documents establish possible ingredients, not support for the proposed
authoring language or state-binding semantics.

The implementation checkout has unrelated edits to `pixi.toml` and untracked
demo artifacts; this idea does not depend on them. No source-behavior audit,
build, test, benchmark, or usability study was performed for this capture.
The remote was not refreshed, so the baseline identifies the local commit.

## First question to test

Can a small composition express a repeated property editor with paired numeric
controls more clearly than hand wiring, while preserving identity and behavior?
Use two independently mounted instances, one application-owned value per pair,
and a keyed collection. Insert and reorder entries, rebuild, and apply a
padding/background order change. Observe state retention, focus, event routing,
visual consequences, authoring burden, and compiler diagnostics.

Keep application-specific bindings explicit. Do not begin with a universal
schema, arbitrary bidirectional binding, full visual editor, new effect system,
or runtime rewrite. Extract additional primitives only from repeated consumer
needs. Any prototype must define the preservation rules it actually checks.

Confidence: **Moderate**. Value-based views and namespaced child composition
suggest a plausible starting point. Reduced wiring with predictable state and
focus would strengthen it; brittle identities, opaque diagnostics, or complex
lifetime plumbing would favor simpler helpers. Stateful relationship reuse is
the central hypothesis to test beyond existing spatial containers.

Related: [compositional plot instruments](compositional-plot-instruments.md),
[invented notations](v03-invent-notations.md),
[personal instruments](v12-personal-instruments.md), and
[reusable application operations](i20-reusable-application-operations.md).
Return to the [idea collection](README.md#composition-experiments).
