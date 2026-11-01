# Authoring Moxi applications

Write ordinary Mojo state and methods. Describe controls in `render`. Give changing
collections stable keys. Let the host manage retained controls and queued delivery.

The supported authoring API lives in `moxi.authoring`. The examples import it
using only the normal `src` package path. The lower-level `Component`/`App` API
remains available and is documented in [API.md](../API.md).

Start here, then read [building an application](application-guide.md) and
[how this compares with other systems](comparisons.md). The examples run headlessly;
they exercise real Moxi controls but do not open a window.

## A counter

The complete model from [counter.mojo](../../examples/authoring/counter.mojo):

```mojo
from moxi.authoring import Screen, UI

struct Counter(Screen):
    var count: Int

    def __init__(out self):
        self.count = 0

    def increment(mut self):
        self.count += 1

    def render(self, mut ui: UI[Self]):
        ui.label("Count: " + String(self.count))
        ui.button("Increment", Self.increment)
```

`Counter` owns its count. Clicking the button calls `increment` on the current
counter. `render` describes what to show from the current values. It may run again,
so saving files, starting requests, and changing model state belong in commands or
event handlers.

`UI` is the declaration builder's type; `ui` is its local variable name. Neither
is the model. `Self.increment` names a method; the runtime supplies the current
model when it delivers the action. There is no captured pointer to an old counter.

The runnable example constructs its host with inferred types:

```mojo
from moxi import App, Rect
from moxi.authoring import HandlerHost

var app = App(HandlerHost(Counter()), Rect(0, 0, 320, 200))
```

The model owns application values. `HandlerHost` connects declarations to retained
controls and action routing. `App` provides layout, focus, scrolling, and event
dispatch. You construct these once at the application boundary; ordinary model
methods do not need to mention them.

From the repository root, run all three examples and their behavior checks:

```sh
python3 examples/authoring/run.py
```

The [native counter](../../examples/authoring/window.mojo) uses the same model
with `MacOSWindow`, `MacOSRenderer`, and `app.run(window, renderer)`:

```sh
pixi run --locked authoring-counter-build
./dist/moxi-authoring-counter
```

## Several editors

[editors.mojo](../../examples/authoring/editors.mojo) adds a `Pane`, a small
model that renders as a child. Its `draft` is an ordinary string, and its `change`
method receives text input. A `Keyed[Editor]` owns several such models:

```mojo
self.editors = Keyed[Editor]()
_ = self.editors.append(Editor("First"))
_ = self.editors.append(Editor("Second"))
```

`append` allocates an entry key. Move the whole entry when reordering, so its key
travels with its value. Removing an entry retires its controls after publication.
Adding a new entry creates a new owner even if its draft text matches an old one.

The parent's declaration is:

```mojo
field["editors"](ui, self, NoneType(), key=EDITORS)
```

`field` finds the named child field at compile time and routes actions into its
current value. `EDITORS` identifies this child within its parent; the collection
supplies each entry's identity beneath it. `NoneType()` means these editors need
no shared context. This is the API's explicit spelling; it is real remaining
ceremony, not a new language to learn.

Use stable keys for dynamic children. A row index or display label is usually the
wrong key: sorting changes indices, and labels can change or repeat. Fixed controls
inside one pane use declaration positions; changing their logical order requires
explicit scopes. Keys do not automatically make arbitrary positional declarations
safe to rearrange.

## Shared data and local drafts

[shared.mojo](../../examples/authoring/shared.mojo) contains two drafts and
one document. `Desk` owns all three. Each draft receives a `Document` as its typed
context and edits the document only when Apply is clicked:

```mojo
def apply(mut self, mut document: Document):
    document.title = self.text
```

The parent supplies the route:

```mojo
def route_left(mut self, key: Int, action: Action[Draft, Document]):
    if key == LEFT:
        action(self.left, self.document)
```

And declares the child:

```mojo
ui.child(self.left, self.document, Self.route_left, key=LEFT)
```

The read context describes the current document. At dispatch, the route passes the
actual current parent-owned document for mutation. Applying the left draft changes
the saved title visible to both panes; the right draft keeps its unsaved text.
There is no ambient global store or hidden subscription in this example.

## Updating values versus starting over

| Intent | Operation | Meaning |
| --- | --- | --- |
| Change existing state from a control | Model method | Same owner; host publishes the result |
| Change state from outside control dispatch | `update_model(app, command)` | Run a synchronous command and publish before draining queued work |
| Replace values of an existing owner | Assignment inside a command | Existing queued work can still address that owner |
| Discard a collection's children | `editors.reset()` inside a command | Fresh entries receive fresh keys |
| Start a new native root session | `reset(app, Root(), window, renderer)` | Clear old input and owned requests, replace the root, and publish output |
| Start a new headless root session | `reset_headless(app, Root())` | Retire owned requests and the old root/retained UI lifetime without a native backend |

For example, assigning a fresh `Counter()` resets the number but keeps the logical
counter. A previously captured increment can still increment it. Root `reset`
rejects that old captured action. Use assignment for updating the same thing;
use reset when old work must no longer apply.

Reset a `Keyed` collection using its method, rather than assigning a newly
constructed collection into an existing owner: restarting its allocator could
reuse identities. At a whole-root reset, fresh collection allocators are safe
because the host lifetime changes too.

Call native `reset` on the UI thread between event dispatches. It currently
supports macOS AppKit and `TestWindow`; other backends reject it before changing
the application. `reset_headless` does not clear native input or publish a native
snapshot. See the [application guide](application-guide.md#requests-and-native-input)
for request scheduling, supported boundaries, and validation limits. The
[API inventory](api-status.md) lists the supported exports; internal retained
control records and erased callback storage are implementation details.

## What this promises

The authoring strategy keeps state and behavior in ordinary Mojo code. It separates
application values from retained interaction state such as focus, selection, and
IME composition. Stable identity lets the latter survive appropriate updates.

This syntax does not promise automatic field tracking, constant-time routing, or
one render per mutation. Selective declaration and paint work are runtime
optimizations with separate evidence. Current examples establish behavior and
teach ownership; they are not performance benchmarks or a human usability study.
