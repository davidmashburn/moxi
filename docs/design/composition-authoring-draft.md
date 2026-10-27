# Composition authoring draft

October 27, 2026. **Proposal for source review, not an implemented API.**
This follows the [child-routing experiment](child-routing-experiment.md),
inspected on `feat/data-workbench` at
`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`, with its uncommitted experiments.
The implementation checkout and unrelated edits are unchanged by this draft.

The question is whether a complete application makes sense before adding more
runtime machinery. Below are two complete proposed application files: independent
forms, then forms sharing only their name. They include the existing nickname,
validation, Save, Restore defaults, and native launch behavior. The three edit
exercises are assessed separately against the independent baseline.

`moxi.authoring`, `ScreenHost`, `InputScreen`, and `UI.child` below are proposed.
`Screen` and the control methods adapt the experimental handler API. None of the
two complete files has been compiled. The imports deliberately identify the
proposed boundary; these are not runnable examples of today's Moxi.

## Reading rule

A form owns its fields and methods. Its `render` describes controls; a control
calls its method when used. A parent places a persistent child under a local key.
When a value must be shared, its owner passes the current value down and receives
a requested replacement through a method. Event changes finish before views render.

The ownership difference is substantive: the proposed host owns the mounted
child instances. A parent no longer stores `first` and `second` as ordinary
fields. A shorter parent comes with a retained component tree and its lifetime
rules. This is a candidate tradeoff, not an adopted architecture decision.

## Complete application: independent forms

```mojo
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow
from moxi.authoring import Screen, ScreenHost, UI  # Proposed module.


struct GreetingForm(Screen):
    var name: String
    var nickname: String
    var use_nickname: Bool
    var saved: String
    var saves: Int

    def __init__(out self):
        self.name = "Ada"
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        self.saves = 0

    def selected(self) -> String:
        var source = self.name
        if self.use_nickname:
            source = self.nickname
        return String(source.strip())

    def set_name(mut self, text: String):
        self.name = text

    def set_nickname(mut self, text: String):
        self.nickname = text

    def set_use_nickname(mut self, checked: Bool):
        self.use_nickname = checked

    def save(mut self):
        self.saved = self.selected()
        self.saves += 1

    def restore(mut self):
        self.name = "Ada"
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""

    def render(self, mut ui: UI[Self]):
        ui.text_input("Name", self.name, Self.set_name)
        ui.checkbox("Use nickname", self.use_nickname, Self.set_use_nickname)
        if self.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.nickname, Self.set_nickname)
            ui.end_scope()
        var selected = self.selected()
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        ui.button("Save", Self.save, enabled=selected != "")
        ui.button("Restore defaults", Self.restore)
        if self.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.saved)
            ui.end_scope()


struct TwoForms(Screen):
    def __init__(out self):
        pass

    def render(self, mut ui: UI[Self]):
        ui.child[GreetingForm]("first")
        ui.child[GreetingForm]("second")


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Two independent forms", 520, 760))
    var size = window.size()
    var app = App[ScreenHost[TwoForms]](
        ScreenHost[TwoForms](TwoForms()),
        Rect(0, 0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
```

`child[GreetingForm]("first")` means “place the GreetingForm mounted here under
the key first.” Its constructor runs on mount, not on every render. Both forms
start with Ada, then evolve independently. Their nickname and saved controls may
use the same local scope names. Neither parent forwards individual handlers.

Explicit conditional scopes remain visible in this example. This draft does
not solve all control identity ergonomics by making child composition shorter.

## Edit 1: add a local Notes field

Make these five changes inside `GreetingForm`; no parent or host edits:

```mojo
# Field declaration:
var notes: String

# Constructor:
self.notes = ""

# New handler:
def set_notes(mut self, text: String):
    self.notes = text

# In render, after Restore defaults and before the saved scope:
ui.text_input("Notes", self.notes, Self.set_notes)

# In restore:
self.notes = ""
```

Notes are a local scratchpad; Save still saves the selected greeting. Each
instance gets its own Notes value. Saving notes too would be a separate domain
behavior change. Adding the field while editing source is not a promise to
migrate a running tree during hot reload.

## Edit 2: add a third independent form

Add one line to the parent render:

```mojo
ui.child[GreetingForm]("third")
```

The new key is local to this parent and must be unique among its children.
There is no numeric ID, offset, field forwarding, clipboard forwarding, or
refresh call. A real application may also need scrolling or more window space;
the composition edit alone does not guarantee all three forms fit onscreen.

