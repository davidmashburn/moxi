# UI Library Ingredients, Paradigms, and Architecture: Moxi in Context

This document breaks down the fundamental "ingredients" of graphical user interface (GUI) libraries into a clear taxonomy. It provides architectural context for the decisions made in Moxi, drawing on the analysis in [comparisons.md](comparisons.md), Raph Levien’s foundational essays on reactive UI architecture, and modern GUI systems across native and web ecosystems.

---

## 1. The Central Problem of GUI Architecture

At its core, every UI library is an answer to a single fundamental challenge:
> **How do you synchronize dynamic, domain-specific application state with a visual, interactive output across time, while maintaining high performance, stable interactive identity (focus, cursor, selection, IME), and robust event delivery?**

In native systems languages like Mojo, C++, and Rust, this problem is compounded by ownership, lifetimes, memory layout, and the avoidance of dangling pointers or cyclic reference graphs.

---

## 2. The Taxonomy of UI Ingredients

Every UI architecture can be broken into **six orthogonal layers**:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. State Ownership & Data Flow (Where state lives & who owns it)       │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Authoring Paradigm (How the programmer describes the UI)           │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Change Detection & Invalidation (How the runtime knows what changed)│
├────────────────────────────────────────────────────────────────────────┤
│ 4. Reconciliation & Runtime Graph (Virtual vs. Retained representation)│
├────────────────────────────────────────────────────────────────────────┤
│ 5. Identity & Ephemeral State (Preserving focus, scroll, selection)   │
├────────────────────────────────────────────────────────────────────────┤
│ 6. Event Routing & Async Boundaries (How actions flow back safely)     │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Layer 1: State Ownership & Modeling
*Where does application truth live, and who is responsible for its memory?*

* **Plain Value Types (Algebraic Data Types / Value Semantics)**:
  * Application state is stored in plain, idiomatic language structs/types with natural field ownership.
  * No base classes, framework introspection proxies, or hidden subscribers.
  * *Examples*: Moxi (`struct Screen`), Xilem, SwiftUI (`struct View` state models).
* **Retained Object Graphs (Classic OOP Model)**:
  * State is distributed across long-lived widget objects on the heap. Application logic queries and updates widgets directly (`textBox.getText()`, `progressBar.setValue()`).
  * *Tradeoffs*: Leads to synchronization drift (state duplicated between widgets and domain models), tight coupling, and cyclic ownership graphs (`parent <-> child`).
  * *Examples*: Qt Widgets (`QObject`), wxWidgets, Win32, classic DOM.
* **Centralized Single-Store / Unidirectional Data Flow**:
  * State lives in a single normalized tree. Changes occur exclusively by dispatching action objects through pure reducer functions (`(state, action) -> new_state`).
  * *Tradeoffs*: Highly predictable, serializable, and debuggable; but induces high verbosity and prop drilling unless accompanied by scoped selectors.
  * *Examples*: Redux, The Elm Architecture (TEA).
* **Entity Component System (ECS)**:
  * State is decomposed into flat tables of data components indexed by sparse integer entity IDs, transformed sequentially by systems.
  * *Tradeoffs*: Excellent for cache locality in games with flat or spatial queries, but historically ill-suited for GUI. GUI is inherently a nested tree hierarchy with cascading parent-child layout constraints, focus rings, clipping boundaries, and event bubbling. Emulating hierarchical trees over flat ECS tables introduces significant relational indexing overhead.
  * *Examples*: Bevy UI, Flecs GUI experiments.
* **Lenses & Scopes (Functional State Slicing)**:
  * A lens provides bidirectional access to a sub-field of a parent model (`get: State -> SubState`, `set: (State, SubState) -> State`).
  * Enables composing modular child components that operate on local data while seamlessly mutating the parent owner without storing pointers or closures.
  * *Examples*: Xilem `lens`, functional GUI architectures.

---

### Layer 2: Authoring Paradigm
*How does the developer declare the user interface?*

* **Pure Immediate Mode (IMGUI)**:
  * The interface description and event processing run directly within the application's render loop every frame:
    ```c
    if (Button("Click Me")) {
        count++;
    }
    ```
  * *Pros*: Zero synchronization bugs; no retained widget tree; trivial dynamic UI.
  * *Cons*: Layout negotiation is complex (often requiring 2+ frame delays or multi-pass layout hacks); continuous CPU/GPU load; highly problematic for native accessibility (screen readers need a persistent semantic tree) and complex text/IME input.
  * *Examples*: Dear ImGui, egui.
* **Pure Declarative Render Functions**:
  * An ephemeral view function runs against current state to return a lightweight description of the interface:
    `render(state) -> ViewDeclaration`.
  * *Pros*: Side-effect free; deterministic; declarative clarity.
  * *Cons*: Requires an underlying reconciliation mechanism to avoid recreating native platform controls on every frame.
  * *Examples*: React, Flutter `build()`, SwiftUI `body`, Xilem typed views, Moxi `render(self, mut ui)`.
