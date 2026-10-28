# UI authoring and update patterns

Research snapshot: October 27, 2026. This inventory follows the
[composition authoring draft](composition-authoring-draft.md). It is research,
not an adopted API, performance ranking, or implementation plan. The user remains
unconvinced by the draft's authoring comfort. The next comparison should widen
the design space rather than polish that interface by default.

The useful distinction is **how the author expresses a relationship, who owns
the state, and what the runtime recomputes**. Those are separate choices. A short
binding can drive retained objects, fine-grained updates, or a recomputed view.
Recomputing a view description does not imply recreating widgets or repainting
the whole screen.

## Raph's framework for the comparison

Raph Levien's [2019 reactive UI inventory](https://raphlinus.github.io/ui/druid/2019/11/22/reactive-ui.html)
separates the stages from application data through widget/render trees, layout,
and drawing. Trees may be stored values or an execution trace; push, pull,
diffing and dependency tracking can operate at different stages. That prevents
us from treating either "declarative" or "immediate" as a complete architecture.

His [2020 principled reactive UI essay](https://raphlinus.github.io/rust/druid/2020/09/25/principled-reactive-ui.html)
also foregrounds observation, mutation and stable identity. Its later Crochet
assessment is particularly relevant: reaching technical research goals did not
make the authoring experience satisfactory. Our passing experiments likewise
do not settle comfort.

The categories below are our synthesis, informed by that work and current
framework documentation. They are overlapping mechanisms, not Raph's exact
taxonomy or exclusive buckets.

## Major patterns

| Pattern | What the author says | What the system does | Principal authoring cost |
| --- | --- | --- | --- |
| Retained mutable widgets | Create objects; handle an event; set properties | Keeps widget objects alive and applies explicit mutations | Keeping domain state and multiple controls synchronized; object lifetime |
| Observable properties and bindings | This property follows that expression; optionally write edits back | Observes changes and propagates values through bindings | Direction, ownership, cycles, notification and commit timing |
| Fine-grained reactive computations | This expression reads this reactive value | Reruns dependent expressions; retains unaffected UI | Knowing which reads are tracked and who disposes subscriptions |
| Re-evaluated UI descriptions | Given this state, describe the UI | Reruns selected functions/scopes, then reconciles with retained UI | Repeatable view code, identity and choosing useful update boundaries |
| Model/View/Update messages | This interaction emits a message; update transforms the model | Routes messages and separates state transitions from view descriptions | Message definitions and routing through reusable components |
| Immediate author API | Execute these UI calls against current application values | Interprets repeated calls, retaining whatever interaction state it needs | Stable IDs, execution order and repeated work |

The next table supplies concrete examples and sources for each mechanism.
MVU is a state-transition discipline, while reconciliation is an update mechanism:
they can coexist. Fine-grained observation can also decide *which view bodies*
rerun, as in SwiftUI and Compose, instead of directly patching a text node.
State projection/lenses, context injection and stores cut across these categories.
Enaml's layout constraints solve geometry; they are not its state-binding system.

## Framework comparison

The shared-value exercise is the same throughout: two reusable child editors
edit one parent/model-owned name. These are idiomatic baseline approaches, not
the only options each framework supports. Framework names link to primary
documentation; the following notes cover syntax, identity and effects.

| Framework / mechanism | What updates | Two children edit one value | Comfort and cost |
| --- | --- | --- | --- |
| [Svelte 5](https://svelte.dev/docs/svelte/what-are-runes) — Fine-grained | Dependent template expressions and reactive computations; component setup is not rerun for each edit. | Parent $state; both children use bind:value, with $bindable in the child. | Mutable-looking state and concise binding; rune boundaries, ownership and tracked reads still matter. |
| [Solid](https://docs.solidjs.com/concepts/components/basics) — Fine-grained | Signal readers rerun; the component function normally runs once per mount. | One parent signal; pass reactive reads and its setter to both children, or share a store. | Local, targeted data flow; an ordinary variable read outside tracking does not become reactive. |
| [React](https://react.dev/learn/sharing-state-between-components) — Re-evaluation | Component functions produce new descriptions; reconciliation commits necessary host changes. Memoization can skip work. | Lift state; give both children the value and an onChange callback. | Uniform composition and explicit ownership; render snapshots, hooks, effects and keys require discipline. |
| [Vue 3](https://vuejs.org/guide/extras/reactivity-in-depth) — Hybrid | Reactive dependencies trigger component render effects; compiler hints narrow virtual-DOM patch work. | Parent ref; child defineModel and v-model, expanding to a prop plus update event. | Compact forms and mutable-looking models; ref/proxy rules and render/watch timing remain visible. |
| [Marko 6](https://markojs.com/docs/reference/reactivity) — Fine-grained | Dependent render expressions update; the compiler may group expressions. Updates are batched. | Parent `<let>`; controllable children use value:=name, shorthand for value/change propagation. | State, bindings and lifetime stay close to markup; requires Marko semantics and compiler tooling. |
| [SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/) — Hybrid | Observed property reads invalidate relevant view bodies; recomputed descriptions update retained UI. | One owned model/value; both children receive writable bindings, such as $model.name. | Concise property editing; state storage and identity outlive ephemeral view values. |
| [Flutter](https://docs.flutter.dev/resources/architectural-overview) — Re-evaluation | setState schedules a build for its State; reconciliation can reuse elements and narrow downstream work. | Lift state/model; pass value plus callbacks, or use inherited/listenable mechanisms. | Explicit build/state boundary; callback plumbing and rebuild/key rules add work. |
| [Qt Widgets](https://doc.qt.io/qt-6/signalsandslots.html) — Retained objects | Handlers and notifications explicitly change widget/model properties; optional Qt 6 bindable properties add propagation. | One model property; connect both editors to it and distribute changes through signals/slots. | Concrete objects and direct debugging; synchronization and object lifetime need care. |
| [Qt Quick / QML](https://doc.qt.io/qt-6/qtqml-syntax-propertybinding.html) — Property bindings | Property dependencies reevaluate affected binding expressions. | Both editors read one model property; user-edit handlers write it back. A binding alone is not automatically two-way. | Compact property relationships; imperative assignment can replace a binding. |
| [wxPython](https://www.wxpython.org/pages/overview/) — Retained objects | Bind events and call setters; no general automatic dependency tracking in the basic model. | Both handlers update one model value, then explicitly synchronize controls. | Familiar Python and concrete widgets; synchronization, feedback loops and event wiring are manual. |
| [Enaml](https://enaml.readthedocs.io/en/latest/get_started/syntax.html) — Property bindings | Subscriptions reevaluate dependent expressions; delegation synchronizes properties. | Both fields delegate to one Atom model property: text := model.name. | Very concise editable models; binding operators and dynamic scope are extra language semantics. |
| [Xilem](https://docs.rs/xilem/latest/xilem/) — Re-evaluation | App logic rebuilds descriptions after changes; diffing updates widgets; memoize can skip known unchanged views. | Callbacks receive current app state; both editors can address one field. lens projects parent state for reusable children. | Ordinary data and current-state actions; state projection, type signatures and retained identity still need design. |
| [Jetpack Compose](https://developer.android.com/develop/ui/compose/state) — Hybrid | State reads invalidate composition scopes; recomposition can skip unaffected work. | Hoist state; pass value plus onValueChange, or share an appropriate state holder. | Ordinary-looking functions with local state; compiler/runtime rules, remember and keys govern behavior. |
| [Elm / Iced](https://guide.elm-lang.org/architecture/) — Messages (MVU) | Messages change model state, then views describe the result. MVU specifies data flow, not one rendering granularity. | Both children emit messages targeting the same model field; parent routes child messages. | Explicit, traceable transitions; message types and composition routing add ceremony. |
| [Dear ImGui](https://github.com/ocornut/imgui/wiki/About-the-IMGUI-paradigm) — Immediate API | UI code executes again and submits current values; the toolkit still retains interaction state. | Pass the same application variable to both editors, with distinct widget IDs. | Direct local control flow; ID stability, execution order and repeated work are author concerns. |
| [WPF / MVVM](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/data/) — Property bindings | Property notifications update binding targets; binding mode controls reverse propagation. | Two editable controls bind TwoWay to the same model property. | Reusable binding and command conventions; notification plumbing and update timing can be hidden. |

## Syntax, identity and effects

### Svelte 5

Svelte templates + compiler-controlled runes; runtime reactive dependencies. Mounted blocks/components own state; keyed lists preserve item identity; key blocks can reset it. Events perform actions; $derived computes values; $effect synchronizes external systems with cleanup.

Sources: [Runes](https://svelte.dev/docs/svelte/what-are-runes); [Bindings](https://svelte.dev/docs/svelte/$bindable); [Effects](https://svelte.dev/docs/svelte/$effect); [Keys](https://svelte.dev/docs/svelte/each).

### Solid

JavaScript/JSX tooling + runtime signals and tracking scopes. Reactive owners manage subscriptions and cleanup; list/control-flow primitives determine retained instances. Event callbacks act; createEffect tracks dependencies; onCleanup releases resources.

Sources: [Components](https://docs.solidjs.com/concepts/components/basics); [State](https://docs.solidjs.com/guides/state-management); [Effects](https://docs.solidjs.com/concepts/effects).

### React

JavaScript/JSX + runtime render/commit; optional React Compiler memoization. State belongs to tree position/type/key, not the function invocation. Render stays pure; event handlers perform interaction effects; useEffect handles external synchronization.

Sources: [Sharing state](https://react.dev/learn/sharing-state-between-components); [Identity](https://react.dev/learn/preserving-and-resetting-state); [Compiler](https://react.dev/learn/react-compiler/introduction); [Effects](https://react.dev/learn/synchronizing-with-effects).

### Vue 3

Compiled templates + runtime refs/proxies; standard virtual-DOM rendering path. Persistent component instances; stable list keys preserve child and temporary DOM state. Events perform actions; watch/watchEffect synchronize reactions with explicit timing and cleanup.

Sources: [Reactivity](https://vuejs.org/guide/extras/reactivity-in-depth); [Rendering](https://vuejs.org/guide/extras/rendering-mechanism); [v-model](https://vuejs.org/guide/components/v-model); [Watchers](https://vuejs.org/guide/essentials/watchers).

### Marko 6

Tags API in .marko; compiler discovers the reactive graph. State/lifecycle attach to tags; if remounts, show preserves; keyed loops retain item identity. Event functions act; lifecycle tags manage effects. Render expressions stay pure; derived values can lag until the update queue flushes.

Sources: [Reactivity](https://markojs.com/docs/reference/reactivity); [Tags API](https://markojs.com/docs/explanation/class-vs-tags-api); [Controllable components](https://markojs.com/docs/explanation/controllable-components); [Core tags](https://markojs.com/docs/reference/core-tag).

### SwiftUI

Swift value views, result builders/property wrappers; modern @Observable uses a macro. Structural identity and explicit IDs govern persistent state lifetime. Actions and lifecycle/effect modifiers own imperative work; body describes UI.

Sources: [Observation and binding](https://developer.apple.com/videos/play/wwdc2023/10149/); [Identity](https://developer.apple.com/videos/play/wwdc2021/10022/).

### Flutter

Ordinary Dart widget classes; immutable descriptions and retained Element/render trees. State survives through matching element location, widget type and key. Callbacks/lifecycle methods act; build should be free of side effects.

Sources: [Architecture](https://docs.flutter.dev/resources/architectural-overview); [State](https://api.flutter.dev/flutter/widgets/State-class.html); [Shared state](https://docs.flutter.dev/data-and-backend/state-mgmt/simple).

### Qt Widgets

Persistent C++/binding-language widgets; signals/slots, with C++ meta-object tooling. QObject parent-child ownership and persistent object identity. Event handlers and slots perform mutations and external work.

Sources: [Signals/slots](https://doc.qt.io/qt-6/signalsandslots.html); [Ownership](https://doc.qt.io/qt-6/objecttrees.html); [QProperty](https://doc.qt.io/qt-6/qproperty.html).

### Qt Quick / QML

Declarative QML object tree + JavaScript handlers and optional C++ models. Retained QML objects; id is a lexical reference, not an ownership policy. Bindings describe values; signal handlers perform actions. Do not depend on binding evaluation order.

Sources: [Bindings](https://doc.qt.io/qt-6/qtqml-syntax-propertybinding.html); [Objects](https://doc.qt.io/qt-6/qtqml-syntax-objectattributes.html); [Handlers](https://doc.qt.io/qt-6/qtqml-syntax-signals.html).

### wxPython

Ordinary Python constructing retained native wxWidgets controls. Persistent native windows; parent-child destruction rules matter beyond Python references. Bound event callbacks directly perform actions.

Sources: [Overview](https://www.wxpython.org/pages/overview/); [Events](https://docs.wxpython.org/events_overview.html); [Window lifetime](https://docs.wxpython.org/wx.Window.html).

### Enaml

Python superset in .enaml files; retained declarative objects and observable Atom members. Retained declarative/toolkit instances govern lifetime. Layout constraints are a separate geometry system. = initializes; << subscribes; >> writes back; := delegates; :: runs notification code.

Sources: [Syntax/operators](https://enaml.readthedocs.io/en/latest/get_started/syntax.html); [Runtime](https://enaml.readthedocs.io/en/latest/get_started/anatomy.html); [Layout](https://enaml.readthedocs.io/en/latest/get_started/layout.html).

### Xilem

Ordinary Rust typed view values; diffing against retained Masonry widgets. Retained ViewState/elements and routed identity paths connect ephemeral views to widgets. Actions mutate current state; view-bound tasks offer lifecycle-managed async work. App logic takes mutable state, so purity is not enforced by its signature.

Sources: [Current API](https://docs.rs/xilem/latest/xilem/); [Architecture](https://docs.rs/crate/xilem/latest/source/ARCHITECTURE.md); [Raph's introduction](https://raphlinus.github.io/rust/gui/2022/05/07/ui-architecture.html).

### Jetpack Compose

Kotlin composable functions + compiler plugin and snapshot-state runtime. remember follows composition identity; keyed groups preserve identity when order changes. Composable bodies describe UI; callbacks and lifecycle-aware effect APIs perform external work.

Sources: [State/hoisting](https://developer.android.com/develop/ui/compose/state); [Lifecycle](https://developer.android.com/develop/ui/compose/lifecycle); [Effects](https://developer.android.com/develop/ui/compose/side-effects).

### Elm / Iced

Model → view → message → update. Elm uses immutable models; Iced can mutate Rust state. Model state lifetime is explicit; renderer-specific keys/widget-state rules still apply. Elm returns commands/subscriptions; Iced provides Task/subscriptions. Effects are separate from describing the view.

Sources: [Elm architecture](https://guide.elm-lang.org/architecture/); [Elm effects](https://guide.elm-lang.org/effects/); [Iced API](https://docs.rs/iced/latest/iced/).

### Dear ImGui

Ordinary imperative C++ calls, typically issued each frame; application owns domain values. ID stack associates calls with active/focus and other retained interaction state. An activated control can guard an action branch. Repeated UI code must not repeat unconditional external effects.

Sources: [API paradigm](https://github.com/ocornut/imgui/wiki/About-the-IMGUI-paradigm); [Identity FAQ](https://github.com/ocornut/imgui/blob/master/docs/FAQ.md).

### WPF / MVVM

Retained .NET objects, commonly XAML bindings to observable view models; code bindings also work. Persistent controls plus data-context/model lifetime; templates can create separate view instances. Commands/events perform actions. UpdateSourceTrigger chooses when edits reach the model; TextBox.Text defaults to focus loss.

Sources: [Binding model](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/data/).


## What this changes for Moxi

**We should reopen the ownership and editing contract before implementing the
mounted-child draft.** Confidence: moderate. The evidence is the user's repeated
confusion, the shared draft's extra component protocol, and the number of
established alternatives in this inventory. A complete, understandable Mojo
example of that protocol surviving the same edits would change this assessment.

### The apparent two-way tradeoff is incomplete

Concise authoring does not force whole-application work. Solid and Marko target
dependent computations; bindings can target individual properties. Conversely,
React, Flutter and Xilem rebuilding descriptions does not mean rebuilding all
native objects. SwiftUI and Compose combine observation with re-evaluation.
These are documented mechanisms, not evidence that one will outperform another
for Moxi's workloads. See the framework sources above.

The [Dear ImGui paradigm note](https://github.com/ocornut/imgui/wiki/About-the-IMGUI-paradigm)
explicitly distinguishes the public immediate API from implementation choices.
An immediate surface does not inherently require continuous rendering or forbid
retained state. Our render-twice prototype's costs belong to that implementation;
they are not an impossibility proof for the whole API family.

### Comfort often comes from a standard editing relationship

Here are the relationships beneath the surface syntax. These are conceptual
contracts, not proposed Mojo APIs or interchangeable runtime implementations.

| Contract | What a reusable editor receives | Where it appears | What Moxi would have to make easy |
| --- | --- | --- | --- |
| Controlled value | Current value plus a function requesting a replacement | React, Flutter, Compose; expanded Vue/Marko bindings | Passing and routing a field's edit without custom forwarding for every field |
| Writable binding | A connection with both read and write behavior | SwiftUI; Svelte bind; Enaml delegation; WPF TwoWay | Ownership, lifetime, validation and commit timing behind one comprehensible interface |
| Shared observable model | Access to observed model properties | QML, Enaml, modern SwiftUI; stores in web frameworks | Field observation and mutation without exposing a dependency graph to ordinary users |
| Current-state projection | Event-time access to the relevant part of ordinary app state | Xilem's current-state callbacks and lens adapter | Reusing a child against a submodel, without capturing stale state or hand-routing each action |
| Direct application value | A reference/pointer passed during the UI call | Dear ImGui | Clear sequencing and stable interaction identity without repeatable-render side effects |

This is why another shorter spelling of `ui.child` is unlikely to resolve the
discomfort. The previous shared example requires an `InputScreen` protocol,
associated input/output types and handlers receiving an extra input even when
unused. We made the parent shorter by changing ownership, while leaving the
editor's relationship to a shared value expensive to explain.

Marko is a useful comfort reference precisely because its local state,
controllable inputs and tag lifecycle form one coherent vocabulary. It still
has scheduling rules: current docs distinguish immediate assignment from derived
values refreshed when the update queue flushes. The target should be a small,
teachable set of rules, not a claim of zero rules.
([Controllable components](https://markojs.com/docs/explanation/controllable-components),
[reactivity](https://markojs.com/docs/reference/reactivity).)

### Xilem remains a live option, not just historical inspiration

Current Xilem describes lightweight typed views diffed into retained Masonry
widgets. Callbacks receive current application state; `lens` exposes a field of
that state to a reusable view; `memoize` can avoid known unchanged construction.
This gives us a concrete ordinary-language reference for separating data,
descriptions and persistent widgets. It does not require the application-facing
runtime-owned child-state tree proposed in our latest draft.
([Current API](https://docs.rs/xilem/latest/xilem/),
[architecture](https://docs.rs/crate/xilem/latest/source/ARCHITECTURE.md).)

That does not make lenses automatically comfortable. Raph's earlier writing
records ergonomic difficulty with Druid's lens approach, and Mojo's borrowing,
closures and type facilities are not Rust's. Xilem is a strong comparison
candidate, not proof that copying its surface will solve Moxi.
([Principled reactive UI](https://raphlinus.github.io/rust/druid/2020/09/25/principled-reactive-ui.html).)

### "No new language" leaves several choices

Qt Widgets, wxPython, Flutter and Xilem demonstrate library-oriented surfaces.
Solid's reactive primitives are runtime library constructs, though its usual
JSX authoring uses a transform. SwiftUI relies on language features and macros;
Compose uses a compiler plugin. Svelte runes and Marko tags have compiler-defined
semantics; Enaml and QML explicitly add declarative languages.

It is reasonable to keep ordinary Mojo as a constraint. It does not follow that
all state must be plain unobserved fields, or that any library binding is an
unacceptable extra language. However, renaming the binding wrapper we already
tried would not answer the user's objection. Any mechanism must earn its place
in the complete application, including initialization, sharing, removal and
side effects. This survey does not establish which mechanisms Mojo can support
comfortably today.

## Decision and bounded next evidence

Keep the existing event/update versus view-description separation as the
working baseline. The child-routing experiment supports settling changes before
refreshing controlled editors: it observed cursor loss with eager refresh and
fixed that case with deferred settlement. This is narrow evidence, not a proof
of every scheduler or lifecycle case.
([Child routing experiment](child-routing-experiment.md).)

Before another runtime experiment, compare **three complete ownership models**
using the same existing form: current-state projection (Xilem), a shared observed
model/property (Solid/QML/SwiftUI), and controlled values plus callbacks as the
baseline. Marko remains the reference for reading comfort. Do not introduce
three new public Moxi APIs; show the necessary application code and explicitly
mark any unsupported Mojo feature.

Use the previous edits—add a field, add a third instance, share only name—and
also predict Save immediately after a sibling edit and remove/reorder/remount
a child. Count concepts, ownership changes and required edits, not just lines.
The user should be able to explain the complete example before we invest in its
runtime. Only an acceptable candidate needs a focused compilation/lifetime test;
performance measurements become useful once we have a concrete implementation.

High confidence in the documented broad mechanisms and in the need to separate
authoring, ownership, propagation and identity. Moderate confidence in the
recommendation to prioritize the editing contract. Low confidence in any claim
that one candidate will achieve universal ease in Mojo. Actual source-reading
and editing evidence could change the comfort judgment; compiled ownership and
runtime tests could change the feasibility judgment.

## Evidence and limits

The implementation reference remains `feat/data-workbench` at
`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`, with its existing uncommitted
experiments. Inspection of `src/moxi/component.mojo` and the current API docs
shows a build/update contract, retained component slots, and localized subtree
facilities. Moxi is not accurately described as necessarily rebuilding the
whole application for every edit. This inventory does not change product code
or reconcile unrelated implementation work.

Current documentation was researched on October 27, 2026. Xilem 0.4.0 and Iced
0.14.0 were the docs.rs versions observed. The web rows distinguish Svelte 5,
Vue 3's documented virtual-DOM path, Marko 6 Tags API, and React's optional
compiler; SwiftUI covers modern Observation rather than only ObservableObject.
Raph's historical essays supply architectural axes, not current feature audits.

Primary sources were checked, with focused delegated web/native research and
parent verification of consequential Marko, Vue, SwiftUI, Enaml, Qt, Xilem and
immediate-mode distinctions. No cross-framework examples were compiled or run;
no performance, memory, accessibility, platform-support or usability ranking was
tested. The comparison is intentionally about authoring/state/update patterns,
not a framework-selection scorecard. Source links can evolve after this snapshot.

The companion [interactive table](ui-pattern-inventory.html) contains the same
framework inventory, with filters and expandable syntax, lifetime, effect and
source notes. The Markdown document is the durable assessment.

## Follow-up: complete form comparison

The [three-form ownership comparison](form-ownership-comparison.md) carries out
the source exercise above. It provisionally prefers shared observed properties
for shared fields while retaining current-state callbacks for local state.
Concrete Mojo field projection and shared storage passed narrow probes; full
UI integration and authoring comfort remain unverified. This does not adopt a
new public API or authorize a general runtime rewrite.
