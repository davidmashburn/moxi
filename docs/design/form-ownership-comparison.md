# Three complete form ownership designs

October 27–28, 2026. **Source comparison, not adopted API or runnable UI.**
Follow-up to the [UI pattern inventory](ui-pattern-inventory.md) and the
[composition draft](composition-authoring-draft.md). Implementation inspected:
`feat/data-workbench` at `c8c7cbb7741519c9796a02ffa25c02e701b2f58a`, including
existing uncommitted handler, child-routing and scoped-binding experiments.

## Finding

The observed shared-property variant has the smallest change from independent
to shared forms in these examples. Its rule is understandable: give both forms
the same cell; give them different cells for independence. That is a provisional
source-reading judgment, **not evidence of user comfort or a working Moxi API**.
It charges a real cost: a special shared value with read/write operations,
tracking, notification and lifetime rules.

Current-state projection remains a useful foundation. It gives handlers current
ordinary state and fits the Xilem direction. Projecting a whole form is simple;
projecting one shared field alongside private form state needs more machinery.
The split projection below is visibly close to the extra-input convention the
user disliked in the preceding draft. We should not call it a comfort solution.

Controlled values keep ownership and parent validation explicit, but they still
require value/change wiring and a defined refresh boundary. They are a useful
escape hatch, not the leading comfort candidate here.

These are **ownership variants on a common retained-view architecture**, not
three mutually exclusive rendering engines. The observed candidate also uses
current-state projection for its form-local actions. No candidate requires
continuous rendering, side effects in render, or a new source language. All
three require library/runtime support beyond today's experimental handler API.

## Fixed behavior and comparison rules

Two forms start at Ada and share only Name. Each owns its nickname, nickname
choice, saved greeting and successful Save count. The nickname control appears
only while selected; its data survives hiding. Preview trims the selected name.
Empty selection disables Save; the handler also checks it. Save records a
snapshot and increments only that form's count. Restore resets Name to Ada and
clears that form's nickname, choice and saved result, preserving its Save count.
Restoring either form consequently changes the other's Name, but not its local
fields or previously saved snapshot. This shared reset is intentional.

All designs keep form data in the application model; none hides business state
in a mounted-child registry. Widget focus, cursor and composition belong to the
retained UI. Keys identify UI instances, not owners of application data. The
examples use the same conditional scopes as the working handler experiment.
They do not claim to have eliminated every identity annotation.

Below, **common.mojo + one candidate module + main.mojo** form each complete
application specification. The form behavior and application assembly are shown in full.
The `proposed` import deliberately prevents these from being mistaken for
runnable examples. Native launch uses existing Moxi types, but `Host` and the
child APIs do not exist. Full modules have not been compiled.

## Shared ordinary domain data

```mojo
# common.mojo — ordinary domain data; no UI state or observation.
struct Details(ImplicitlyCopyable):
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

    def save(mut self, name: String):
        var selected = self.selected(name)
        if selected != "":
            self.saved = selected
            self.saves += 1

    def restore(mut self):
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        # Preserve the count of successful Save actions.
```

## What the proposed helpers actually owe us

| Helper | Contract; this is work, not a short spelling of an existing feature |
| --- | --- |
| `Host`, `ProjectionUI.project` | Retain widgets under a child key; build from the supplied read-only snapshot. At dispatch, find the current child through the stored projector and invoke its handler. Store no borrowed application-state pointer across renders. Local mutations invalidate that form. Route clipboard, focus and accessibility as well as clicks. |
| `project_pair`, `SplitUI` | In addition, supply current mutable form state and current mutable Name to an action. They must be disjoint and short-lived borrows. Concrete field-specific projectors passed a direct-call compiler probe. A generic stored two-projector API still needs to preserve those origins and enforce non-aliasing. Refresh all consumers after the action settles. |
| `Cell[String]` | Copies share one value identity. `get()` reads the current value and records a dependency only during a tracked render. `set()` changes the value immediately and schedules subscribers after the event. No synchronous render halfway through Restore. Dropped views unsubscribe; last handle releases the value. This is a proposed shared-property implementation, not automatic observation of arbitrary Mojo assignments. |
| `Change[String]`, `controlled`, `button_with` | Bind a callback to the current root route without retaining a borrowed root reference. Queue the requested parent edit until the child mutable borrow is released; never reenter the root through that borrow. Retain explicit payload values for button handlers. Finish queued parent callbacks and refresh affected props/handlers before accepting the next user event. A discarded child's callback cannot revive it. |

