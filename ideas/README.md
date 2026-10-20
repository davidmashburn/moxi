# Moxi ideas

Capture of both October 20, 2026 brainstorms: what becomes possible when
existing Moxi implementations and plans compose with structured math, mind
mapping, native canvases, and spatial interaction.

The shared vision is a workspace where ideas acquire handles and become live
instruments. People can think, calculate, investigate, design, explain, and
reshape tools within a coherent interactive experience. Moxi's purpose remains
clean application code and smooth, tactile interaction.

This collection contains **21 small idea documents**: 17 product concepts,
three framework concepts, and one concrete demonstrator. They are speculative,
not scheduled work or new support claims. The
[execution plan](../PROJECT-PLANNING.md) and
[workbench hardening](../WORKBENCH-HARDENING-PLAN.md) retain their priorities.
See [rankings](RANKINGS.md) for the comparative assessment and experiment order.

## Complete reference and conversation coverage

IDs preserve capture order; they do not indicate priority. Each row maps a
distinct proposal from the conversation to a small standalone document.
Overlapping concepts stay separate so their distinctive interactions survive.

| ID and idea | Kind | Conversation origin |
| --- | --- | --- |
| [I01 — A sketch that gradually becomes an instrument](i01-progressively-executable-sketch.md) | Product | First brainstorm, idea 1 |
| [I02 — Mathematics you can physically interrogate](i02-tangible-mathematics.md) | Product | First brainstorm, idea 2 |
| [I03 — Design by pulling on consequences](i03-inverse-design.md) | Product | First brainstorm, idea 3 |
| [I04 — Mind maps of possible worlds](i04-possible-worlds.md) | Product | First brainstorm, idea 4 |
| [I05 — Instruments you can pick up and attach](i05-attachable-instruments.md) | Product | First brainstorm, idea 5 |
| [I06 — Semantic zoom as a way of thinking](i06-semantic-zoom.md) | Product | First brainstorm, idea 6 |
| [I07 — An explanation you can perform](i07-performed-explanations.md) | Product | First brainstorm, idea 7 |
| [I08 — A debugger for your reasoning](i08-reasoning-debugger.md) | Product | First brainstorm, idea 8 |
| [I09 — Make an instrument panel from what matters](i09-curated-instrument-panels.md) | Product | First brainstorm, idea 9 |
| [I10 — A laboratory where observations become tools](i10-investigations-become-tools.md) | Product | Second brainstorm, idea 1; recommended data-workbench experiment |
| [I11 — Agents that work visibly inside your tools](i11-visible-agent-work.md) | Product | Second brainstorm, idea 2 |
| [I12 — An application that grows new instruments while you use it](i12-live-tool-authoring.md) | Product | Second brainstorm, idea 3 |
| [I13 — A visual debugger you can climb inside](i13-visual-execution-debugger.md) | Product | Second brainstorm, idea 4 |
| [I14 — A playable mathematics and motion studio](i14-mathematics-and-motion-studio.md) | Product | Second brainstorm, idea 5 |
| [I15 — A flight recorder for experiments and incidents](i15-experiment-flight-recorder.md) | Product | Second brainstorm, idea 6 |
| [I16 — An executable essay that becomes a workbench](i16-executable-essay.md) | Product | Second brainstorm, idea 7 |
| [I17 — One instrument with several bodies](i17-one-instrument-many-bodies.md) | Product | Second brainstorm, idea 8 |
| [I18 — Coordinated representations of the same object](i18-coordinated-representations.md) | Framework | Shared synthesis in both brainstorms |
| [I19 — An interaction as an inspectable object](i19-inspectable-interactions.md) | Framework | First brainstorm's interaction synthesis; extended by replay and live instruments |
| [I20 — Application operations across interaction styles](i20-reusable-application-operations.md) | Framework | Second brainstorm's framework synthesis |
| [I21 — A living linkage sketch](i21-living-linkage-sketch.md) | Demonstrator | First brainstorm's proposed first demonstration |

The first brainstorm's nine numbered ideas are I01–I09. The second's eight are
I10–I17. I18–I20 preserve the cross-cutting architectural ideas instead of
burying them in product descriptions. I21 preserves the living-linkage demo;
the data-workbench demonstration is the staged experiment in I10.

## Overlaps that are intentional

- **I09 and I12:** selecting existing controls to package a panel versus
  writing or replacing behavior while an application is running.
- **I07 and I16:** performing an interruptible explanation versus authoring a
  persistent narrative document with editable evidence.
