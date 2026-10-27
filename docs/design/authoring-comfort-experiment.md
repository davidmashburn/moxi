# Authoring comfort: a form written three ways

Status: executable subset experiment completed October 27, 2026; no public API
adoption. The two earlier Moxi surface proposals remain unimplemented and were
rejected in author feedback. The follow-up below uses familiar Marko syntax.
Neither the source comparison nor the executable follow-up is a usability study.

The latest follow-up is the [ordinary Mojo render experiment](render-api-experiment.md).
It tests ordinary fields and controls that report interaction without a tags
compiler. The Marko experiment below remains comparison evidence, not the selected
authoring direction.

Implementation baseline: `feat/data-workbench` at
[`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`](https://github.com/davidmashburn/moxi/tree/c8c7cbb7741519c9796a02ffa25c02e701b2f58a).
The earlier uncommitted probes are described in the
[runtime findings](scoped-reactivity-experiment.md). Those results remain useful,
but do not establish a comfortable authoring surface. No product code changes
are part of this experiment.

## Executable follow-up: observed results

The author authorized committing the planning record and running the experiment.
The pre-experiment record was committed as `e3c6eb0`. A new isolated directory,
`experiments/tags-authoring/`, now contains a small Marko-AST-to-Mojo compiler,
reusable counter and name-field sources, a greeting form, native demo, behavior
checks, and source-change checks. It is **uncommitted implementation work** on
`feat/data-workbench` at the baseline above, not available in that baseline's Git
snapshot. No production Moxi APIs or existing source files were changed.

The key authoring distinction is executable:

```marko
<Counter count=0/>
<Counter count=0/>
```

These own independent values. To share, declare one value in the parent:

```marko
<let/shared=0>
<Counter count:=shared/>
<Counter count:=shared/>
```

The reusable counter uses `<let/count:=input.count>` and returns `<return:=count>`.
A name field follows exactly the same rule for its string. A parent can read its
returned value in an expression or assign to it in a handler. The compiler
supplies the event routing and state bookkeeping; Moxi supplies layout, editing,
focus routing, paint, and the native window.

### Verification performed

- `bash experiments/tags-authoring/check.sh` passed with exit 0. It runs eight
  official Marko HTML/DOM compilations with zero diagnostics, eleven rejected
  unsupported-source cases, generated Mojo behavior checks, and four authoring
  variations. Exact output and source hashes are captured in the experiment's
  `results.txt`.
- Real Moxi `App` checks passed for independent/shared counters, fresh roots,
  keyboard activation, child-return bindings, live trimmed preview, immediate
  Save, disabled Save, reset, conditional mounting, and rejection of events sent
  to removed controls.
- Headless native-editor checks passed for Unicode deletion, composition/commit,
  focus/cursor continuity across rebuild, Tab routing, and clipboard hooks.
  Direct clipboard-hook checks are not OS clipboard verification.
- Source variations passed without changing compiler or runtime: add a validation
  rule once and affect both preview and Save; change one bound counter to an
  independent counter; move a counter inside an `if` and observe local-state
  reset on remount; share text between two fields with separate cursors.
- `native.sh --build-only` passed. The macOS window was opened and interacted with:
  typing/live preview, Save, blank nickname disabling Save, nickname editing,
  text surviving hide/show, and Restore defaults worked. Builds emitted 14
  existing native-window `as_c_string_slice` deprecation warnings.

One native issue remains unresolved: an accessibility-targeted click on the
nickname field did not move editing focus; subsequent typing went into the
primary field. A pointer-coordinate click focused the nickname correctly. The
cause was not isolated between automation and Moxi accessibility/focus handling.
Do not report complete native interaction or accessibility coverage.

### Assessment and limits

**High confidence in narrow feasibility:** the supported authoring subset can
produce working native Moxi controls without application-authored routing,
binding objects, or editor bookkeeping. A mismatch on the verified programs
would weaken that conclusion. This is a material advance over a syntax sketch.

**Authoring comfort remains unmeasured.** The author's negative assessment of the
prior candidates remains valid; this new implementation has not yet been judged
through unassisted author changes. Familiar spelling is a hypothesis about
comfort, not proof. Lists, async work, debugging, and real Mojo application-logic
interop could expose much greater complexity and change the recommendation.
There is still no recommendation to adopt a new public language/API.

The experiment accepts static component instances and scalar state, a small
expression set, bindings/returns, `if`, and basic controls in a vertical column.
It expands derived expressions at their uses and rebuilds the whole view after
successful events. It neither uses nor validates the earlier tracked-dependency
runtime. Unsupported syntax is rejected; this is not full Marko compatibility
or an HTML/CSS implementation. The form uses immediate validation: the original
touched-on-blur requirement is **not implemented**, because the ordinary Moxi
component event surface lacks blur.

The full repository suite, performance benchmarks, Linux/native cross-platform
checks, VoiceOver, an actual IME session, OS clipboard interaction, native counter
interaction, and browser behavioral parity were not run. Reproduction commands,
supported subset, implementation details, and further limits live beside the
experiment in `experiments/tags-authoring/README.md`.

The next decision should come from the author editing these actual sources and
explaining the ownership changes, not from another invented syntax sketch.

## Assessment before the executable follow-up

The author found the proposed surfaces confusing and far from the comfort of
Marko's Tags API. The preference for candidate B below is withdrawn. That is
direct negative feedback on these sketches, not a general usability study.
Neither candidate has earned adoption. The examples and initial assessment are
retained as experiment history.

The next explanation starts with the existing Moxi counter. It owns `count`,
builds a view from it, and increments it when a button is activated. The current
`CounterState.update` also checks event targets/action IDs and mouse, action,
and keyboard event kinds. See
[app.mojo](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/app.mojo).
That routing is real implementation work which a simpler button-authoring API
should absorb. It is not necessary to understand the counter's application logic.

Use familiar Marko directly as an authoring benchmark rather than introducing
another spelling for every concept. For example, the desired complete counter
component could read:

```marko
<let/count=0>

<button onClick() { count++ }>
  Clicked ${count} times
</button>
```

This is a Marko reference for the desired experience, not supported Moxi syntax
or a decision to build a native Marko compiler. It says what is remembered, what
is displayed, and what an action changes. Moxi would supply native layout,
painting, input routing, and screen updates beneath that description. The source
language and compilation route remain open.

The ease-of-use test is progressive: placing two counters should give two
independent instances; sharing their count should require one understandable
ownership change; extracting a reusable control should preserve the same authoring
rules. Native keyboard activation, focus, and editing behavior belong in the
controls. These expectations are proposed requirements, not verified features
of an authoring layer. A tiny counter does not establish ease for forms, keyed
lists, asynchronous operations, or debugging.

Confidence is high that neither existing probe establishes authoring comfort;
confidence in a replacement surface remains low until realistic changes can be
understood and performed without learning another layer of machinery. This
follow-up inspected current counter source; it did not run new code or tests.

## Initial assessment (superseded)

Can Moxi make a stateful, reusable component pleasant to write, read, and change?
Removing manual dependency lists is only one part of that question. We also need
to examine state ownership, returned values, event handlers, and the lifetime of
conditional children.

The strongest hypothesis from this comparison is that the desired comfort comes
from a coherent component model: a component can render UI, own state, and expose
a live value at its call site. Ordinary expressions can consume that value;
assignment and binding have consistent meanings. Angle brackets are one possible
spelling of that model. **Confidence: medium** in this explanation of the desired
experience, high that the previous runtime probes did not test it.

Candidate B was initially my preferred surface to discuss next. It keeps those
relationships visible with less handle manipulation than A. This is a provisional
reading judgment, not evidence that a new language is worth its cost. A successful
library implementation with similarly local changes would weaken the case for B;
awkward diagnostics, ownership, or editor integration would weaken it further.

## Shared scenario and expected behavior

A greeting editor has a primary name, an optional nickname, a live preview, a
local Save action, and Restore defaults. Saving only records the selected,
trimmed name in local state; there is no network request or persistence.

- The reusable `NameField` owns its value when given an initial value. It can
  alternatively edit a binding supplied by its parent, using the same component
  definition. It exposes an assignable value to its caller.
- Each field owns a `touched` flag. Blur marks it touched. A touched blank field
  displays “Required”; validation checks the trimmed value without rewriting
  the user's input.
- The primary field is always mounted and initially contains “Ada”.
- The parent owns the nickname string outside the conditional section. Enabling
  “Use nickname” mounts its field; disabling it destroys that field's local state.
  Reopening preserves the nickname text and starts `touched` as false.
- Preview and Save use only the selected name. A blank selected name displays
  “Name required” and disables Save, even before the field has been touched.
  An error on the unselected primary field does not disable Save.
- Restore defaults sets primary to “Ada”, nickname to empty, selection to primary,
  and saved output to empty. It intentionally leaves the mounted primary field's
  touched flag alone; the button resets values, not the entire component tree.

For example: enable nickname, blur it empty (error shown), type “Countess”, disable
and re-enable nickname. The text remains “Countess”; its field starts untouched.
Clear it, then disable nickname: Save becomes enabled again for “Ada”.

All examples include the parent and the reusable field. Host startup, visual
styling, accessibility polish, keyboard submission, and asynchronous saving are
outside this comparison. The native candidates still owe real text-selection,
focus, and IME behavior; a `String` alone does not implement an editor.

## Reference: Marko 6

These are original examples using documented Marko features. In
[core tags](https://markojs.com/docs/reference/core-tag), `<let>` owns state,
`<const>` derives values, and `<return>` exposes a tag variable. An assignable
return lets the parent reset a child-owned value. `<if>` discards child state
when its branch disappears. The
[controllable pattern](https://markojs.com/docs/explanation/controllable-components)
lets the same field accept either an initial value or parent-controlled state.
The [binding shorthand](https://markojs.com/docs/reference/language#shorthand-bind)
connects a value and its change handler. Native input bindings are documented in
[native tags](https://markojs.com/docs/reference/native-tag).

`name-field.marko`:

```marko
<let/value:=input.value>
<let/touched=false>
<const/error=(touched && !value.trim() ? "Required" : "")>

<label>
  ${input.label}
  <input value:=value onBlur() { touched = true }>
</label>
<if=error><p role="alert">${error}</p></if>

<return:=value>
```

`greeting-form.marko`:

```marko
import NameField from "./name-field.marko";

<let/nickname="">
<let/useNickname=false>
<let/saved="">

<NameField/name label="Name" value="Ada"/>
<label>
  <input type="checkbox" checked:=useNickname>
  Use nickname
</label>
<if=useNickname>
  <NameField label="Nickname" value:=nickname/>
</if>

<const/selected=(useNickname ? nickname : name).trim()>
<p>${selected ? `Hello, ${selected}` : "Name required"}</p>
<button type="button" disabled=!selected onClick() {
  saved = selected;
}>Save</button>
<button type="button" onClick() {
  name = "Ada";
  nickname = "";
  useNickname = false;
  saved = "";
}>Restore defaults</button>
<if=saved><p>Saved: ${saved}</p></if>
```

The primary field's invocation introduces `name`. We did not first declare a
second copy of its state or write a callback to mirror it. The nickname uses an
explicit parent binding because its text must outlive that field's conditional
mount. These two ownership choices are visible at their respective call sites.

This is still a language to learn: `/name`, `:=`, controllable initialization,
and assignable returns carry semantics. “Comfort” here does not mean no rules.
Marko's graph is discovered at compile time, per its
[reactivity reference](https://markojs.com/docs/reference/reactivity); the prior
Moxi runtime read collector is a different mechanism.

## Candidate A: a retained UI builder library

**Mojo-shaped pseudocode.** Every `UI`, `Binding`, `Control`, `Initial`, and
`Bound` operation below is proposed. Closure capture and these generic call
signatures have not been validated with Mojo. This sketches what a library
would need to offer; it does not claim today's Moxi can run it.

The component body runs again after a relevant edit. Named state slots survive
those runs. `ui.child` identifies a child within its parent's scope, renders it,
and returns its exposed binding. At the end of a build, an omitted child is
disposed. `ui.control` uses either one local state slot or the parent's binding;
it must not synchronize two independently mutable copies.

```text
def NameField(mut ui: UI, label: String,
              value: Control[String]) -> Binding[String]:
    var text = ui.control("value", value)
    var touched = ui.state("touched", False)
    var error = "Required" if touched.get() and not text.get().strip() else ""

    ui.text_input("editor", label=label, value=text,
                  on_blur=lambda: touched.set(True))
    if error:
        ui.label("error", error, role="alert")
    return text

def restore(name: Binding[String], nickname: Binding[String],
            use_nickname: Binding[Bool], saved: Binding[String]):
    name.set("Ada")
    nickname.set("")
    use_nickname.set(False)
    saved.set("")

def GreetingForm(mut ui: UI):
    var nickname = ui.state("nickname", "")
    var use_nickname = ui.state("use_nickname", False)
    var saved = ui.state("saved", "")

    var name = ui.child("name", NameField,
                        label="Name", value=Initial("Ada"))
    ui.checkbox("use_nickname", "Use nickname", value=use_nickname)
    if use_nickname.get():
        ui.child("nickname", NameField,
                 label="Nickname", value=Bound(nickname))

    var selected = (nickname.get() if use_nickname.get()
                    else name.get()).strip()
    ui.label("preview", "Hello, " + selected if selected else "Name required")
    ui.button("save", "Save", enabled=bool(selected),
              on_click=lambda: saved.set(selected))
    ui.button("restore", "Restore defaults",
              on_click=lambda: restore(name, nickname, use_nickname, saved))
    if saved.get():
        ui.label("saved", "Saved: " + saved.get())
```

This is a meaningful improvement over the probe: no source numbers, subscription
replacement, explicit read collector, or separate dependency masks appear in the
component. A conservative first implementation could rebuild the whole form
after each event. Fine-grained tracking is not required to judge this surface.

It still asks the author to manipulate handles and provide identity keys. The
same logical value appears as a `Binding`, `.get()` result, `.set()` target, and
`Bound(...)` argument. Those distinctions may be acceptable to a Mojo programmer;
they are visible friction for the experience we are seeking.

The hard implementation questions are concrete. Handlers must retain safe
handles rather than stack borrows. A returned handle must not outlive its owner
unchecked. The Save handler captures a build-time snapshot, so event delivery
must settle a preceding edit before using that handler; otherwise Save could
record stale text. Rebuilding must preserve the active editor and composition
state. Child disposal and replacement of handlers need a defined transaction.
Hiding these obligations behind `UI` does not prove them solved.

## Candidate B: a declarative component language

**Invented syntax, not Mojo.** A separate component source would compile to Mojo.
This deliberately allows new syntax so we can assess the surface before deciding
whether a compiler is justified. Names and punctuation are provisional.

```text
component NameField(label: String, value: String = ""):
    state text := value
    state touched = False
    let error = "Required" if touched and not text.strip() else ""

    TextInput(label=label, value:=text):
        on blur:
            touched = True
    if error:
        Label(error, role="alert")
    return bind text

component GreetingForm():
    state nickname = ""
    state use_nickname = False
    state saved = ""

    NameField/name(label="Name", value="Ada")
    Checkbox("Use nickname", value:=use_nickname)
    if use_nickname:
        NameField(label="Nickname", value:=nickname)

    let selected = (nickname if use_nickname else name).strip()
    Label("Hello, " + selected if selected else "Name required")
    Button("Save", enabled=bool(selected)):
        on click:
            saved = selected
    Button("Restore defaults"):
        on click:
            name = "Ada"
            nickname = ""
            use_nickname = False
            saved = ""
    if saved:
        Label("Saved: " + saved)
```

The `/name` deliberately borrows the idea of a tag variable: calling a component
both inserts its UI and exposes its result. A different spelling could replace
it; preserving that capability matters more than preserving the slash.

The minimum promised semantics are substantial:

- `state x = initial` initializes once per mounted instance. `let x = expression`
  is a read-only reactive derivation. It must not be confused with an ordinary
  Mojo local evaluated only once.
- `state text := value` is a controllable slot. A plain `value="Ada"` supplies
  its initial value; `value:=nickname` supplies parent-owned readable/writable
  state. Binding mode is fixed for the instance in this initial design.
- `return bind text` exposes a writable capability scoped to that instance.
  Reading `name` reads it; assigning `name` invokes its write operation. A plain
  `return expression` would expose a read-only derived result instead.
- `if` owns the lifetime of everything inside its branch. Stable call sites
  identify children across updates. Repeated children will need explicit stable
  keys; this form does not establish keyed-list behavior.
- Event bodies mutate state and settle UI after the event transaction. Derived
  values read inside an event must reflect preceding writes, or the compiler
  must reject that read. This is a proposed requirement, not a claimed Marko
  guarantee or an implemented Moxi scheduler.
- UI expressions and derivations are pure. Imported Mojo helpers consume values;
  they cannot mutate hidden UI state. Async effects and native resources require
  separate explicit lifetime contracts.

Those promises explain both B's appeal and its cost. A preprocessor that only
rewrites indentation into function calls is insufficient. State storage, routing,
binding ownership, conditional teardown, source locations in diagnostics, and
editor tooling all become part of the design. Initial code generation could
recompute the whole component, allowing us to validate semantics before choosing
dependency inference or tracking.

## Change exercises: where comfort survives or breaks

These are source-level walkthroughs, not measured developer tasks.

**Lift the primary value into the parent.** Suppose another sibling should edit
the same primary name. Marko adds `<let/name="Ada">` and replaces the field call
with `<NameField label="Name" value:=name/>`. B adds `state name = "Ada"` and
replaces its call with `NameField(label="Name", value:=name)`. In both, preview
and Restore defaults remain the same. A adds `ui.state("name", "Ada")` and
passes `Bound(name)`; `.get()` and `.set()` consumers likewise stay the same.
All three avoid changing the reusable field. This is a real strength of A too.

**Reuse the field with entirely local state.** Marko's
`<NameField label="Alias" value=""/>` and B's `NameField(label="Alias", value="")`
need no parent state declaration. A uses
`ui.child("alias", NameField, label="Alias", value=Initial(""))`.
Returning a value is optional at the call site in every candidate.

**Change validation to require two trimmed characters.** Change the field's
validation expression and the parent's Save eligibility expression. Every
version currently duplicates the rule! A pleasant surface does not remove that
design flaw. Extract one pure validation helper and call it from both locations.
A future return record containing `{value, valid}` may help, but it should earn
its extra API through a case that needs it. Non-ASCII length rules must be
specified before implementing this particular requirement.

**Preserve touched state while hiding the nickname.** The current contract is
destroy/remount. Marko offers `<show>` with different retention semantics. Neither
Moxi sketch implements an equivalent. A needs a retained-but-hidden child
operation; B needs an explicit construct such as `show` with rules for focus,
layout participation, and resources. Reinterpreting `if` would silently break the
original contract. This exposes an additional primitive rather than a free win.

**Reset the primary field's touched state too.** The returned string is
insufficient. Remount the field using an explicit identity change, expose a reset
operation, or make touched parent-controlled. None is written in the baseline.
This boundary should be visible rather than hidden behind a misleading “reset”
promise. The baseline button is deliberately called Restore defaults.

**Introduce a delayed save.** An async handler cannot safely keep an arbitrary
child reference alive after that child unmounts. Snapshotting the selected string
is appropriate for the request payload; updating the UI afterward requires an
owner/lifetime policy. The earlier read collector resolves neither issue, and
this experiment makes no async capability claim.

## What the comparison supports

| Question | Marko reference | A: proposed library | B: proposed language |
| --- | --- | --- | --- |
| UI plus returned live value | Tag variable | Explicit returned handle | Component result |
| Read / write | Value / assignment | `.get()` / `.set()` | Value / assignment |
| Local or parent ownership | Initial value or binding | `Initial` or `Bound` | Initial value or binding |
| Dependency maintenance by author | Expressions | No lists; rebuild policy hidden in builder | Expressions; compiler policy unresolved |
| Conditional lifetime | Existing language rule | Proposed builder disposal rule | Proposed language rule |
| Cost exposed to author | Marko syntax and semantics | Handles, keys, callbacks | New syntax and semantics |
| Evidence here | Source compilation, as recorded below | Complete sketch only | Complete sketch only |

Do not rank these by line count or imply that B has won a user test. Its concise
surface benefits from facilities we have only named. A is closer in shape to a
library, but its lifetime and callback implementation is also unproven.

The current implementation uses `Component.build(self, bounds)` and
`update(mut self, event, view)`, explicit `ComponentSlot` routing, and value-oriented
reactivity contracts. See
[component.mojo](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/component.mojo)
and
[reactivity.mojo](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/reactivity.mojo).
Neither proposed surface is a small rename of those APIs. The current component
API can implement the behavior; the sketches propose who writes its plumbing.

## Initial decision boundary and verification

Both Moxi candidates remain exploratory; the initial preference for B as a
comfort target was subsequently withdrawn as recorded above. Do not adopt runtime
tracking merely because the previous trace passed. A later implementation
experiment should first prove the
shared scenario, including safe child bindings, edit/Save ordering, teardown,
and real native editor continuity. Whole-form recomputation is an acceptable
starting point for evaluating authoring; performance can be measured afterward.

Before any language investment, also test a keyed editable list, extraction of
shared pure logic, and an asynchronous operation with cancellation. Error
messages for binding a read-only result and using a result after its owner is
gone are part of the authoring experience, not backend details to postpone
indefinitely. This is a proposed next gate, not a scheduled implementation task.

Fresh validation from the initial comparison: the two named Marko files in the
Reference section were extracted verbatim into a
temporary directory and compiled with `marko@6.4.6`, `@marko/compiler@5.42.12`, and
Node v26.10.0. Both files passed `html` and `dom` compilation (four successful
compiles), with `api: "tags"` and empty diagnostic lists. Dependencies were
installed only in the temporary directory with package scripts disabled. The
initial compiler invocation could not resolve a relative translator package;
using `require.resolve("marko/translator")` fixed the harness configuration.

To reproduce, copy those two Marko blocks into the named files in a disposable
directory, run
`npm install --ignore-scripts --no-audit --no-fund --save-exact marko@6.4.6 @marko/compiler@5.42.12`
there, and run this as `compile.cjs` in that directory:

```javascript
const { compileFileSync } = require("@marko/compiler");
const path = require("node:path");
for (const output of ["html", "dom"]) {
  for (const file of ["name-field.marko", "greeting-form.marko"]) {
    const result = compileFileSync(path.join(__dirname, file), {
      output,
      translator: require.resolve("marko/translator"),
    });
    const diagnostics = result.meta.diagnostics || [];
    console.log(file, output, result.meta.api, diagnostics);
    if (diagnostics.some(d => d.type === "error")) process.exitCode = 1;
  }
}
```

This uses the documented
[compiler API](https://markojs.com/docs/reference/compiler). Compilation checks
source acceptance, not the full behavioral contract. No browser interaction test,
TypeScript check, new native Moxi runtime, Mojo compilation of the sketches,
usability study, or performance comparison has been performed. The earlier probe
checks were not rerun; their limits remain in the linked findings. Planning
changes passed whitespace and local-link checks. Edits are local and uncommitted.