## Edit 3: share the name, keep the rest local

The parent now owns `name`. The form receives it as an argument; it no longer
has its own mutable name field. The separate type name makes the ownership
change explicit in this comparison. An application could replace its original
form type instead of keeping both versions.

This candidate uses `InputScreen`, with associated `Input` and `Output` types.
All of its handlers receive the current input after `self`; control event data
comes next. Returning `Output` requests a parent change. Returning nothing means
only local work. The parent chooses what to commit. This uniform convention
avoids per-control binding objects and captured parent references, but it adds
signature noise even to handlers that do not use the input.

```mojo
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow
from moxi.authoring import InputScreen, Screen, ScreenHost, UI  # Proposed.


struct SharedGreetingForm(InputScreen):
    comptime Input = String
    comptime Output = String

    var nickname: String
    var use_nickname: Bool
    var saved: String
    var saves: Int

    def __init__(out self):
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        self.saves = 0

    def selected(self, name: String) -> String:
        var source = name
        if self.use_nickname:
            source = self.nickname
        return String(source.strip())

    def set_name(mut self, name: String, text: String) -> String:
        return text

    def set_nickname(mut self, name: String, text: String):
        self.nickname = text

    def set_use_nickname(mut self, name: String, checked: Bool):
        self.use_nickname = checked

    def save(mut self, name: String):
        self.saved = self.selected(name)
        self.saves += 1

    def restore(mut self, name: String) -> String:
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        return "Ada"

    def render(self, name: String, mut ui: UI[Self]):
        ui.text_input("Name", name, Self.set_name)
        ui.checkbox("Use nickname", self.use_nickname, Self.set_use_nickname)
        if self.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.nickname, Self.set_nickname)
            ui.end_scope()
        var selected = self.selected(name)
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        ui.button("Save", Self.save, enabled=selected != "")
        ui.button("Restore defaults", Self.restore)
        if self.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.saved)
            ui.end_scope()


struct SharedForms(Screen):
    var name: String

    def __init__(out self):
        self.name = "Ada"

    def rename(mut self, text: String):
        self.name = text

    def render(self, mut ui: UI[Self]):
        ui.child[SharedGreetingForm]("first", self.name, Self.rename)
        ui.child[SharedGreetingForm]("second", self.name, Self.rename)


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Forms with a shared name", 520, 760))
    var size = window.size()
    var app = App[ScreenHost[SharedForms]](
        ScreenHost[SharedForms](SharedForms()),
        Rect(0, 0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
```

The name change crosses exactly one ownership boundary. No request flags or
refresh sequence appear in the application. The name argument is a value
snapshot, not a retained mutable borrow. The runtime must give Save the latest
settled input, including after the sibling edits the name.

Restore on the first form requests the shared name Ada and resets only the first
form's nickname, toggle, and saved message. The second form sees Ada but keeps
its other fields, including any previously saved greeting. That behavior is a
consequence of sharing only name. An “entire application reset” would belong to
the parent and is not implemented by this button. Save records a snapshot and
increments only the local save count; it does not write a file or call a service.

This third edit is bigger than adding a child: remove the name field and its
initialization, add the input/output declarations, change the helper/render
signatures and all five handler signatures, replace the name assignment and
reset with returned values, and add the parent field, initializer, handler and
two connections. It is a source-level ownership refactor, not a one-line binding.

## What the framework would have to guarantee

These obligations are part of evaluating the proposal. Moving them out of
application code does not establish that they are cheap or already implemented.

1. **Persistent children.** The identity is parent instance plus child key and
   type. Reordering declarations retains the instance. Duplicate keys are an
   error. Removal destroys the mounted subtree; a later mount starts fresh.
   A type change under an existing key is an error until that child is removed.
   Native IDs need collision-free allocation and instance generations, rather
   than the experiment's fixed numeric offsets. Stale events must be rejected.
2. **Current-instance dispatch.** Keep method identities and tree routes, not
   borrowed references to mutable parents. Dispatch receives the current child
   state and current input. A child output calls the registered current-parent
   method exactly once, including when the output is an empty string. Local
   methods returning nothing must not accidentally produce an output.
3. **One event transaction.** For a name edit: update the editor, call the child
   handler, pass its output to the parent, commit the parent's state, evaluate
   the parent's child declarations with the new inputs, then render affected
   children. Never restore the origin editor from its old name between those
   steps. The parent renders too; this is not “one render for the entire app.”
   Cursor-only events render the affected child without invoking rename. Copy,
   cut, paste and composition use the same boundary.
