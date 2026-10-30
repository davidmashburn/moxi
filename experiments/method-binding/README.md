# Direct method binding experiment

**Working authoring candidate, not a public API.** Keep current-state ownership;
let reusable children bind ordinary methods without author-written adapters.

The actual compiled [Editor](editor.mojo) renders like this:

```mojo
def render(self, mut ui: UI[Self, Document], document: Document):
    ui.label("Current: " + document.name)
    ui.text_input("Name draft", self.draft, Self.set_draft)
    ui.text_input("Private note", self.note, Self.set_note)
    ui.button("Apply", Self.apply)
    ui.button("Reload", Self.reload)
    ui.label(self.error)
```

These are its existing methods, including `apply(mut self, mut document: Document)`
and `reload(mut self, document: Document)`. It declares `Pane` conformance and
`comptime Context = Document`. It knows neither the root type nor its location in
the application. This is ordinary Mojo; there is no template parser, generated
application code, action enum, per-action forwarding function or retained borrow
of application state.

The parent still owns one route for the collection. This is the complete routing
method in [Application](application.mojo):

```mojo
def route_editor(mut self, key: Int, action: Action[Editor, Document]):
    for index in range(len(self.shell.workspace.editors)):
        if self.shell.workspace.editors[index].key == key and self.shell.workspace.editors[index].mounted:
            action(self.shell.workspace.editors[index], self.shell.workspace.document)
            return
```

Its render loop mounts each live editor:

```mojo
for editor in self.shell.workspace.editors:
    if editor.mounted:
        ui.child(editor, self.shell.workspace.document, Self.route_editor, key=editor.key)
```

The key names the child once; ordinary controls use positions within its scope.
Distinct child collections sharing a parent need distinct enclosing scopes if
their keys overlap. Conditional or reordered controls still need explicit scopes
when positional identity would change. Stable identity is a rule, not inference.

`Action` means “perform this editor operation on the current editor and document.”
The route chooses those values when the event arrives. Neither the child method
nor its stored binding captures a rendered document snapshot. The root still
refreshes once after dispatch. Render/rebuild/resize/paint do not execute actions.

## What became easier

All eight per-action adapters in the composition gate disappear. Adding another
local editable field requires five nonblank code lines: declaration,
initialization, a two-line setter, and `ui.text_input`. The route and application
are byte-for-byte unchanged in the compiled extension. The three-line additional
document validation policy also remains at the owner, independent of UI wiring.

| Nonblank, noncomment lines | Previous composition gate | Direct bindings |
| --- | ---: | ---: |
| Editor, including its rendering and adapters | 57 | 37 |
| Application, including state, actions and routing | 49 | 50 |
| Document | 47 | 47 |
| Complete application/domain total | 153 | 134 |
| Experiment runtime, including callback storage | 261 | 359 |
| Add a local Reviewer field | 9 | 5 |

The runtime increase is real. This removes repeated application work by moving
method adaptation into framework-owned code. Total application plus experiment
runtime grows from 414 to 493 counted lines. These are source-size observations,
not a complexity or performance score. The current runtime is a separate fork of
the earlier experiment; public Moxi and the original experiment are unchanged.

## What the runtime does and costs

[UI](runtime.mojo) builds temporary typed declarations. A child builds its own
list; mounting prefixes its identities and wraps its actions with the parent
route. The host reconciles the final list with retained IDs and text-input state.
The same Editor works under another root and inside another reusable Pane; the
latter receives its document through two routing levels in [nested.mojo](nested.mojo).

[Bindings](bindings.mojo) own immutable callback descriptors behind reference
counting. Domain state remains value-owned. A copied host shares descriptor
storage but routes into its own current model. Descriptor copies carry event
text/check values separately, so invoking one does not mutate shared bindings.

This deliberately simple prototype boxes both method pointers and child routes.
The two-editor application creates **20 descriptors per render**, each with a
payload allocation and an ArcPointer allocation: **40 allocation sites per
render**, before declaration/view/string allocations. Instrumented construction
and destruction counts cover two renders and final host destruction; see
`descriptor_lifetimes` in [results.json](results.json). Allocation-site counting
is not allocator profiling. No latency, throughput or memory benchmark was run.