* **Template & DSL-Driven Declarations**:
  * A specialized compiler processes templates or tags into optimized update functions.
  * *Examples*: Marko 6 tags, Svelte templates, Qt QML, Enaml.
* **Imperative Construction**:
  * Manual procedural assembly of controls:
    ```cpp
    auto btn = new QPushButton("Click");
    layout->addWidget(btn);
    connect(btn, &QPushButton::clicked, this, &App::onClicked);
    ```

---

### Layer 3: Change Detection & Reactivity
*When state changes, how does the system know what to recompute?*

```
Coarse Invalidation           Fine-Grained Signals                Compiler Dependency Graph
 (React / Flutter)            (SolidJS / Vue / Qt)                   (Marko 6 / Svelte)
┌──────────────────┐           ┌──────────────────────┐           ┌──────────────────────┐
│  State mutated   │           │  Signal value set    │           │ Assignment analyzed  │
│        ▼         │           │          ▼           │           │ at compile time      │
│ Invalidate whole │           │ Notify registered    │           │          ▼           │
│ component/tree   │           │ subscriber closures  │           │ Pinpoint update runs │
└──────────────────┘           └──────────────────────┘           └──────────────────────┘
```

* **Coarse Invalidation / Subtree Invalidation**:
  * Mutating a model triggers an invalidation flag on a component boundary. On the next tick, the component's `render()` method runs completely.
  * *Examples*: React (`setState`), Flutter (`setState`), Moxi's authoring contract (rebuilds declarations on event dispatch or synchronous command).
* **Signals & Observers (Fine-Grained Reactivity)**:
  * Values are wrapped in observable containers (`Signal[T]`). When an expression or component reads the signal, it registers as a subscriber in a runtime reactive graph. Writing to the signal immediately notifies only its direct subscribers.
  * *Pros*: O(1) pinpoint updates without re-evaluating whole component functions or diffing trees.
  * *Cons*: Runtime memory overhead for the subscription dependency graph; dynamic allocations for closure callbacks; potential subscription leaks.
  * *Examples*: SolidJS, Vue 3 `ref`, Svelte 5 runes, Qt Signals & Slots.
* **Compiler-Driven Dependency Tracking**:
  * The language compiler analyzes field assignments and builds a static dependency graph at build time. It generates specific patch functions without requiring runtime signal subscriptions.
  * *Examples*: Marko 6, Svelte 3/4.
* **Incremental Computation Systems**:
  * Computation nodes are cached and memoized using dependency graphs that execute minimal re-evaluations upon input mutations.
  * *Examples*: Adapton, Salsa (Rust-analyzer), Differential Dataflow.

---

### Layer 4: Reconciliation & Runtime Representation
*How do ephemeral declarations interface with the OS, layout engines, and GPU?*

* **Pure Retained Widget Tree**:
  * Widgets are long-lived entities that maintain geometry, layout caches, dirty rects, and platform handles.
  * *Examples*: Masonry (in the Linebender/Xilem stack), Qt `QWidget`, DOM elements.
* **Virtual DOM / Ephemeral Tree Diffing**:
  * Each render generates a transient tree of descriptors.
  * A reconciler compares the new descriptor tree with the previous descriptor tree (or directly updates the retained widget tree) by matching identities: `(kind, id, key)`.
  * It emits granular mutation commands (create, reuse, update, move, destroy) into the retained engine.
  * *Examples*: React reconciler, Flutter Element/RenderObject tree, Xilem diffing into Masonry, Moxi `ColumnRuntime`.
* **Compiled Direct Mutations (No VDOM)**:
  * The declarative template compiles directly into native DOM/widget mutations triggered by signals. No virtual tree is ever created or diffed at runtime.
  * *Examples*: SolidJS, Svelte.

---

### Layer 5: Identity, Lifetimes, & Ephemeral State
*How does transient interactive state (text cursor, IME composition, scroll position, focus) survive when views re-render?*

* **Hooks (`useState`, `useEffect`)**:
  * Local state is stored in an array owned by the underlying runtime node, indexed implicitly by the **lexical call order** during render.
  * *Fragility*: Rules of Hooks (cannot be called inside conditionals or loops).
* **Explicit Keys & ID Paths**:
  * Elements in collections or dynamic trees carry explicit developer-provided or generation-indexed keys.
  * In Xilem and Moxi, state identity is tracked via structural ID paths or explicit collection keys (`Keyed[T]`).
* **Property Wrappers & Bindings**:
  * Language attributes (`@State`, `@Binding` in SwiftUI) distinguish view-local storage from external model projections.
