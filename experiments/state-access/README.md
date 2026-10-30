# State access and update work

October 30, 2026. Experimental code, not a public API. This follows
[direct method binding](../method-binding/README.md) and corrects a gap in the
[shared-document comparison](../shared-document/README.md): shared pointers alone
did not test Solid's context lookup or dependency tracking.

Follow-up: [actual Marko 6 Tags API browser experiment](marko/README.md) adds
three source variants, 375 browser assertions and 45 matched output cases. Its
results and comparison are under `marko/`; the original comparison below stays
specific to Mojo and Solid.

## Contract

Compare a nested Shell → Workspace → Group → Editor workflow. Each editor has
private draft, note and validation state; it reads a shared document and a second
settings dependency. A commit checks document identity, revision, permission and
validation. Other drafts remain private until Reload. Exercise removal, remount,
document replacement and a new local field. Preserve existing experiments and
public Moxi. Do not infer native performance or human comfort from green tests.

The two implementations intentionally have different fidelity:

- [Mojo application](application.mojo): compiled field adapters and a reusable
  keyed collection over the existing method-binding runtime, tested through real
  Moxi `App`. This borrows Xilem's current-state projection idea; it does not run
  Xilem. Services are an explicit typed bundle, not ambient context lookup.
- [Solid application](solid/): actual Solid client reactivity and providers in a
  headless Node process. Its sinks stand in for UI properties; no DOM or native
  input integration is claimed.

The work-count experiment measures a common five-output projection (Current,
draft, note, error, Apply enabled). Apply enabled reads permission only; the
command reports invalid names. The initial scale data and five mutations match
exactly. `compare.py` verifies source hashes and equal changed-write counts
across all 15 cases, recording the joined results in `comparison.json`. Mojo's [full/memo comparison](update_work.mojo)
is **separate from the App runtime**. Its memo cache visits every editor and
compares five dependency values before recomputing that editor. This is one
possible memoization strategy, not a lower bound on Xilem or Moxi performance.
Labels, layout, focus, callback construction and widget reconciliation are not
included in those five-output counts.

## What the compiled Mojo author writes

The editor still uses ordinary fields and methods:

```mojo
def render(self, mut ui: UI[Self, Services], services: Services):
    ui.label("Current: " + services.document.name)
    ui.text_input("Name draft", self.draft, Self.set_draft)
    ui.text_input("Private note", self.note, Self.set_note)
    ui.button("Apply", Self.apply, enabled=services.settings.writable)
    ui.button("Reload", Self.reload)
    ui.label(self.error)
```

The intermediate Shell has no handwritten action route:

```mojo
def render(self, mut ui: UI[Self, Services], services: Services):
    field["workspace"](ui, self, services, key=1)
```

The field name is checked at compile time. The framework adapter projects the
same field during rendering and event dispatch. Its `rebind` calls assert type
equality at instantiation; they are not unchecked casts. `Keyed[Editor]` owns the
collection and routes by current membership. The application still supplies one
route where separately owned shell state and services meet:

```mojo
def route_shell(mut self, key: Int, action: Action[Shell, Services]):
    action(self.shell, self.services)
```

This saves forwarding functions but introduces two framework concepts (`field`
and `Keyed`). It does not prove that this spelling is comfortable. The typed
services bundle still appears in intermediate component signatures. There is no
template parser, code generator or new language.

## Reproduce

From the repository root:

```sh
python3 experiments/state-access/check.py
(cd experiments/state-access/solid && npm ci && npm run check)
python3 experiments/state-access/compare.py
```

[results.json](results.json) records the compiler, source hashes, commands and
outputs. The runner checks the old binding baseline; the small field adapter;
nested App behavior; an added Reviewer field with unchanged application/adapters;
full/memo output equivalence and work counts; expected generic-lens origin,
missing-field and wrong-context compiler errors; and descriptor lifetimes.
Temporary generated sources and full logs are retained at the printed path.

The new behavioral tests include normalization, conflict/reload, undo, Unicode
codepoint length, permission enforcement in both widgets and commands, explicit
service overrides, copied hosts, a same-revision replacement document, stale
retained actions and 100 collection removals/remounts. The earlier method-binding
suite remains the source of broader input/IME/cursor coverage; that whole suite
is not rerun here. The common baseline is rerun.

## Limits that the experiment exposes

- The field adapter retains no application-state pointer. It still inherits the
  old runtime's unsafe erased callback storage and per-render descriptor boxing.
  More nesting adds wrappers. The two-editor, four-boundary application creates
  40 descriptors in one render and destroys all 40; there are two allocation
  sites per descriptor before UI allocations. This is instrumentation plus
  source inspection, not allocator profiling or a memory-safety proof.
- `Keyed.remove` followed by `append` allocates a fresh key and rejects old
  actions. Replacing the **whole collection** resets the allocator. A retained
  action with a reused key then reaches the replacement child; an executable
  limit test demonstrates this. A collection-generation/lifetime contract is
  still required before adoption. Stable identity is not solved by a wrapper.
- The inherited retained UI keeps retired identity records. The 100-cycle check
  bounds collection entries, not retained-UI memory. No bounded-memory claim.
- Document identity plus revision prevents stale drafts committing into a new
  document at revision zero. The application must supply a distinct identity
  for a distinct document. Reactive observation does not replace this rule.
- [The simple generic lens trait](diagnostics/generic_lens.mojo) fails because
  its whole-parent return origin does not match the field's origin. This says
  nothing about every possible Mojo lens design.
- The original integration probe crashed Mojo 1.1.0 with deeply nested calls.
  [Its source](diagnostics/nested_call_crash.mojo) is preserved outside the normal
  suite. Moving operations into ordinary model methods compiled and passed.
  The crash was not minimized to a single compiler defect.

No public API, production runtime or repository dependency changes. Not tested:
native rendering/accessibility, full repository suite, latency, allocator costs,
sanitizers, concurrent/reentrant updates, asynchronous commands or unfamiliar
developer usability. Solid results and the comparative interpretation are in
the planning worktree's `docs/design/state-access-comparison.md`.

## Primary references

- [Xilem lens](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.lens.html): project a
  parent into the current child state.
- [Xilem memoize](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.memoize.html): reuse
  a view until explicit comparison data changes.
- [Solid context](https://docs.solidjs.com/concepts/context): scoped ancestor
  lookup avoids passing dependencies through intermediate components.
- [Solid fine-grained reactivity](https://docs.solidjs.com/advanced-concepts/fine-grained-reactivity):
  reads establish subscriptions for targeted computations.
- [Mojo reflection](https://mojolang.org/1.1.0/docs/manual/metaprogramming/reflection/)
  and [reference origins](https://mojolang.org/1.1.0/docs/manual/values/lifetimes/).
