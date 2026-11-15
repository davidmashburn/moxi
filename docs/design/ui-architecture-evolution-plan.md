# UI Architecture Evolution Plan: Ingredients, Tradeoffs, and Trajectory

**Status:** Proposed architectural plan for Moxi post-0.5 authoring and runtime evolution.
**References:**
- `docs/authoring/ui-ingredients.md` (Taxonomy of GUI library ingredients)
- `docs/authoring/comparisons.md` (Authoring and update mechanics: Moxi in context)
- `docs/design/ui-pattern-inventory.md` (October 2026 pattern inventory)
- `docs/design/simple-composition.md` & `experiments/paint-costs/` (Performance baselines)
- Raph Levien: *Towards a unified theory of reactive UI* (2022) & *Thoughts on reactive UI in Rust* (2019)

---

## 1. Executive Summary & Context

Moxi has established a working, bounded UI architecture tailored to Mojo’s value semantics:
1. **Model:** Ordinary Mojo structs (`Screen`) with value-owned fields and `mut self` methods.
2. **Authoring:** Pure declarative `render(self, mut ui: UI[Self])` without JSX, macros, or hidden subscriptions.
3. **Reconciliation:** Ephemeral `ViewNode` declarations diffed into a retained control tree (`ColumnRuntime`) by `(kind, id, key)`.
4. **Identity & Lifetimes:** Explicit `Keyed[T]` collections and a strict distinction between in-place *replacement* (preserving logical identity, focus, and IME) versus *reset* (clearing retained state and canceling pending requests).
5. **Event Routing:** Method tokens (`Self.increment`) and scoped routes (`Action[Child, Context]`), completely avoiding closure-captured pointers.
6. **Agent Integration:** An in-process `CapabilityBus` providing schema-checked permissions, execution leases, and replayable audits.

While this foundation ensures memory safety, deterministic execution, and headless testability, two primary authoring tensions remain open:
- **Authoring ceremony:** Prop drilling and manual route definitions (`field["..."]`, `ui.child(...)`) add friction when sharing documents across nested views.
- **Update granularity:** Updates rebuild the declaration list following an event or synchronous command; plain field assignment has no automatic dependency tracking.

This plan outlines a principled path forward to evolve Moxi’s authoring and update machinery without compromising Mojo’s zero-cost value semantics or introducing heavy runtime reactivity graphs.

---

## 2. Strategic Positions Across the UI Ingredients

| Dimension | Common Approaches | Moxi Current Stance | Proposed Evolutionary Trajectory |
|---|---|---|---|
| **State Ownership** | OOP widgets, Redux store, ECS, plain value types | Plain value structs (`Screen`) | **Retain value structs**. Reject OOP widget state and flat ECS tables (which distort tree hierarchies). |
| **Authoring Paradigm** | Immediate mode (IMGUI), JSX, Templates, Pure render functions | Pure `render(mut ui)` | **Retain pure `render`**. Preserve side-effect-free view declarations; investigate typed ambient context. |
| **Reactivity & Invalidation** | Runtime Signals, compiler dependency graphs, coarse invalidation | Coarse rebuild on event dispatch/command | **Compile-time memoization & subtree lenses**. Avoid runtime signal graphs; use static dependency boundaries. |
| **Runtime Graph** | No VDOM (direct node updates), heavy OOP widgets, lightweight VDOM | Ephemeral view nodes diffed to retained controls | **Retain `ColumnRuntime` diffing**. Maintain separation between view declarations and layout/OS handles. |
| **Identity & Local State** | Hooks (call order), property wrappers, explicit keys/paths | Explicit `Keyed[T]` + Scope resets | **Retain explicit keys and lifetime boundaries**. Keep identity explicit; reject lexical-order hooks. |
| **Event Routing** | Closures capturing mutable pointers, Signals/Slots, Action queues | Method tokens (`Self.func`) & scoped routes | **Retain method tokens**. Avoid closure pointer capture; explore ergonomic route sugar. |

---

## 3. Detailed Investigation Tracks

### Track 1: Ambient Typed Context (Ergonomics Gate)
* **Problem:** In complex nested compositions (e.g. `shared.mojo`, `workspace.mojo`), passing shared state (such as a shared `Document` or active theme) requires manual route plumbing (`route_left`, `Action[Draft, Document]`) through each intermediate container.
* **Proposed Design:**
  - Introduce an ambient **`Environment` / `Context` stack** attached to the `UI` builder during `render`.
  - Parents provide context via typed registration: `ui.provide(self.document)`.
  - Children access context by type: `var doc = ui.consume[Document]()`.
  - Mutations route through parent-declared handlers, ensuring the parent retains authoritative ownership.
