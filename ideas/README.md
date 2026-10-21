# Moxi ideas: expressive tools and new kinds of interaction

What could people create, understand, or control if structured math, plotting,
graphs, text, native controls, and spatial interaction were cleanly composable
and felt immediate to use? This portfolio explores that question across art,
programming, learning, design, mathematics, and collective decision-making.
Moxi's purpose is to make highly reactive, interactive UI clean to author,
smooth in use, and tactile in its response.

Existing implementations and plans are ingredients for imagining possibilities.
Their current demonstration applications do not set the product horizon.
Plotting contributes an expressive medium: a curve might specify behavior,
a distribution might be manipulated, or a trajectory might connect motion to
sound. It also remains useful as observation and feedback. The
[framework synthesis](FRAMEWORK.md) distinguishes these meanings and the
contracts that could support them.

## Product visions

These **15 speculative visions** are the active portfolio. Each has a small
standalone brief describing the experience, the role of the combined media,
a question a first experiment could answer, and evidence that would change
confidence. The [rankings](RANKINGS.md) assess expressive potential separately
from prototype cost. Neither is a release schedule or a measured market claim.

| Vision | What someone could do |
| --- | --- |
| [V01 — Draw executable behavior](v01-draw-executable-behavior.md) | Author executable responses, transitions, and constraints through their behavior. |
| [V02 — Compose worlds through rules](v02-compose-worlds.md) | Compose environments and emergent patterns by editing the rules that animate them. |
| [V03 — Invent a notation that becomes a tool](v03-invent-notations.md) | Make a domain language whose symbols have editing behavior and live meaning. |
| [V04 — Design across material, mechanism, and system](v04-design-across-scales.md) | Connect desired behavior to material response, geometry, and mechanisms. |
| [V05 — Make arguments spatial and executable](v05-executable-arguments.md) | Let readers change assumptions and inspect which conclusions still hold. |
| [V06 — Compose an experience across media](v06-compose-across-media.md) | Compose meaningful relationships among sound, motion, light, and interaction. |
| [V07 — Learn by changing a system](v07-learn-by-changing-systems.md) | Learn through prediction and manipulation, then connect experience to formal notation. |
| [V08 — Make invisible phenomena manipulable](v08-instruments-for-invisible-phenomena.md) | Give abstract relationships and machine-sensed phenomena inspectable perceptual forms. |
| [V09 — Compose how a space is experienced](v09-compose-lived-spaces.md) | Author journeys, reveals, and events across space and time. |
| [V10 — Negotiate possible futures together](v10-negotiate-possible-futures.md) | Express competing goals and explore shared alternatives without hiding disagreement. |
| [V11 — Turn patterns into structures](v11-patterns-become-structures.md) | Move between generative patterns, construction rules, and physical structures. |
| [V12 — Make interfaces into personal instruments](v12-personal-instruments.md) | Author interaction mappings that fit an individual’s task and way of acting. |
| [V13 — Wire an executable instrument](v13-visual-instrumentation.md) | Assemble acquisition, computation, controls, and outputs into an inspectable instrument. |
| [V14 — Give a robot predictive chemical perception](v14-robot-nose.md) | Explore whether chemical sensor input helps a robot anticipate meaningful outcomes. |
| [V15 — Play a tool with the whole hand](v15-hand-pose-control.md) | Author continuous multidimensional control through camera-estimated hand movement. |

### Distinctions worth preserving

- **V01 and V03:** author behavior in a supplied language versus author the
  notation and editing rules of a language itself.
- **V02 and V10:** compose a simulated world versus negotiate preferences and
  alternatives among people. Simulation cannot decide a group's values.
- **V04 and V11:** work across behavioral and mechanical scales versus move
  between a generative craft pattern and its constructed form.
- **V06 and V09:** compose across sensory media versus compose an experience
  anchored to a spatial journey.
- **V07 and V08:** author a learning experience versus build an instrument for
  exploring an abstract or machine-sensed phenomenon. Either could use the other.
- **V05 and V10:** inspect an argument's support versus make a shared decision
  while preserving different goals.
- **V03 and V12:** define a domain's expressive language versus adapt the way a
  person operates an existing domain. Neither requires arbitrary hot reload.
- **V01 and V13:** author desired behavior versus assemble and operate its
  mechanism. An instrument can offer both workflows.
- **V08 and V14:** a broad family of perceptual instruments versus one concrete
  chemical-sensing and prediction opportunity, with its own empirical burden.
- **V12 and V15:** personal interaction authoring versus a specific continuous
  hand-input medium. V14 senses the world; V15 expresses intentional control.

Not every product needs every representation. A powerful 2D instrument can be
more useful than adding 3D without a domain reason. The horizon stays broad
while each experiment tests a specific interaction claim.

## Earlier concepts and supporting mechanisms

The **21 earlier briefs** remain available under their original filenames.
They preserve useful experiences, implementation probes, and architectural
ideas. Their former composite ranking is retained in
[historical rankings](HISTORICAL-RANKINGS.md), explicitly superseded as portfolio
guidance. It rewarded closeness to current work multiple times through fit,
reuse, and feasibility, and mixed framework mechanisms with product ambitions.

The table below records how those concepts contribute now. A contributor is
not a required dependency; each product can discover a smaller solution.