* **Lifecycle & Reset Boundaries**:
  * A critical distinction formulated in Moxi: **Replacement vs. Reset**.
    * *Replacement (in-place update)*: Preserves logical identity; selection, IME, and existing action routes continue to point to the current owner.
    * *Reset (new lifetime)*: Clears retained controls, resets scroll capture, flushes IME and user input buffers, and rejects any queued asynchronous tasks from the prior lifetime.

---

### Layer 6: Event Routing & Asynchronous Boundaries
*How do user inputs and async operations mutate state without creating memory hazards?*

* **Direct Callbacks & Captured Closures**:
  * Widgets store callback closures: `button.on_click = || state.count += 1`.
  * *The Systems Hazard*: In Rust and Mojo, capturing mutable pointers in retained widgets introduces aliasing violations, cyclic ownership, or lifetime compilation errors.
* **Decoupled Method References / Action Queues**:
  * Views emit declarative action tokens or method pointers (`Self.increment`), never raw closures capturing model instances.
  * The runtime routes the action to the current live instance of the model during dispatch.
  * *Examples*: Elm messages, Xilem message routing, Moxi's `ActionQueue` and `moxi.authoring.UI` method references.
* **Generational Task Lifetimes**:
  * Background tasks and external requests are tagged with generation IDs tied to an explicit lifecycle scope. If a scope is destroyed before the task completes, late arriving results are discarded automatically, preventing race conditions or stale writes.

---

# 3. What Does Moxi Choose?

Moxi's authoring and runtime architecture (documented in [comparisons.md](comparisons.md) and [xilem-comparison.md](../xilem-comparison.md)) makes specific, deliberate choices:

| Ingredient | Moxi's Choice | Rationale & Tradeoffs |
|---|---|---|
| **State Ownership** | **Plain Mojo Value Structs (`Screen`)** | Avoids heap-allocated framework objects. State belongs to the author with idiomatic Mojo `mut self` methods. |
| **Authoring Surface** | **Pure `render(self, mut ui: UI[Self])`** | Declarative, pure descriptions. No JSX, no custom DSL, no runtime compiler dependencies. |
| **Reactivity / Invalidation** | **Event-Driven & Command Rebuilds (No Auto Tracking)** | Plain assignments do not notify. Rebuilds are triggered by dispatched events or synchronous `update_model` commands. Avoids runtime signal overhead. |
| **Reconciliation** | **`ColumnRuntime` Retained Control Tree** | Flat, parent-aware `ViewNode` declarations diffed into retained controls using `(kind, id, key)`. Retains layout caches and native platform handles. |
| **Identity & Lifetimes** | **`Keyed[T]` + Explicit Lifetime Contract** | Dynamic items use stable keys. Replacement updates current owner; explicit `reset()` retires retained controls, native IME, and queued tasks. |
| **Event Routing** | **Typed Method References (`Self.method`) & Scopes** | No closures capturing pointers. The runtime resolves the method on the current owner at dispatch time. |
| **Async & Agent Boundary**| **Deterministic Tasks + `CapabilityBus`** | Generation-tagged request lifecycles with explicit cancellation; in-process capability bus for authorized agent interactions. |

---

# 4. Architectural Analysis: What is Optimal for Mojo?

### 1. Why Moxi's Foundation is Solid
* **Value Semantics Match Mojo**: In Mojo, value types with `inout`, `borrowed`, and `owned` semantics are first-class. Forcing an OOP widget graph with reference counting (`Arc<RefCell<...>>`) would undermine Mojo’s memory efficiency.
* **Elimination of Captured Closures**: Routing actions through method tokens (`Self.increment`) completely avoids the closure-lifetime hazards that plague Rust and C++ GUI libraries.
* **Retained Layout with Virtual Declarations**: Pure immediate mode cannot support high-quality typography (CoreText/HarfBuzz shaping), complex multi-pass layout constraints, or platform accessibility (macOS AX / AccessKit). A retained engine driven by ephemeral declarations provides the right separation of concerns.

### 2. The Path Forward: Where Moxi Can Evolve
* **Compile-Time Lensing over Runtime Signals**:
  Adding a JavaScript-style Signal runtime to Mojo would introduce significant allocation and bookkeeping overhead. The optimal evolution is **compile-time dependency analysis and memoization** (leveraging Mojo’s metaprogramming and struct reflection) to narrow updates to dirty subtrees.
* **Typed Context / Environment Propagation**:
  Prop-drilling shared state through explicit routes can create authoring ceremony. An ambient, typed context stack (similar to SwiftUI's `@Environment`) allows child views to read shared documents or theme data cleanly without manual parameter passing across intermediate layout containers.
* **SIMD-Accelerated Layout Solver**:
  Because Moxi's retained controls store flat, cache-friendly data structures, layout resolution (flexbox/grid constraints) can be vectorized using Mojo's native SIMD primitives, delivering sub-millisecond layout passes even across large document trees.