`UI`'s named form methods and conditional scope vocabulary come from the
existing handler experiment. Its actual stored callbacks are thin functions;
it does **not** already support these projectors, arbitrary bound payloads,
`Cell`, or root-bound `Change` objects. The observed design has two invalidation
sources: local handler completion and shared-cell changes. The host must coalesce
them. Neither that combination nor its cleanup is demonstrated by these sources.

## A — current-state projection

The easy, whole-model case would own `first: Greeting` and `second: Greeting`,
where each Greeting includes its own ordinary `name: String`, and project each
whole Greeting. The child uses normal methods such as `save(mut self)`.

Sharing only Name breaks that contiguous submodel. Below is the complete shared
version, with an explicit **split-projection proposal**. Every handler now gets
Name, including handlers that ignore it. A plain single-field lens does not
provide this combined view by itself. Alternatives include a borrowed composite,
a more general adapter, normalized IDs, or a shared handle; each adds its own
contract. Copying names into both children and synchronizing them is not an
acceptable substitute for one owner.

```mojo
# projection.mojo — SOURCE SPECIFICATION; proposed UI module.
from common import Details
from proposed import SplitUI, ProjectionUI

struct Form(ImplicitlyCopyable):
    var details: Details

    def __init__(out self):
        self.details = Details()

    # The host supplies BOTH current state locations on each event.
    def rename(mut self, mut name: String, text: String):
        name = text

    def nickname(mut self, mut name: String, text: String):
        self.details.nickname = text

    def toggle(mut self, mut name: String, checked: Bool):
        self.details.use_nickname = checked

    def save(mut self, mut name: String):
        self.details.save(name)

    def restore(mut self, mut name: String):
        name = "Ada"
        self.details.restore()

    def render(self, name: String, mut ui: SplitUI[Self, String]):
        ui.text_input("Name", name, Self.rename)
        ui.checkbox("Use nickname", self.details.use_nickname, Self.toggle)
        if self.details.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.details.nickname, Self.nickname)
            ui.end_scope()
        var selected = self.details.selected(name)
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        ui.button("Save", Self.save, enabled=selected != "")
        ui.button("Restore defaults", Self.restore)
        if self.details.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.details.saved)
            ui.end_scope()

struct Model(ImplicitlyCopyable):
    var name: String
    var first: Form
    var second: Form

    def __init__(out self):
        self.name = "Ada"
        self.first = Form()
        self.second = Form()

    def first_form(mut self) -> ref[self.first] Form:
        return self.first

    def second_form(mut self) -> ref[self.second] Form:
        return self.second

    def shared_name(mut self) -> ref[self.name] String:
        return self.name

    def render(self, mut ui: ProjectionUI[Self]):
        ui.project_pair("first", self.first, self.name,
                        Self.first_form, Self.shared_name)
        ui.project_pair("second", self.second, self.name,
                        Self.second_form, Self.shared_name)
```

## B — shared observed property

Only Name is a `Cell`; other data stays ordinary because event handlers already
identify the form to refresh. This is intentionally a hybrid of current-state
callbacks and one observed shared property. A fully observed model would require
more wrappers/read-write operations or additional language facilities.

The domain Save reads `get()` at event time; it does not reuse the string read
by render. Both forms receive a handle to the same cell at initialization.
Rendering may read through that handle but must not call `set()`.

