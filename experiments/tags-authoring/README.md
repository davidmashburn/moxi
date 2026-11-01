# Tags authoring experiment

A small subset of real Marko syntax now drives native Moxi controls. The counter
and greeting form compile to ordinary `Screen` models, methods, and `UI` calls
from the production [`moxi.authoring` API](../../docs/authoring/README.md).
`HandlerHost` owns event routing, native editor state, and control lifetimes.

This is an executable feasibility experiment, not a complete Marko backend or
an adopted Moxi language. The production-target migration was checked on
November 1, 2026. The supported Marko syntax and example sources are unchanged.

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
subset into ordinary Mojo models in ignored `generated/`; it also writes
source-key/location manifests. Source keys identify declaration sites, not native
control IDs. They are stable within a compiled program, not across source edits
or hot reload. Unsupported constructs produce errors rather than a fallback.

## What the new target looks like

A simplified single-counter equivalent is ordinary Mojo:

```mojo
from moxi.authoring import Screen, UI

struct Counter(Screen):
    var count: Int

    def __init__(out self):
        self.count = 0

    def increment(mut self):
        self.count += 1

    def render(self, mut ui: UI[Self]):
        ui.button("Clicked " + String(self.count) + " times", Self.increment)
```

The actual generator additionally wraps each source site in a stable `begin_scope`
/ `end_scope` pair. Conditional siblings can disappear without changing the
identity of their neighbors. A removed and remounted control gets a fresh host ID,
so delayed events cannot target its replacement. Start the generated form with
`App(HandlerHost(GreetingForm()), bounds)`; [demo.mojo](demo.mojo) runs it natively.

| Concern | Translator responsibility | Production runtime responsibility |
| --- | --- | --- |
| Values and bindings | Ordinary fields; shared bindings refer to the same field | Route handlers to the current owner |
| Changes | Methods assign values and settle conditional model state | Dispatch input and refresh declarations |
| Conditional local values | Initialize them on a new conditional mount | Retire removed controls and their editor state |
| Editing and clipboard | Declare a text value and change handler | Selection, composition, focus, clipboard hooks |
| Root replacement | Construct a fresh generated model | `reset` / `reset_headless` reject the previous owner's work |

The generated `settle` method only initializes model values on conditional mounts.
`render` reads the resulting state. The form's **Restore defaults** button changes
values; it does not replace the root lifetime. A real session replacement uses the
production reset API. Reusable Marko components are still flattened into root
fields: this experiment does not test reusable `Pane` composition or context routing.

Marko can supply a separate visible label and `aria-label`. The migration adds
`show_label=False` to production text inputs and checkboxes to preserve the
accessible name without duplicating visible text. Existing API defaults remain
visible. No private editor/event/clipboard adapter remains in this experiment.

## Observed results

On November 1, `check.sh` passed. Output is in [results.txt](results.txt).

- All four examples pass the official Marko HTML and DOM translators: eight
  compilations, zero diagnostics. This verifies syntax, not browser equivalence.
- Real `App` routing preserves independent/shared counters, keyboard activation,
  child returns, derived validation, immediate Save, conditional local reset,
  parent state across hiding, selection, Unicode, simulated composition, clipboard
  hooks, and Tab focus.
- Added checks reject an old editor ID after remount, a captured button action
  after remount, and an action captured before production root reset.
- Four source variations still pass. A static model without fields also compiles
  and runs. Twelve unsupported cases fail with source locations, including empty
  handlers (already unsupported before this migration).
- Separate production tests verify accessible names with visible labels suppressed
  through both child-routing overloads. The generated form also checks its names
  and unchanged visible node count.
- The migrated macOS app builds. This run did not open it or repeat physical input,
  OS clipboard, VoiceOver, or a real IME session. Existing native-window
  `as_c_string_slice` deprecation warnings remain.

| Maintained/generated code | Previous target | Production target |
| --- | ---: | ---: |
| Generated counters | 55 lines | 38 lines |
| Generated greeting form | 121 lines | 75 lines |
| Private runtime adapter | 43 lines | 0 lines |
| Compiler | 292 lines | 268 lines |

The generated examples are 36% shorter (176 to 113 lines). These counts include
blank/comment lines and are a maintenance indicator, not a usability or speed
measurement. The host already exists; these reductions do not mean the underlying
editing machinery disappeared from Moxi.

Historical native interaction on October 27 verified typing, preview, validation,
Save and hide/show. An accessibility-targeted click failed to move focus while a
coordinate click worked; the cause was not isolated. That observation has not been
retested here, so complete native accessibility coverage remains unclaimed.

## What this does and does not establish

**High confidence:** these small declarative programs can run on Moxi with state
ownership and native editing hidden from application source. The generated
programs and interaction checks support this narrow conclusion.
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

**Moderate confidence: keep this as a compatibility probe and teaching example.**
It removes duplicated runtime behavior and makes the translation to ordinary Mojo
inspectable. That is real value without adopting another application language.
Repeated pressure for translator-only runtime hooks, difficult generated-code
debugging, or unsupported constructs dominating real applications would weaken
that recommendation. A larger language still needs a credible plan for tooling,
typed application logic, and the unsupported cases before adoption.
