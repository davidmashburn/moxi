# Ordinary Mojo handlers and scoped identity

Status: bounded experiment completed October 27, 2026. No public API adoption.

Implementation baseline: `feat/data-workbench` at
[`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
The preceding `experiments/render-api/` is uncommitted implementation work, not
part of that commit. This follow-up belongs in `experiments/handler-api/` and
must leave production code and other experiments intact.

## Assessment and architectural decision under test

The [render experiment](render-api-experiment.md) demonstrated narrow behavior,
but did not justify adopting its API. Shorter examples introduced execution rules
that readers cannot readily see: one render dispatches an event, and another
repairs declarations evaluated before the action changed state. The user's
tentative approval of the syntax was not evidence of usability.

Stable identity is required; root-global strings on every control are a choice.
An effect boundary is required; mixing handlers into repeatable render bodies is
a choice. Two render passes are a consequence of that event model, not a Mojo or
retained-rendering requirement. Even within one dispatch pass, an earlier derived
local is not recomputed before a later handler uses it.

Xilem retains lightweight view descriptions for event routing and diffing. An
event invokes a callback with mutable application state; the application then
produces another view. The callback need not retain a mutable state reference.
Its identity paths are scoped to views, not global application strings. Moxi's
existing `Component.build/update` and explicit request policy preserve a similar
separation. The render experiment retained the backend but changed the author's
execution model. This comparison does not imply that Rust statically enforces
pure view construction, or that Moxi should copy Xilem's entire abstraction stack.

Sources inspected October 27, 2026:

- [Xilem overview and counter](https://docs.rs/xilem/latest/xilem/).
- [Button callback signature](https://docs.rs/xilem/latest/xilem/view/fn.button.html).
- [View lifecycle and messages](https://docs.rs/xilem_core/latest/xilem_core/trait.View.html).
- [Scoped ViewId paths](https://docs.rs/xilem_core/latest/xilem_core/struct.ViewId.html).
- Implementation `docs/API.md`, effect policy; `src/moxi/component.mojo`;
  `experiments/render-api/runtime.mojo`. The working API document has unrelated
  pre-existing edits; those edits are outside this experiment.

Recommendation: preserve separate view construction and event handling, ordinary
Mojo, and ordinary state ownership. Run one bounded feasibility and authoring
comparison before deciding whether to pursue handlers or simplify explicit actions.
Do not start another broad framework survey or silently adopt a new public API.

## Contract and acceptance gates

- Store ordinary Mojo handlers and pass mutable state at dispatch time. View
  construction must not dispatch events. No retained borrowed application fields,
  parser, code generation, dependency, unsafe type erasure, or production change.
- Repeat the counter/form scenarios: independent/shared state, text changes,
  conditional fields, validation, Save, reset, and exactly one handler invocation.
  Rebuild/resize/paint must not replay actions.
- Exercise reuse and nested state. Show any forwarding callbacks or projection
  machinery explicitly instead of hiding its cost in a demo-specific runtime.
- Exercise reorder, insertion, removal, stale events, editor focus/cursor, and
  independent instances. Scope identity locally; document which structural changes
  still require explicit keys. Positional identity is not safe for arbitrary lists.
- Compile a representative invalid handler and inspect diagnostic usefulness.
  Compare actual source with the render experiment and existing explicit events.
- Record failures, source limitations, and skipped checks. Behavior passing is
  evidence of feasibility, not proof of comfort or readiness for adoption.

Initial confidence: high that the render experiment has not justified replacing
Moxi's architecture; moderate that ordinary handlers can improve authoring. A
compiled, readable composed example with useful diagnostics and predictable
identity would strengthen the second conclusion; elaborate forwarding or callback
storage would weaken it.

## Results

The experiment is uncommitted in implementation `experiments/handler-api/`.
`runtime.mojo` stores thin methods in `UI[State]`, passes mutable state only at
event dispatch, and runs read-only `render(self, mut ui: UI[Self])` once afterward.
The adapter caches the completed view for today's immutable `Component.build`.
It stores no borrowed application fields. Fixed controls use positions; named
scopes isolate conditional sections and keyed rows. Removed IDs are retired so
stale events cannot address remounted controls.

`bash experiments/handler-api/check.sh` exited 0. Checks through real Moxi App
cover independent/shared counters, copied hosts, exactly one handler and one render
per action, labels above actions, form text/validation/Save/reset, disabled Save,
conditional state and stale events, two independent nested forms, shared editors,
Unicode and synthetic composition, App clipboard, keyboard routing, keyed list
reorder/insertion/removal/remount, and focus/cursor continuity. Rebuild, resize,
and paint do not replay actions. Cursor, selection, and composition-only changes
do not invoke value-change handlers.

The identity limitation was also demonstrated: unkeyed same-kind controls retain
position IDs when reordered, so focus transfers to another logical item. Explicit
identity boundaries remain necessary. The runtime rejects duplicate sibling
scopes. Compiler fixtures reject mutation through read-only render `self`, a
wrongly typed text handler, and a captured closure passed to the thin-handler API.
The wrong-handler diagnostic identifies the call site and expected String versus
supplied Int signature; the capture diagnostic exposes the lower-level `thin`
distinction. These are actual compiler outputs, not proof of novice comprehension.

`bash experiments/handler-api/native.sh --build-only` exited 0 with existing
`as_c_string_slice` deprecation warnings. The packaged native demo was opened.
Keyboard editing and Enter activation confirmed first-form `Saved: Grace`, then
second-form blank-nickname validation and `Saved: Mox` while the first remained
unchanged. An automated lowercase `space` did not visibly activate Save, and an
uppercase `Space` attempt was rejected by the automation tool with
`keyNotFound("Space")`; native Space behavior remains unresolved. Synthetic App
Space activation passes. Earlier native accessibility focus was not rechecked.

The actual application surface exposes a cost the counter alone misses:

```mojo
def first_name(mut self, text: String):
    self.first.set_name(text)

def first_save(mut self):
    self.first.save()
```

There are ten such forwarding methods for two nested forms, and five typed
callback arguments in the reusable form helper. Rows require an explicit owned
Int item key and `button_for`/`text_input_for` handlers that find the current item.
Conditional and list scopes use paired `begin_scope`/`end_scope` calls. The simple
control call is concise (`ui.button("Save", save, enabled=selected != "")`),
but this candidate has not made composition comparably simple.

The locked Mojo compiler accepts stored non-capturing methods. Its
[1.1 closure reference](https://mojolang.static.modular.com/1.1.0/docs/reference/closure-declarations/)
documents escaping/existential closure restrictions. This evidence does not prove
that all callback designs need forwarding, or that natural nested composition is
impossible in Mojo. Moxi already has ComponentSlot child routing; this experiment
did not integrate it or implement a typed view tree, automatic state projection,
or custom closure erasure. Those are material alternative designs, not features
to add silently until this experiment looks simpler.

Implementation `README.md` compares the actual source with the earlier render API
and existing Component API. It is a qualitative comparison; existing
`src/moxi/form.mojo` has fewer features and no apples-to-apples timing or line-count
claim is made. `results.txt` records executed checks, diagnostics, native
observations, compiler version, and source hashes.

## Decision supported by the result

Preserve separate view construction and event handling. Do not promote either
experimental authoring API yet. This experiment establishes a cleaner execution
model in ordinary Mojo, but its forwarding and identity conventions do not yet
meet the desired comfort. The next decision is whether improving composition is
worth additional framework machinery; no further broad research is required to
make that tradeoff visible. Any follow-up should justify its source and runtime
cost against the existing ComponentSlot/explicit-action boundary.

Confidence is high in narrow technical feasibility, moderate in the handler
direction, and low that this exact surface meets the comfort goal. A readable
nested-state implementation and independent successful edits involving dynamic
identity would strengthen that conclusion. Passing the current checks alone does
not establish universal ease.

Not verified: performance, full repository suite, non-macOS hosts, browser behavior,
VoiceOver, actual IME input, OS clipboard, mouse caret/drag, native Space or the
previous accessibility-focus observation, async/request integration, or independent
authoring comprehension. The prototype uses linear lookup and retains identity
history, has no virtualization, and caches application render output across bounds
changes. External state mutations require explicit refresh/rebuild. Read-only
`self` does not prevent external I/O, and exactly-once means per accepted event,
not durable delivery of effects.

## Child routing follow-up

The [child routing experiment](child-routing-experiment.md) now tests the existing
ComponentSlot boundary. Independent forms need zero per-field forwarding
handlers. Shared controlled inputs expose a cursor-loss bug when this host
refreshes before the parent settles a change; a separate bounded host variant
defers rendering and fixes it. The original experiment remains unchanged.
The follow-up narrows the remaining problem to parent composition and settlement
ergonomics; it does not establish a comfortable final API.