* **Acceptance Signal:**
  - Eliminate at least 40% of routing boilerplate in `examples/authoring/workspace.mojo`.
  - Zero dynamic heap allocation for context access (backed by a static or inline frame stack).
  - Deterministic rejection if a child requests an unprovided context type.

---

### Track 2: Subtree Invalidation & Compile-Time Memoization (Performance Gate)
* **Problem:** In large workspaces (e.g., 100+ editors), re-evaluating declarations for the entire screen on every keystroke incurs unnecessary view construction, even though paint scans are already optimized (`3.935 ms` cached in production).
* **Why NOT Runtime Signals?**
  - Signals require heap-allocated subscriber lists, dynamic closures, and complex graph cleanup to prevent memory leaks.
  - In a systems language like Mojo, dynamic signal graphs fight value ownership and incur substantial cache-miss penalties.
* **Proposed Design:**
  - **Compile-Time Lensing & Subtree Invalidation (`memoize` / `lens`):**
    - Support wrapping child component invocations in explicit memoization boundaries:
      `ui.memo[Editor](editor_key, self.editors[i], ...)`
    - If `self.editors[i]` has not mutated (tested by value equality or explicit revision/generation counter), the runtime skips calling `render()` on that subtree and reuses the cached `ViewNode` declarations.
* **Acceptance Signal:**
  - Re-run the 100-editor and 300-editor frame probe from `experiments/paint-costs/`.
  - Reduce declaration generation time for localized child edits to $< 1.0\text{ ms}$ at 100 editors and $< 5.0\text{ ms}$ at 300 editors.
  - Zero heap allocation overhead when subtrees are skipped.

---

### Track 3: SIMD-Accelerated Layout & Constraint Solving (Scalability Gate)
* **Problem:** Flex, grid, and portal layout computations currently traverse retained control structures sequentially.
* **Proposed Design:**
  - Reorganize `ColumnRuntime` measurement arrays into Structure-of-Arrays (SoA) layout.
  - Vectorize min/max constraint clamping, flex distribution, and coordinate translation passes using Mojo’s `@vectorize` and `SIMD` primitives.
* **Acceptance Signal:**
  - Demonstrate linear scaling and sub-millisecond layout passes across 10,000 synthetic layout nodes in headless benchmarks.

---

### Track 4: CapabilityBus & Agent Boundary Hardening (Safety Gate)
* **Problem:** As Moxi integrates deeper agentic workflows, side-effects triggered by external inputs or LLM agents must not bypass the UI ownership contract.
* **Proposed Design:**
  - Formally bind `CapabilityBus` leases to UI lifetime scopes.
  - If a window or workspace session is reset (`reset(app, ...)`), any active capability leases and queued agent actions are revoked immediately.
* **Acceptance Signal:**
  - Headless test verifying that an in-flight agent action dispatched after a root reset is deterministically dropped with an audit log entry.

---

## 4. Explicit Non-Goals

To maintain focus and avoid architectural churn, the following are explicit non-goals for this plan:
1. **No JavaScript-Style Runtime Signals:** No reactive proxy wrappers, runtime subscriber arrays, or observable primitives that undermine Mojo value semantics.
2. **No Proprietary Authoring DSL / Compiler Fork:** Moxi authoring must remain 100% valid, idiomatic Mojo code compilable by the standard `mojo` compiler.
3. **No Immediate-Mode Paradigm Shift:** We will not abandon the retained control tree or declarative `render`. Pure immediate mode would destroy accessibility (macOS AX), native text shaping (CoreText), and IME contracts.
4. **No Flat ECS Architecture:** Hierarchical UI layout and event bubbling will remain modeled as trees, not relational entity tables.

---

## 5. Phased Implementation Sequence

```
Phase 1: Ambient Context Prototype
  ├── Implement prototype Environment stack in moxi.authoring
  ├── Validate against shared-document and workspace examples
  └── Verify zero-allocation and type-safety boundaries

Phase 2: Subtree Memoization Probe
  ├── Add ui.memo() / lens wrapper to component rendering
  ├── Validate identity preservation during partial rebuilds
  └── Measure 100/300 editor benchmarks against baseline

Phase 3: SIMD Layout Optimization
  ├── Benchmark existing layout solver bottlenecks
  ├── Vectorize flex/grid constraint math
  └── Validate pixel-identical layout output

Phase 4: Acceptance & Documentation
  ├── Human authoring comfort review
  ├── Update docs/authoring/ and examples
  └── Formal release gate sign-off
```
