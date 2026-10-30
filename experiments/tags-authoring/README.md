# Tags authoring experiment

A small subset of real Marko syntax now drives native Moxi controls. The counter
and greeting form run through Moxi's existing `App`, layout, event routing,
text editor, and renderer. No production Moxi API was changed.

This is an executable feasibility experiment, not a complete Marko backend or
an adopted Moxi language. Results were observed on October 27, 2026, against
`feat/data-workbench` at `c8c7cbb7741519c9796a02ffa25c02e701b2f58a`, plus this
uncommitted experiment directory.

## What you write

The reusable [counter](examples/counter.marko) is:

```marko
<let/count:=input.count>
<button onClick() { count++ }>
  Clicked ${count} times
</button>
<return:=count>
```

Give each counter an initial value and each owns its count:

```marko
<Counter count=0/>
<Counter count=0/>
```

Declare one count outside them and bind both to it to share:

```marko
<let/shared=0>
<Counter count:=shared/>
<Counter count:=shared/>
```

The [greeting form](examples/greeting-form.marko) uses the same rules. Its
[NameField](examples/name-field.marko) returns an editable value:

```marko
<NameField/name label="Name" value="Ada"/>
```

`name` is that field's value. Expressions read it; assignment changes it.
For the optional nickname, the parent owns the value and passes `value:=nickname`.
Hiding that field removes its editor, but the parent's nickname survives.
An uncontrolled counter placed inside an `if` instead starts over on remount.

## Run it

From the repository root, with Node/npm and the repository's Pixi environment:

```sh
npm ci --ignore-scripts --prefix experiments/tags-authoring
bash experiments/tags-authoring/check.sh
bash experiments/tags-authoring/native.sh
```

The last command builds and opens **Moxi Tags Experiment** on macOS. Edit the
`.marko` sources and rerun it after closing the existing window. There is no hot
reload. `native.sh --build-only` builds without opening a window.

The official Marko parser supplies the AST. `compile.cjs` lowers the supported
subset into ordinary Mojo components in ignored `generated/`; it also writes
control-ID/source manifests. The generated component handles ownership, event
routing, derived expressions, conditional mounting, and native editor state.
The application author supplies none of that machinery. Unsupported constructs
produce errors rather than falling back to a web view.

## Observed results

`check.sh` passed, exit 0. The captured output is in [results.txt](results.txt).

- All four example files compiled with the official Marko HTML and DOM
  translators: eight compilations, zero diagnostics. This verifies Marko syntax;
  it is not a browser/runtime equivalence test.
- Generated Mojo passed real `App` interaction checks for independent/shared
  counters, keyboard activation, fresh-root state, child returns, trimmed
  preview, disabled Save, immediate Save after edits, reset, conditional
  lifetime, and stale events targeting removed controls.
- Native editor state passed headless checks for focus/cursor continuity across
  rebuild, Unicode deletion, composition and committed text, Tab focus, and
  clipboard hooks. Clipboard hooks were checked directly; OS copy/cut/paste
  and an actual IME session were not exercised.
- Four source variations passed without compiler/runtime edits: add a validation
  rule once; change a shared counter to an independent one; put a counter inside
  a conditional; share text between two fields with separate editor cursors.
- Eleven unsupported-source cases were rejected with file/line/column errors.
- The macOS app built and opened. Native interaction verified typing and live
  preview, Save, an empty nickname disabling Save, nickname editing, persistence
  across hide/show, and Restore defaults. The final window was left at defaults.

**Unresolved native observation:** an accessibility-targeted click on the nickname
field did not move editing focus, so subsequent typing went to the primary field.
A pointer-coordinate click focused the nickname correctly. The cause was not
isolated between automation and Moxi accessibility/focus handling. This prevents
claiming complete native interaction/accessibility coverage.

Native builds emitted 14 existing `as_c_string_slice` deprecation warnings from
`src/moxi/native_window.mojo`. No production sources were edited to address them.

## What this does and does not establish

**High confidence:** these small declarative programs can run on Moxi with state
ownership and native editing hidden from application source. The generated
programs, interaction checks, and native window support this narrow conclusion.
A behavioral mismatch on the supported examples would weaken it.

**Comfort remains unmeasured.** The experiment preserves familiar Marko spelling
instead of proposing another vocabulary, but the author has not yet attempted
the change tasks. Successful unassisted changes would be stronger evidence than
our automated tests. A need to understand the generated Mojo would count against
this approach.

The compiler is deliberately limited: static sibling component imports; scalar
string/integer/boolean state; writable bindings/returns; pure expressions from a
small operator set and `trim()`; assignments/increments; `if`; labels, buttons,
text inputs, and checkboxes. Unbound child props must be literals. Layout is one
vertical column with fixed defaults; tags do not implement HTML/CSS semantics.
Expressions use Mojo scalar/string behavior, not a JavaScript runtime.

The form uses immediate validation. The planning sketch's touched-on-blur behavior
was not implemented because Moxi's ordinary component event surface lacks blur.
No keyed lists, async work, effects, dynamic components, reactive readonly props,
custom layout, source-mapped Mojo compiler diagnostics, or Mojo application-logic
interop were implemented. No language-compatibility claim follows from this subset.

Derived expressions are expanded at their uses, and successful events rebuild the
whole view. This does not use the earlier dependency-tracking probe and makes no
performance claim. The full repository suite, Linux/native cross-platform runs,
VoiceOver, native counter interaction, and browser behavioral parity were skipped.

The compiler and adapter absorb the complexity; they do not remove it from the
system. A larger language needs a credible plan for debugging, tooling, typed
application logic, and the unsupported cases before adoption.
