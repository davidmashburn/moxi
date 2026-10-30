# Direct method bindings: the current authoring candidate

October 29, 2026. Follow-up to the [shared-document comparison](shared-document-comparison.md).
**Compiled experiment; recommended authoring direction, not adopted public API.**

Keep current-state ownership and eliminate the per-action forwarding functions.
The child now writes its own methods directly in its render method:

```mojo
def render(self, mut ui: UI[Self, Document], document: Document):
    ui.label("Current: " + document.name)
    ui.text_input("Name draft", self.draft, Self.set_draft)
    ui.text_input("Private note", self.note, Self.set_note)
    ui.button("Apply", Self.apply)
    ui.button("Reload", Self.reload)
    ui.label(self.error)
```

This is actual compiled source from `experiments/method-binding/editor.mojo`.
`Editor` conforms to `Pane`, declares `comptime Context = Document`, and retains
its ordinary setters, `apply(mut self, mut document: Document)` and
`reload(mut self, document: Document)`. It has no root type parameter, application
path, action enum or per-action adapter. The runtime adapts method signatures.

The parent retains exactly one route for its editor collection:

```mojo
def route_editor(mut self, key: Int, action: Action[Editor, Document]):
    for index in range(len(self.shell.workspace.editors)):
        if self.shell.workspace.editors[index].key == key and self.shell.workspace.editors[index].mounted:
            action(self.shell.workspace.editors[index], self.shell.workspace.document)
            return
```

The render loop calls:

```mojo
ui.child(editor, self.shell.workspace.document, Self.route_editor, key=editor.key)
```

That route supplies the current child and document when an event arrives. The
key identifies one child, not every control. Adding a field or action does not
change the route. Adding an editor instance needs no new route or action bridge.
The root's state layout and route remain explicit; this is not zero-wiring
composition. A nested Pane can route through its inherited document context too.

## Evidence and cost

Run `python3 experiments/method-binding/check.py` in the implementation checkout.
Eight checks pass: original composition baseline; identical assertions on the
new runtime; original root-control/Unicode/IME/clipboard checks; genuine nested
Pane composition; callback lifetime/copy checks; a compiled Reviewer-field and
owner-policy extension; instrumented descriptor allocation/destruction; and an
expected compile rejection for mutation from read-only render.

The common suite includes normalized/rejected edits, independent drafts and
notes, owner policy, undo, once-only effects, a third instance, another root,
keyed reorder with focus/cursor continuity, removal/remount, stale events and
value-copy isolation. The new nested test copies the entire Host, replaces its
document and invokes the already-bound Reload method: it reaches the copied
root's current document. Unmounting before refresh prevents mutation through the
old route as well. The lifetime check retains one payload across a retained-UI
copy, releases it after both owners retire it, and runs 100 further remounts.

| Counted nonblank, noncomment lines | Previous current-state gate | Direct bindings |
| --- | ---: | ---: |
| Editor | 57 | 37 |
| Application | 49 | 50 |
| Document | 47 | 47 |
| Complete author code | 153 | 134 |
| Runtime, including storage | 261 | 359 |
| Add Reviewer field | 9 | 5 |
| Author-written per-action adapters | 8 | 0 |

The Reviewer extension is only a field, initialization, setter and input. The
application is unchanged. The new centralized validation rule takes the same
three lines as before. These counts include the actual ownership/routing code;
they are not complexity measurements. Total author code plus experiment runtime
increases from 414 to 493 lines.

The runtime creates temporary typed declarations, then reconciles IDs and text
state against retained controls. It retains owned immutable callback descriptors,
not pointers into application state. Copying descriptors shares their storage;
copying the domain still copies values. Actions run before a single refresh.
There is no render-time action replay or observation engine.

This implementation allocates **20 callback descriptors per render** for the
two-editor example. Each has a payload allocation and an ArcPointer allocation,
so there are **40 callback allocation sites per render**, before UI allocations.
An instrumented two-render run observed 40 descriptors created, 40 destroyed,
peak 40 live, and zero after Host destruction. This counts descriptor lifetimes;
it is not allocator profiling or a latency benchmark. Binding construction scales
with callback count times routing depth. Root refresh and linear lookups remain.
Retired identity records accumulate; retired payloads and text state are released.

## Safety and compiler limits

The callback storage erases payload types behind a private raw pointer. Allocation,
invocation and destruction must agree on the payload type and layout. The final
reference destroys that payload and frees its allocation. `Action.__call__`
explicitly extends the owner lifetime through invocation because the raw pointer
has lost its origin. An initial probe without that extension demonstrated early
destruction; the corrected implementation passes the lifecycle scenarios. This
is framework machinery, but it requires an audit before production adoption.

Mojo references used for the storage boundary:
[Pointer](https://mojolang.org/1.1.0/docs/std/memory/pointer/Pointer/),
[Allocation](https://mojolang.org/1.1.0/docs/std/memory/alloc/Allocation/), and
[lifetime extension](https://mojolang.org/1.1.0/docs/manual/lifecycle/death/).
These document the primitives, not the safety of this implementation.

Sanitizer verification did not run successfully: JIT could not resolve ASan
symbols, and the AOT sanitizer build failed to link
`___asan_version_mismatch_check_v8`. The positive lifetime tests are not a
substitute for sanitizer coverage or a memory-safety proof.

Direct nested assignment in the first test form crashed Mojo 1.1.0. That source
is preserved as `diagnostics/nested_assignment.mojo` and excluded from the
positive suite. Performing the same replacement through ordinary model methods
compiles and passes. The read-only-render diagnostic is a separate, normal
compiler rejection.

Not verified: full repository suite, native UI/accessibility, nested layout,
performance, async/reentrancy/concurrency, arbitrary closure captures, multiple
context types in one Pane, multi-window observation or unfamiliar-reader usability.
The framework signatures cover only the tested local/text/bool/context methods.

## Decision

**Moderate confidence:** retain this as the leading authoring candidate. The
component has fields, ordinary methods and a render method; local additions stay
local. The parent route still asks the reader to understand current-state action
routing. That remaining concept must earn its place in a reader exercise.

**High confidence in the bounded observed behavior; low confidence in universal
comfort or production readiness.** Keep the current-state ownership decision;
do not reopen the framework inventory. Do not merge this runtime into public
Moxi yet. Next, measure and reduce callback allocation, audit/verify erased
storage, bound retired state, and have an unfamiliar reader add a field, another
instance and a nested component. Preserve the syntax while evaluating those
implementation changes. Difficulty maintaining the route would weaken the API
recommendation; excessive measured costs would weaken this runtime implementation.

## Provenance

Implementation baseline: `feat/data-workbench` at
`f458f1fc4085b533883434e447fbcb5fbfbc9cb6`. Planning baseline: `project-planning`
at `f98395b3c525c0e3b093ac291867ea5dad43d22f`. Both experiments and their recorded
results are committed in [0764b1b](https://github.com/davidmashburn/moxi/commit/0764b1b5e8017526a8e94b2b367480a9d7f7590f)
on `feat/data-workbench`. Unrelated changes were preserved. No public Moxi
source, original runtime, dependency or lockfile changed. Source hashes were
rechecked before publication; the passing suites were not rerun for this
documentation-only publication update.

`experiments/method-binding/results.json` records the locked compiler, exact
commands, source hashes, materialized-source hashes, output, extension diff,
line counts and descriptor measurements. The complete authoring source, runtime,
README, diagnostics and runner are beside it. Generated inputs and full logs
remain in the temporary directory printed by the runner.