```mojo
# observed.mojo — SOURCE SPECIFICATION; Cell and UI are proposed.
from common import Details
from proposed import Cell, UI, ProjectionUI

struct Form(ImplicitlyCopyable):
    var name: Cell[String]
    var details: Details

    def __init__(out self, name: Cell[String]):
        self.name = name       # Copies a handle to the SAME cell.
        self.details = Details()

    def rename(mut self, text: String):
        self.name.set(text)

    def nickname(mut self, text: String):
        self.details.nickname = text

    def toggle(mut self, checked: Bool):
        self.details.use_nickname = checked

    def save(mut self):
        self.details.save(self.name.get())

    def restore(mut self):
        self.name.set("Ada")
        self.details.restore()

    def render(self, mut ui: UI[Self]):
        var name = self.name.get()
        ui.text_input("Name", name, Self.rename)
        ui.checkbox("Use nickname", self.details.use_nickname, Self.toggle)
        if self.details.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.details.nickname, Self.nickname)
            ui.end_scope()
        var selected = self.details.selected(name)
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        ui.button("Save", Self.save, enabled=selected != "")
        ui.button("Restore defaults", Self.restore)
        if self.details.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.details.saved)
            ui.end_scope()

struct Model(ImplicitlyCopyable):
    var first: Form
    var second: Form

    def __init__(out self):
        var name = Cell[String]("Ada")
        self.first = Form(name)
        self.second = Form(name)

    def first_form(mut self) -> ref[self.first] Form:
        return self.first

    def second_form(mut self) -> ref[self.second] Form:
        return self.second

    def render(self, mut ui: ProjectionUI[Self]):
        ui.project("first", self.first, Self.first_form)
        ui.project("second", self.second, Self.second_form)
```

## C — controlled value plus callback

Name is an ordinary parent field. The child receives its current rendered
value and a callback requesting a replacement. Local-only handlers remain
ordinary methods; there is no input/output associated-type protocol.

The price is now visible at the exact controls that need it: Name forwards the
change callback; Restore retains that callback; Save retains the rendered Name.
`button_with` is an explicit stored-argument proposal, not a supported Mojo
closure trick. Replacing those arguments with live getters would change this
candidate into a binding/current-state-access design.

```mojo
# controlled.mojo — SOURCE SPECIFICATION; UI/Change are proposed.
from common import Details
from proposed import Change, UI, ProjectionUI

struct Form(ImplicitlyCopyable):
    var details: Details

    def __init__(out self):
        self.details = Details()

    def nickname(mut self, text: String):
        self.details.nickname = text

    def toggle(mut self, checked: Bool):
        self.details.use_nickname = checked

    def save(mut self, name: String):
        self.details.save(name)

    def restore(mut self, on_name: Change[String]):
        on_name("Ada")
        self.details.restore()

    def render(self, name: String, on_name: Change[String], mut ui: UI[Self]):
        ui.text_input("Name", name, on_name)
        ui.checkbox("Use nickname", self.details.use_nickname, Self.toggle)
        if self.details.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.details.nickname, Self.nickname)
            ui.end_scope()
        var selected = self.details.selected(name)
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        # These extra arguments are retained VALUES from this render.
        ui.button_with("Save", Self.save, name, enabled=selected != "")
        ui.button_with("Restore defaults", Self.restore, on_name)
        if self.details.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.details.saved)
            ui.end_scope()

struct Model(ImplicitlyCopyable):
    var name: String
    var first: Form
    var second: Form

    def __init__(out self):
        self.name = "Ada"
        self.first = Form()
        self.second = Form()

    def rename(mut self, text: String):
        self.name = text

    def first_form(mut self) -> ref[self.first] Form:
        return self.first

    def second_form(mut self) -> ref[self.second] Form:
        return self.second

    def render(self, mut ui: ProjectionUI[Self]):
        ui.controlled("first", self.first, Self.first_form,
                      self.name, Self.rename)
        ui.controlled("second", self.second, Self.second_form,
                      self.name, Self.rename)
```

## Shared native assembly

```mojo
# main.mojo — choose ONE candidate module above.
from observed import Model  # Or: projection / controlled.
from proposed import Host
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow

def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Two greeting forms", 520, 760))
    var size = window.size()
    var app = App[Host[Model]](
        Host[Model](Model()), Rect(0, 0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
```

## Edit exercises

These are edits to the written specifications, not measured human task times.
No line-count score is used: a one-line helper with a new ownership contract is
not automatically easier than several ordinary assignments.