4. **Pure description.** Render does not call user event handlers, produce
   change outputs, or perform Save. If an output changes an ancestor, settle
   that upward path before rendering downward. Rendering itself must not emit
   another output. Bounds, resize, paint and input comparison need explicit
   invalidation rules; the prototype's cached-view limitation is not a solution.
5. **Visible ownership.** Copying `SharedForms` alone copies its name, not its
   mounted children's local fields. A whole-application snapshot or deep copy
   must include the host's tree. Tests need a supported way to inspect child
   state. Remounts, persistence, restoration and external model mutation cannot
   silently inherit the old root-value semantics. Those APIs remain undecided.

The conservative first implementation could render both shared children after
a parent output; equal-input caching is an optimization, not a prerequisite for
this source. One render per affected child is a target inherited from the
previous experiment, not a measured result for this proposal. The tree registry,
view composition, layout, reconciliation, input copies, allocations and routing
still cost work. No performance claim follows from fewer author-written lines.

## Language and architecture check

The draft uses ordinary methods, values and type declarations. Mojo 1.1.0
documents associated types as `comptime` members of traits and conforming
structs ([trait declarations](https://mojolang.static.modular.com/1.1.0/docs/reference/trait-declarations/)).
That supports the spelling of Input and Output; it does not validate this
particular UI protocol or its compiler diagnostics. Generic trait syntax,
automatic field accessors and escaping closures are not assumed here.

An implementation would still need a compile-only feasibility check for the
two render contracts, heterogeneous child storage, dispatch of local versus
output-returning methods, and safe instance lifetime. `Screen` and `InputScreen`
describe two component interfaces, not two scheduling modes. Both require the
same event boundary. Hiding a manual settlement adapter in application code
would fail this proposal's acceptance bar.

The model retains the earlier Xilem-inspired split between event mutation and
view description, plus tree-based identity and routing. Runtime-owned child
application state is an additional Moxi ownership choice; the child-routing
experiment instead stored that state in ordinary parent fields. It would be
misleading to call this change mere syntactic sugar over the existing example
or claim that Xilem requires it. No Xilem implementation was changed or tested.

## Assessment and stop condition

| Edit | Application work visible in this draft | Assessment |
| --- | --- | --- |
| Add a local field | Field, initialization, local handler, control declaration, reset behavior | Meets the locality bar on paper; ordinary Mojo still has boilerplate. |
| Add a form | One child declaration with a parent-local key | Meets the source-composition bar on paper; mounted lifetime is a new contract. |
| Share one value | Move ownership to parent; use an input/output component contract; connect both children | Removes manual routing and refresh ordering, but adds substantial signature changes. Comfort is unresolved. |

**Recommendation: keep this as a reviewable candidate; do not adopt or build the
general mounted-tree runtime yet.** The independent case is much clearer than
the slot wiring. The shared case is explicit but still carries a second
component interface, associated types, output-return rules and unused input
arguments. That is enough remaining cost that this draft does not establish
the requested universal ease or Marko Tags API comfort.

High confidence that the written independent example removes per-field parent
wiring; moderate confidence in the proposed dispatch/settlement contract based
on the preceding executable experiment; low confidence in the shared form's
authoring comfort and in the uncompiled protocol's implementation cost.

The next evidence should be a source-reading/edit exercise with these complete
files: explain who owns each field, predict Restore and Save after a sibling
edit, add Notes, add a third instance, and share name without instructions about
routing or refresh. The user's judgment on that source is necessary evidence
for this conversation's comfort goal; authored examples cannot stand in for it.
If the shared form still needs repeated explanation, stop this candidate before
writing a runtime. If the source is acceptable, the next bounded experiment is
to compile this exact interface and verify mount/reorder/remount, current-input
Save, shared Restore, clipboard, cursor preservation and one-event settlement.
Do not start another broad architecture survey or quietly simplify the workload
to two bare name editors.

## Verification of this record

Reviewed both source listings against the existing full GreetingForm and the
settled shared-name experiment. Checked the three edit locations, state owners,
shared reset/save semantics, Markdown links, whitespace and planning diff.
The earlier child-routing executable results are inherited evidence only.
No proposed source compilation, new runtime execution, native launch, automated
UI test, benchmark, full repository suite, independent usability study or
cross-platform check was performed for this draft. No product code or
dependencies were changed, and no content was pushed.