| Earlier idea | Current role |
| --- | --- |
| [I01 — A sketch that gradually becomes an instrument](i01-progressively-executable-sketch.md) | Progressive formalization in [V01](v01-draw-executable-behavior.md), [V03](v03-invent-notations.md), [V11](v11-patterns-become-structures.md) |
| [I02 — Mathematics you can physically interrogate](i02-tangible-mathematics.md) | Mathematical interaction in [V07](v07-learn-by-changing-systems.md), [V08](v08-instruments-for-invisible-phenomena.md) |
| [I03 — Design by pulling on consequences](i03-inverse-design.md) | Inverse-editing research for [V01](v01-draw-executable-behavior.md), [V04](v04-design-across-scales.md) |
| [I04 — Mind maps of possible worlds](i04-possible-worlds.md) | Alternatives and branching in [V02](v02-compose-worlds.md), [V10](v10-negotiate-possible-futures.md) |
| [I05 — Instruments you can pick up and attach](i05-attachable-instruments.md) | Composable instruments in [V08](v08-instruments-for-invisible-phenomena.md) |
| [I06 — Semantic zoom as a way of thinking](i06-semantic-zoom.md) | Navigation across scale and meaning in [V02](v02-compose-worlds.md), [V07](v07-learn-by-changing-systems.md), [V09](v09-compose-lived-spaces.md) |
| [I07 — An explanation you can perform](i07-performed-explanations.md) | Authored explanation and performance in [V05](v05-executable-arguments.md), [V06](v06-compose-across-media.md), [V07](v07-learn-by-changing-systems.md), [V09](v09-compose-lived-spaces.md) |
| [I08 — A debugger for your reasoning](i08-reasoning-debugger.md) | Explicit reasoning in [V05](v05-executable-arguments.md), [V10](v10-negotiate-possible-futures.md) |
| [I09 — Make an instrument panel from what matters](i09-curated-instrument-panels.md) | A smaller packaging mechanism within [V12](v12-personal-instruments.md) |
| [I10 — A laboratory where observations become tools](i10-investigations-become-tools.md) | A narrower data-investigation opportunity; no privileged position in the broad portfolio |
| [I11 — Agents that work visibly inside your tools](i11-visible-agent-work.md) | Optional agent interaction pattern across products; no product requires it |
| [I12 — An application that grows new instruments while you use it](i12-live-tool-authoring.md) | Authoring mechanisms relevant to [V03](v03-invent-notations.md), [V12](v12-personal-instruments.md) |
| [I13 — A visual debugger you can climb inside](i13-visual-execution-debugger.md) | Developer tooling; assessed through actual consumer debugging needs |
| [I14 — A playable mathematics and motion studio](i14-mathematics-and-motion-studio.md) | Creative mathematical interaction in [V06](v06-compose-across-media.md), [V08](v08-instruments-for-invisible-phenomena.md) |
| [I15 — A flight recorder for experiments and incidents](i15-experiment-flight-recorder.md) | Capture and reproducibility mechanism where a consumer needs it |
| [I16 — An executable essay that becomes a workbench](i16-executable-essay.md) | Authored narrative in [V05](v05-executable-arguments.md), [V07](v07-learn-by-changing-systems.md) |
| [I17 — One instrument with several bodies](i17-one-instrument-many-bodies.md) | Alternative input/output forms in [V06](v06-compose-across-media.md), [V12](v12-personal-instruments.md) |
| [I18 — Coordinated representations of the same object](i18-coordinated-representations.md) | Supporting architecture: [identity and representations](FRAMEWORK.md#questions-that-recur-across-products) |
| [I19 — An interaction as an inspectable object](i19-inspectable-interactions.md) | Supporting architecture: [interaction sessions](FRAMEWORK.md#questions-that-recur-across-products) |
| [I20 — Application operations across interaction styles](i20-reusable-application-operations.md) | Supporting architecture: [domain operations](FRAMEWORK.md#questions-that-recur-across-products) |
| [I21 — A living linkage sketch](i21-living-linkage-sketch.md) | A bounded mechanism probe for [V04](v04-design-across-scales.md), [V11](v11-patterns-become-structures.md) |

The first brainstorm's nine ideas are I01–I09; the second's eight are I10–I17.
I18–I20 capture shared architecture and I21 the living-linkage demonstration.
The active visions broaden and recombine that material rather than deleting
it or treating near-term demonstrations as the limits of the medium.

The [execution plan](../PROJECT-PLANNING.md) governs scheduled work. This
portfolio does not change its gates. Conversely, those gates do not determine
which speculative product has the most potential.

## Evidence and shared requirements

The preceding investigation inspected the implementation checkout at
`c8c7cbb7741519c9796a02ffa25c02e701b2f58a` and the planning branch through
`87cc6981a87e2ff1e2076ed91417b44c1e5e5db1`. Source links below are pinned to the
implementation commit; planning links are local and evolve with their plans.
The two modified implementation documents (`docs/API.md` and
`docs/capability-bus-design.md`) are not treated as committed evidence here.
This revision uses that earlier evidence only to identify possible ingredients;
it does not refresh implementation support claims. No builds, benchmarks,
native acceptance sessions, user studies, or market comparisons were run for
this portfolio. All V01–V15 integrations are proposed.

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
  glue-code volume, keyboard behavior, and measured latency should inform
  experiment cost and framework extraction. Product potential needs separate
  evidence that people gain useful expressive or practical agency.