| Exercise | Current-state projection | Shared observed property | Controlled value + callback |
| --- | --- | --- | --- |
| Add local Notes, cleared by Restore | Five locations: Details field, constructor, restore; Form handler and input. Split handler still receives unused Name. | Same five locations. Notes need not be a Cell; local handler invalidation covers it. | Same five locations; no parent wiring for local Notes. |
| Add a third shared form | Model field, initialization, projector, placement. Reuse shared Name projector. | Model field, initialization using the same cell, projector, placement. | Model field, initialization, projector, placement. Reuse Name value/change. |
| Start with two independent forms | Prefer two whole Greeting submodels, each including Name. No split projection is needed. | Construct each Form with its own `Cell[String]("Ada")`. Same Form type. | Parent owns two Name strings and two setter methods; each child gets the matching pair. Same Form type. |
| Change independent forms to share only Name | Split the data model; adapt render and action signatures; replace whole projection with paired projection. An already-split design reduces the edit but pays this complexity from the start. | Change construction to pass the same cell. Form handlers and layout stay the same. | Replace two parent Name fields/setters with one; update both prop/callback pairs. Form handlers and layout stay the same. |
| Parent rejects or normalizes an edit | Add policy to the projected editing operation; direct mutable access otherwise permits bypassing parent policy. | A freely writable Cell permits bypass. A validated cell or read-only handle + command adds a new contract. | Natural: parent callback decides whether/what to commit; child refresh reflects accepted value. |
| Explain Save | Read current projected Name and local details. | Read current cell value and local details. | Read Name supplied by the latest committed render and current local details. |

The observed initialization difference, in full:

```mojo
# Independent:
self.first = Form(Cell[String]("Ada"))
self.second = Form(Cell[String]("Ada"))

# Shared:
var name = Cell[String]("Ada")
self.first = Form(name)
self.second = Form(name)
```

That is the clearest result of this comparison. It is also the exact point where
ordinary value semantics change: `Form(name)` must copy a shared handle, while
`Form(Cell[String]("Ada"))` creates a different identity. A cell must be created
in model initialization, not on every render. Naming it differently does not
remove the need to teach these facts. Copying the whole model would also copy
shared handles: it would not produce an independent undo snapshot of Name.
Undo or serialization must snapshot values deliberately. This is another cost
of the observed design, especially for Moxi's data-workbench use cases.

## Event-order trace: edit left, then Save right

Start with Name Ada, both nickname choices off, right Save count 0.
Left commits Grace. Before accepting another normal user event, every proposed
host finishes the state change and refreshes affected UI. Right Save then
records Grace and increments its count to 1 in **all three** designs.

To expose the difference, invoke the right domain Save handler *after the Name
commit but before refreshing its rendered props*:

| Candidate | Input to that deliberately early handler | Predicted saved result |
| --- | --- | --- |
| Current-state projection | Resolve shared Name at event dispatch | Grace |
| Shared observed property | Read the existing cell at event dispatch | Grace |
| Controlled value + callback | Use the Name payload retained from the Ada render | Ada |

The last row is a counterexample to an unspecified scheduler, not a claim that
controlled components inevitably mishandle sequential user input. The required
refresh boundary makes the normal interaction correct. Switching to a live
getter would also fix this payload case, while adding a different access contract.

Current-value access alone does not make stale UI safe: the button's enabled
state, the preview, hit targets and editor selection still need refreshing.
For example, Name changing from empty to nonempty must enable Save before a
normal click can activate it. No design gets permission to ignore settlement.
The earlier [child-routing experiment](child-routing-experiment.md) observed
cursor clamping when a controlled editor refreshed before its parent committed.
That evidence is inherited; this comparison has not rerun its native test.

Restore in the observed design is another explicit ordering requirement:
`name.set("Ada")` must not immediately render the origin before
`details.restore()` finishes. Both invalidations are coalesced after the action.
This is runtime scheduling, even though the author-facing method reads simply.

## Identity and lifetime exercises

The same policy applies to all three specifications:

- Reorder the two placement calls while retaining keys `first` and `second`:
  data remains with the same model; retained editor identity must follow its key.
- Stop placing `first` while retaining `Model.first`: its UI is unmounted, but
  its application data remains. The observed variant removes that view's
  subscription; the cell stays alive through its surviving model handles.