There is no dependency graph or selective refresh. Callback allocation scales
with controls times nesting depth; route lookup and retained-control lookup are
linear. Retired controls retain identity records, although their callback
payloads and text state are released. This is not a bounded-memory list runtime.
Reducing allocation and bounding retired records are implementation requirements
before adopting it in production, not reasons to put forwarding methods back in
application code.

### Memory-safety boundary

The internal erased payload is allocated with its exact `Layout[T]`; its invoker
and destructor must use the same T. Destruction runs T's destructor exactly once
and deallocates with the original layout. Only the private framework constructor
sites establish this pairing; malformed custom low-level payload/invoker pairs
are unsafe. This is **not** a memory-safe arbitrary-closure facility.

The stored raw pointer has an untracked origin. `Action.__call__` explicitly keeps
its owner alive until the invocation completes; omitting that lifetime extension
produced an early-destruction failure in the initial probe. The corrected code
passes tracked-payload destruction/copy checks, including 100 remount cycles.
Those checks do not constitute a memory-safety proof. Relevant Mojo references:
[Pointer](https://mojolang.org/1.1.0/docs/std/memory/pointer/Pointer/),
[Allocation](https://mojolang.org/1.1.0/docs/std/memory/alloc/Allocation/), and
[explicit lifetime extension](https://mojolang.org/1.1.0/docs/manual/lifecycle/death/).

AddressSanitizer was attempted through both JIT and an AOT build on this macOS
setup. JIT could not resolve ASan symbols; AOT failed to link
`___asan_version_mismatch_check_v8`. **No sanitizer execution succeeded.**

## Reproduce and inspect

```sh
python3 experiments/method-binding/check.py
```

The runner retains exact generated sources, logs and extension diffs in a printed
temporary directory, and writes source hashes, commands, output and counts to
`results.json`. It asserts that the adapted common suite differs from the original
only in imports, routing syntax and child identity paths. It runs:

- the original composition gate against its original runtime;
- the same assertions against this runtime;
- the original root-control checks through shared-editor behavior, including
  checkbox/disabled buttons, Unicode, synthetic IME, clipboard, keyboard and
  cursor-only changes;
- true nested Pane composition, copied Host/current-document routing, and removal
  before refresh;
- descriptor copy/destruction and 100 mount/retire cycles;
- the complete common suite plus Reviewer-field and owner-policy extensions;
- an instrumented descriptor-lifetime run;
- an expected compiler rejection for mutation from a read-only render.

The original direct nested field-assignment form crashed the locked compiler.
Its source is retained under `diagnostics/nested_assignment.mojo`, excluded from
the positive suite. The passing nested check performs those same replacements
through ordinary model methods. This is a compiler workaround, not a requirement
of the proposed ownership model. The expected render-mutation rejection is a
normal compiler diagnostic, not that crash.

## Assessment and limits

**Moderate confidence:** this is the best authoring candidate from these
experiments. An editor consists of fields, methods and a render method; adding a
field stays in that editor. The remaining route is a genuine ownership boundary,
but its `Action` parameter is still a concept a beginner must understand.

**High confidence in the bounded behavior results; low confidence in universal
comfort or production readiness.** An unfamiliar developer successfully adding
a field, another instance and a nested component would increase confidence in
comfort. Failure to explain or maintain the one route would weaken it. Measured
allocation/refresh costs and a safer audited storage implementation could change
the implementation recommendation independently of the authoring surface.

Keep this syntax as the candidate. The next work should harden/measure its runtime
and try an unfamiliar-reader edit, rather than reopen ownership or add a language.
Do not merge this experimental runtime into public Moxi yet.

Not covered: full repository suite, native UI/accessibility, nested layout,
asynchronous operations, reentrancy/concurrency, arbitrary captured callbacks,
multiple context types in one pane, multi-window observation, performance
benchmarks or human usability. One explicit Context per pane and the tested
method signatures are the current limits.
