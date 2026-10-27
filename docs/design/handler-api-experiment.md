# Ordinary Mojo handlers and scoped identity

Status: bounded experiment in progress, October 27, 2026. No public API adoption.

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

Pending execution. The experiment is authorized; adoption is not decided.