- Place `first` again later: show its preserved data, but create fresh widget
  interaction state. A key does not promise to resurrect destroyed focus,
  selection or composition. This differs from merely hiding a live widget.
- Actually delete the form model as well: that form's local data is lost.
  Recreating it initializes local data. With a still-existing shared Name owner
  or handle it sees the current Name; creating a new cell resets Name too.
- A removed view's stale queued event must be rejected by mount generation or
  equivalent liveness checking. Reusing its spelling of a key does not authorize
  an old callback to act on a new mount.

The examples have two fixed model fields; deletion here is a contract exercise,
not a demonstrated dynamic-list implementation. Dynamic collections would need
stable item IDs, lookup failure handling and a new mounting generation. This
work is not avoided by choosing a cell or a lens. The native lifecycle behavior
above remains untested for the proposed hosts.

## Relationship to Xilem and Marko

Xilem's current API presents lightweight views backed by retained widgets,
callbacks with current application state, and a lens adapter for a field of
that state. This supports the projection foundation; it does not establish our
paired projection, observed-cell integration or Mojo generic ergonomics.
([Xilem 0.4.0](https://docs.rs/xilem/latest/xilem/).)
Raph's architecture essay also explicitly discusses earlier lens complexity;
this is a known design pressure, not an unexpected flaw in ordinary state.
([Xilem architecture](https://raphlinus.github.io/rust/gui/2022/05/07/ui-architecture.html).)

Adding a shared observed value is compatible with retaining widgets and
routing actions to current state. It changes invalidation and sharing policy;
we would have to make dependency registration and lifetime explicit inside
Moxi. Compatibility here is an architectural inference, not proof that Xilem
or Moxi ships this particular combination.

Marko's comfort advantage includes a consistent controllable-value convention
and binding shorthand: `<input value:=name>` connects value and changes. A
reusable custom component still needs the corresponding controllable contract.
Our `Cell.get()/set()` can give a consistent library rule, but the examples do
not reproduce tag-local declarations, binding shorthand or compiler-established
reactive relationships. Ordinary Mojo is preserved by accepting library concepts,
not by making those concepts vanish.
([Marko controllable components](https://markojs.com/docs/explanation/controllable-components).)

## Decision boundary

**Provisional preference: shared observed properties for sharing, current-state
projection for local handlers.** Moderate confidence in this source-level
preference; low confidence that it meets the user's comfort requirement.
This is a refinement of the Xilem direction, not a choice to replace it.

Do not implement `project_pair`, `Cell`, `Change` and three new hosts in parallel.
Do not adopt the mounted-child ownership proposal merely to remove parent fields.
The comparison has identified a smaller question: is the explicit shared-cell
rule acceptable when read in a complete form? If it is still uncomfortable,
there is no evidence that another runtime experiment will solve that discomfort.

If accepted as a source shape, the next implementation gate is a **single**
bounded observed-Name prototype on the existing handler experiment: two forms,
current-value Save, one settled refresh per affected form, unchanged cursor on
the originating editor, unsubscribe on unmount, and stale-event rejection on
remount. Prove handle ownership and mutation safety first. No parser, automatic
observation of arbitrary fields, general binding DSL, new public package or
whole-framework rewrite. Keep the explicit controlled path available for parent
validation. This is a proposed next gate, not implemented work in this comparison.

Evidence that would change the preference: the user still finds the full cell
example confusing; a safe cell requires substantial caller-side ownership code;
or projection can express split ownership with fewer teachable rules and no
unproven borrowing. Performance cannot select among these sources yet: no
three-way runtime or allocation comparison exists. All three refresh policies
could be coarser or finer than this form needs.

## Mojo feasibility evidence

Fresh checks used the locked environment's **Mojo 1.1.0 (8189361e)**. The
manifest permits `mojo >=1.1.0,<2`; the observed compiler version is the tested
baseline, not a claim about all allowed versions.

| Mechanic | Evidence from this comparison | What remains unproved |
| --- | --- | --- |
| Stored current-state read | A stored thin function received the parent at call time and read `parent changed`, written after its construction. Parent independently reran the probe. | Generic nested routing, mutable projected return from a stored function and host integration. |
| Concrete mutable field projection | Parent probe returned `ref[self.value] String`; mutation through the result changed the parent's value to Grace. | A reusable type-erased/generic lens with equally simple caller syntax. |
| Two disjoint current-state projections | Parent probe below passed both field-specific returned references into one Save action; it printed Grace. | A generic `project_pair` registry, alias rejection through that registry and dynamic lookup/lifetime handling. |
| Shared storage | Copies of `ArcPointer[State]` saw each other's writes, including a handle stored inside another struct. Parent independently reran it. Existing `tests/frame_packet.mojo` also uses shared traces. | A safe observed Cell implementation, subscriptions, cleanup, transactions, thread behavior and UI invalidation. |
| Plain-field reactivity | Existing handler code refreshes after dispatch; the scoped-binding probe explicitly records reads and invalidates scopes. | No automatic observation of arbitrary assignments was established. |

A worker completed probe files and a report but its final delivery encountered a
transport error. The parent inspected the files, reran the consequential positive
checks and added the two successful mutable-projection probes. The worker's
initial rejected parent-origin syntax is **not** the final feasibility result:
using the field's derived origin succeeds in these concrete cases. Failure of
one spelling does not establish that Mojo cannot express a lens.

This complete standalone probe was compiled and run with
`pixi run --locked mojo run /tmp/moxi-form-comparison/pair_ref.mojo` from the
implementation checkout (save this code under any equivalent temporary filename):

```mojo
struct Details(ImplicitlyCopyable):
    var saved: String
    def __init__(out self):
        self.saved = ""

struct Parent(ImplicitlyCopyable):
    var name: String
    var form: Details
    def __init__(out self):
        self.name = "Ada"
        self.form = Details()
    def get_name(mut self) -> ref[self.name] String:
        return self.name
    def get_form(mut self) -> ref[self.form] Details:
        return self.form

def save(mut form: Details, mut name: String):
    form.saved = name

def main():
    var parent = Parent()
    parent.name = "Grace"
    save(parent.get_form(), parent.get_name())
    print(parent.form.saved)  # Observed: Grace
```

The smaller shared-storage probe used this shape, also compiled and run:

```mojo
from std.memory import ArcPointer

struct State(ImplicitlyCopyable):
    var text: String
    var writes: Int
    def __init__(out self):
        self.text = "before"
        self.writes = 0

struct Reader(ImplicitlyCopyable):
    var state: ArcPointer[State]
    def __init__(out self, state: ArcPointer[State]):
        self.state = state
    def observe(self) -> String:
        return self.state[].text
    def write(mut self, value: String):
        self.state[].text = value
        self.state[].writes += 1

def main():
    var owner = ArcPointer(State())
    var copy = owner
    var reader = Reader(owner)
    copy[].text = "parent changed"
    print("copy sees:", reader.observe())  # parent changed
    reader.write("event write")
    print("owner sees:", owner[].text)     # event write
    print("write counter:", copy[].writes) # 1
```

This storage probe is not a proposed public Cell implementation. Reference
counting alone establishes neither reactive dependencies nor an acceptable
mutation/aliasing/thread contract for an exposed property API. The prototype
would have to restrict and document those operations rather than expose its
storage pointer to callers.

## Verification and limits

New work: reviewed the existing handler, scoped-read and child-routing source;
verified the compiler version and the positive mechanics listed above; wrote
three complete application source specifications; walked through local-field,
third-instance, sharing, Save/Restore and removal/reorder/remount edits; checked
planning links, code-block consistency and staged content. The companion
[interactive comparison](form-ownership-comparison.html) presents the same
sources and explicitly labels its event trace as a prediction.

The HTML was previewed at desktop and phone widths, including expanded source
and dark-theme checks; its two event-sequence controls and source section count
were checked. This validates presentation, not a Moxi scheduler.

Not run: full proposed application compilation, native UI interaction, dynamic
mount/cleanup tests, accessibility checks, race/aliasing stress tests, timing or
allocation benchmarks, cross-framework execution or a user comprehension study.
Existing native experiment results are inherited evidence only. Product source
and the existing unrelated documentation/experiment edits were preserved. This
planning work makes no runtime-readiness or universal-ease claim.
