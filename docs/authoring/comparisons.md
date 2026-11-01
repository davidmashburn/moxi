# Authoring and update mechanics: Moxi in context

> Status: `moxi.authoring` implements the selected, bounded authoring API.
> This comparison explains mechanisms; it is not a performance ranking.

Moxi separates the authoring surface from the update machinery. Authors keep
ordinary value-owned fields and methods. A pure render describes controls from
current state; handlers mutate the current owner. Dynamic children use explicit
keys, and child actions are routed through the current parent/child owner with a
delivery scope. The runtime retains control identity and editing state by
explicit paths, then rebuilds the declaration list after an event or synchronous
model update. An assignment alone does not create field-level dependency edges:
the current API has no automatic field tracking. Selective-update probes
are separate experiments beneath this surface.

## The Moxi contract

The practical rule is “same owner unless reset is explicit.” Replacing a root
value within its owner preserves the logical lifetime: existing actions resolve
against current values, and unchanged text preserves selection/IME state. A
collection reset remains in the same owner but allocates fresh child keys. By
contrast, `reset(app, root, window, renderer)` creates a new root lifetime: it
installs a fresh delivery scope, clears retained controls, resets application scroll capture, and
rejects queued or captured work from the previous scope. This is a correctness
boundary, not shorthand for ordinary assignment.

That contract is why keys and scopes are author-visible concepts even though the
runtime owns the bookkeeping. A keyed collection looks up current membership
when routing an action; removed children do not remain reachable through normal
UI delivery. Native ingress and request cancellation share the supported
`reset` boundary; `App` remains the request-delivery owner. The strategy combines
ordinary methods with explicit identity; how comfortable that feels needs human application-author feedback.

## Xilem/Raph, React context, and Redux

Raph Levien’s [reactive-UI account](https://raphlinus.github.io/ui/druid/2019/11/22/reactive-ui.html)
frames UI as tree transformations and discusses React’s `useState` and
Redux-style reducers. His later [Xilem architecture](https://raphlinus.github.io/rust/gui/2022/05/07/ui-architecture.html)
generates a short-lived view tree, diffs it into a retained widget tree, routes
events by an ID path with mutable app state, and uses Adapt/lensing for
composition. Xilem’s current [lens](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.lens.html)
and [memoize](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.memoize.html)
APIs make those composition and update choices explicit.

Moxi borrows the useful shape—declarative descriptions, current-state event
routing, and explicit identity—not Xilem’s implementation or any performance
claim. The distinction also clarifies two nearby React patterns. [React
context](https://react.dev/learn/passing-data-deeply-with-context) solves scoped
data access without prop drilling; a [state update triggers render and
commit](https://react.dev/learn/render-and-commit). [Redux](https://redux.js.org/api/store)
uses a store for the whole state tree and changes it through dispatched actions
and a reducer. Moxi’s typed owner parameters and scoped actions are neither a
Redux store nor automatic dependency tracking. Context-like access could be
added independently of either choice.

## Broader patterns

| Framework | Authoring surface | Update mechanics | Practical Moxi comparison |
|---|---|---|---|
| [Svelte](https://svelte.dev/docs/svelte/$state) | Components with `$state`/`$derived`; assignments stay concise | Compiler/runtime state machinery tracks reads and writes; deep state can trigger granular updates | A comfort target, but its machinery is not present in ordinary Mojo fields |
| [Solid](https://docs.solidjs.com/advanced-concepts/fine-grained-reactivity) | JSX plus signals/stores; [context](https://docs.solidjs.com/concepts/context) is separate | Runtime observers target computations that read changed signals | A reference for selective work and scoped access, not for changing Moxi ownership |
| [React](https://react.dev/learn/render-and-commit) | Components and hooks; context handles deep access | State updates queue component rendering; reconciliation/commit applies necessary output changes | Pure render is analogous; plain field assignment is not a React state update |
| [Vue](https://vuejs.org/guide/essentials/reactivity-fundamentals) | Templates plus refs/reactive objects | Reactive proxies/refs track access and trigger effects/rendering | Field tracking is framework machinery, not a property of assignment syntax |
| [Marko](https://markojs.com/docs/reference/reactivity) | Tags API with `<let>` and ordinary-looking assignments | The compiler discovers dependencies, emits update functions, and batches work | Strong comfort and selective-update reference; Moxi has no compiler dependency graph |
| [SwiftUI](https://developer.apple.com/documentation/swiftui/state) | Value `View`s with `@State` and `Binding` | State changes update view parts that depend on the value | Similar ownership/binding questions, without a Moxi property-wrapper system |
| [Flutter](https://docs.flutter.dev/data-and-backend/state-mgmt/declarative) | Dart widgets and explicit `State`/`build` methods | `setState` marks a state object dirty and reruns `build`; descriptions are diffed | Similar pure-description model, with explicit invalidation rather than Moxi field tracking |
| [Qt Widgets](https://doc.qt.io/qt-6/signalsandslots.html) | Retained `QObject`/widgets, methods, signals, and slots | Signals notify connected slots immediately or through queued delivery | An imperative, notification-driven alternative to Moxi’s declaration rebuild |
| [Qt Quick/QML](https://doc.qt.io/qt-6/qtqml-syntax-propertybinding.html) | Declarative objects and property-binding expressions | Changes to observed dependencies reevaluate bindings | Qt also offers reactive declarations, with an additional language and binding machinery |
| [wxPython](https://docs.wxpython.org/wx.Window.html) | Retained native windows and Python event handlers | Events propagate through handlers; setters, layout, and refresh APIs mutate/repaint controls | A retained imperative baseline; identity lives in widget objects rather than render paths |
| [Enaml](https://enaml.readthedocs.io/en/latest/get_started/introduction.html) | Declarative Python DSL with model/view bindings | Runtime dependency tracking updates the UI and can propagate edits back to models | Demonstrates the convenience—and machinery—Moxi is not claiming today |
| [Xilem](https://docs.rs/xilem/latest/xilem/) | Typed view functions with explicit `lens`/`memoize` adapters | Lightweight views rebuild retained elements; adapters can narrow state and skip view work | Closest Rust lineage; neither ordinary field syntax nor keys imply automatic read tracking |

The useful adoption rule is consequently narrow: keep state in ordinary fields,
put domain changes behind methods, make render side-effect-free with respect to
model state, key dynamic children, and treat replacement versus reset as
different lifetime operations. If selective invalidation is added later, keep
this authoring surface and measure setup, dispatch, teardown, retained-state
bounds, and update work together. Moxi has separate operation-count and timing
experiments, but no benchmark of the combined lifetime/native/request machinery
or a controlled cross-framework performance ranking. Framework behavior depends on
version and formulation, and Xilem’s own API documentation says its memoization
story may change.
