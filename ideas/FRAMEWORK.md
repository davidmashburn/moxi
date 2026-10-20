# Framework questions raised by the visions

Moxi's purpose is to make highly reactive, interactive interfaces clean to
author, smooth to use, and tactile in their response. The
[product visions](README.md) test what that purpose could enable across domains.
This document collects supporting contracts; they do not compete with products
in the [potential ranking](RANKINGS.md).

## Capabilities as creative ingredients

Plotting, structured math, graphs, native controls, text, and spatial interaction
are possible media for an application. Existing demonstrations provide evidence
about individual capabilities. Their workflows do not define the application's
scope. A product should use the representations that clarify its domain; it
does not need every component to qualify as a Moxi idea.

| Ingredient | Creative role | Contract to investigate |
| --- | --- | --- |
| Plots and curves | Specify a response, reshape a distribution, inspect a consequence, or compare alternatives | Explicit role, units, sample/model ownership, and edit interpretation |
| Structured math | Author precise relationships within a visual experience | Exact one-to-one human-readable/editable text and 2D layout, including incomplete states |
| Graphs and mind maps | Express rules, assembly, alternatives, arguments, and navigation | Domain-defined edge meaning and stable identity; a visual edge alone has no execution semantics |
| Native controls and text | Make exact values, commands, prose, and accessible navigation available everywhere | Stable focus, text editing, command discovery, and keyboard parity inside transformed views |
| 2D and 3D space | Work with motion, geometry, fields, arrangement, and embodied consequences | Explicit coordinate spaces, picking, meaningful constraints, and a semantic navigation route |
| Reactive execution | Keep consequences attached to an edit | Bounded previews, cancellation, result freshness, and understandable ownership |
| Capability operations | Expose the same domain action through multiple input routes | Typed intent, preconditions, revision checks, and coherent commit/undo |
| Optional agents and live authoring | Propose alternatives or extend a tool in place | Inspectable changes through the same domain operations; no dependency on an opaque agent service |

## Questions that recur across products

| Question | Consumers that can test it | Earlier brief |
| --- | --- | --- |
| How does selection keep its meaning across notation, curve, graph, and scene? | V01 behavior; V08 mathematical instruments; V11 craft | [I18 — Coordinated representations](i18-coordinated-representations.md) |
| How do preview, snapping, constraints, cancellation, and undo form one understandable action? | V04 mechanisms; V06 media composition; V12 personal instruments | [I19 — Inspectable interactions](i19-inspectable-interactions.md) |
| How can pointer, keyboard, authored sequence, and optional agent invoke the same action? | V03 notation; V10 negotiation; V12 personal instruments | [I20 — Reusable application operations](i20-reusable-application-operations.md) |
| How can an author package or redefine meaningful controls? | V03 notation; V06 media composition; V12 personal instruments | [I09 — Curated panels](i09-curated-instrument-panels.md), [I12 — Live tool authoring](i12-live-tool-authoring.md) |
| How can developers explain delayed or inconsistent feedback? | Any implemented probe with an actual interaction failure | [I13 — Visual execution debugger](i13-visual-execution-debugger.md), [I15 — Flight recorder](i15-experiment-flight-recorder.md) |

These are candidate abstractions to discover through consumers. For example,
a curve editing command can carry a domain-specific edit intent without a
universal inverse-solving engine. A time relationship can be shared without
running an audio callback on the UI scheduler. A shared selection can retain
identity without forcing all document types into one schema.

## Distinguish the meanings of a plot

An **observation** records something; a **prediction** is produced by a model;
a **specification** states a desired behavior; a **constraint** bounds allowed
behavior; a **control mapping** translates an input into an operation. A product
can coordinate these roles, but changing one role into another is an explicit
operation with provenance. Editing an observed trace should not silently alter
source evidence, and pulling a predicted curve should not silently solve for
an arbitrary underlying program.

The exact text/layout guarantee belongs to the structured math document.
Sampled curves, spatial projections, simulation output, and aggregate plots
may lose information. Their edit mappings need clear ownership and declared
limits; matching their appearance does not establish semantic equivalence.

## What a successful probe must show

A domain task should expose both the user's experience and the application's
authoring cost. Record the interaction path, keyboard equivalent, preview and
commit behavior, observed latency, and the amount of domain glue needed to keep
views coherent. Test a rejected edit and recovery as well as the happy path.
Extract shared API only when another consumer needs the same contract.

Follow the [shared requirements](README.md#evidence-and-shared-requirements),
including Cmd on macOS / Ctrl on Windows and Linux for primary shortcuts,
accessible alternatives, predictable cancellation, and permissive dependency
preferences. Device haptics are optional; tactile interaction is also about
timing, resistance, snapping, and continuity on an ordinary desktop.

Confidence: **Moderate** that these questions recur, **Low** that any particular
shared API is established. Two distinct consumers sharing a small contract
would strengthen the case; domain exceptions dominating the interface would
favor keeping more behavior application-owned. No new runtime support is
claimed by this design synthesis.