- **I08, I13, and I15:** reasoning provenance, software execution diagnostics,
  and captured external episodes respectively.
- **I01 and I10:** progressive formalization of a creative sketch versus a
  data investigation grounded in the existing workbench.
- **I18, I19, and I20:** coordinated identity and representations, interaction
  transactions, and reusable operations. These are candidate contracts to
  extract from consumers, not prerequisites to implement in full.

## Evidence and shared requirements

The preceding investigation inspected the implementation checkout at
`c8c7cbb7741519c9796a02ffa25c02e701b2f58a` and the planning branch through
`87cc6981a87e2ff1e2076ed91417b44c1e5e5db1`. Source links below are pinned to the
implementation commit; planning links are local and evolve with their plans.
The two modified implementation documents (`docs/API.md` and
`docs/capability-bus-design.md`) are not treated as committed evidence here.
No builds, benchmarks, native acceptance sessions, user studies, or market
comparisons were run for this capture.

| Foundation | Evidence and boundary |
| --- | --- |
| [Component/runtime foundations](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/features.md) | Typed components, retained identity, native semantics, and localized updates are documented implementation foundations; support varies by host. |
| [Plotting and linked selections](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/plotting.md) | Stable observation keys, explicit linked selection, statistical recipes, and retained plot updates exist within documented coverage. |
| [Existing data workbench](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/data-workbench.md) | The numerical workbench supplies the concrete consumer for I10; its documented experimental and native-validation limits still apply. |
| [Python value boundary and exports](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/python.md) | Versioned plot values and headless exports exist; a native Python-driven UI runtime is not implied. |
| [In-process capability bus](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/capability_bus.mojo) | Synchronous in-process operation policy and typed handlers exist; transport, distributed orchestration, and a model client do not follow from this. |
| [Conversation context](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/conversation.mojo) | Conversation payload/context handling exists; it is not a bundled agent service. |
| [Reloadable scene shell](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/live_script.mojo) | A development scene-module shell exists; arbitrary component hot replacement and state migration remain proposals. |
| [Normalized event fixtures](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/event_replay.mojo) | Versioned normalized-event fixtures exist; full semantic history or reproduction of external systems requires additional capture. |
| [Localized execution](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/execution.mojo) | Localized work counters and execution provide diagnostics ingredients, not a full causal profiler. |
| [Scoped request scheduler](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/tasks.mojo) | Scoped deterministic scheduling rejects stale/detached results; real transport and worker ownership remain adapter work. |
| [Proposed math editing](../docs/design/math-editing.md) | WYSIWYG structured editing and its lossless text representation are planned, not assumed implemented. |
| [Proposed mind mapping](../docs/design/mind-mapping.md) | Native keyboard-first mind mapping is planned. |
| [Proposed canvas interactions](../docs/design/canvas-interaction.md) | Rich native canvas composition, gestures, commands, and transactions are planned. |
| [Proposed 3D interfaces](../docs/design/3d-interaction.md) | Viewport embedding, manipulation, and world-space interfaces have separate proposed gates; existing Metal support does not prove 3D readiness. |
| [Host architecture plan](../CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md) | Portable semantic/host boundaries are planned alongside varying implemented host slices; multi-device synchronization and full target parity are not supplied. |

All experiments inherit these requirements:

- Every mathematical layout state has a one-to-one human-readable/editable
  text counterpart, including incomplete states. WYSIWYG stays primary.
  Derived plots and geometry need explicit mappings; they are not automatically
  lossless representations.
- Keyboard interaction is a primary authoring route. **Primary means Cmd on
  macOS and Ctrl on Windows/Linux**. Any literal-Ctrl exception needs a
  per-command reason. Preserve native text editing and existing reference
  shortcut profiles.
- Tactile behavior includes immediate bounded previews, clear constraints,
  predictable snapping, cancellation, coherent undo, and reduced-motion and
  accessible alternatives. Device haptics are optional future adapters.
- Application-owned state, stable identity, explicit operations, resource
  lifetimes, and revision checks remain visible contracts. No universal
  document schema, implicit inverse solver, or all-purpose effect system is
  implied.
- Prefer permissive licensing. New CAS, solver, rendering, audio, device, or
  transport dependencies require an explicit license and boundary assessment;
  no new dependency is selected by this collection.
- A useful consumer precedes a new shared abstraction. Prototype failures,
  glue-code volume, keyboard behavior, and measured latency should change
  these rankings.
