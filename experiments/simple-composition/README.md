# Simple composition after paint optimization

This experiment removes the application-specific cache host. The same owned
fields, direct methods, typed contexts, explicit routes, and inspector remount
policy now feed the existing `HandlerHost` through one `render` method. It adds
no authoring language, dependency list, reflection helper, or runtime module.
The original `Editor` is imported unchanged.

```mojo
var app = App(HandlerHost(Workbench()), Rect(0, 0, 800, 4000))
```

The root contains ordinary declarations such as:

```mojo
ui.child(self.left, self.services, Self.route_left, key=LEFT)
ui.child(self.settings, self.services.settings, Self.route_settings, key=SETTINGS)
if self.header.inspector_visible:
    ui.child(self.inspector, self.services.document, Self.route_inspector,
             key=self.inspector_key())
```

`screen.mojo` is the complete author-facing root. `probe.mojo` compares it with
the previous typed workbench using 500 mixed transactions and independent domain
assertions. The hosts have different topology: this candidate flattens child
controls into one column; the typed host mounts component surfaces. The probe
compares logical state and all non-container ViewNode fields after normalizing
identity, parent identity, geometry, and their accessibility counterparts. It
executes paint, but does **not** claim identical layout or paint streams.

The probe also checks permission validation, read-only service overrides,
private drafts, conflicts, undo, direct root writes, copied-host routing, old
inspector callbacks/events across removal/remount, caret insertion, composition,
resize, and conditional sibling insertion/reordering. The last two operations
preserve IDs, focus, caret, selection, and IME state.

## Practical edits

`run.py` compiles temporary source variants and records their exact patches:

- **Add a local field:** five added code lines in `editor.mojo`; no parent,
  route, cache, or runtime changes. The field remains private to its editor.
- **Add a child:** seven added code lines in `screen.mojo`: a named key, field,
  initialization, three-line route, and declaration. One file, five edit sites;
  no repeated host registrations. The new editor updates shared services.
- **Add a shared setting:** seven added code lines across the domain, settings
  panel, and editor; all three editor consumers refresh. No root, routing,
  cache, or runtime changes.

The root/composition slice falls from **131 to 85** nonblank, noncomment,
non-docstring lines: the previous 60-line root plus 71 operational host lines
versus the entire new screen module. Including the old host's counter methods
would make the baseline 150. These are active authoring slices, not repository
file totals: historical fixtures and the unused original Workbench type remain
in the imported comparison module. Shared panel definitions, domain, and editor
are excluded on both sides; the new module's five import lines are included.

The unchanged reusable runtime/bindings total 281 + 78 counted lines. The new
candidate does not use the additional 65-line typed `Boundary` module. This is
reuse of an existing host, not proof that the framework has become trivial.
Counts use this runner's documented function; older experiments used somewhat
different counting conventions.

## Whole-candidate timing

On the recorded machine, median real App update + paint costs for eight panes:

- Empty history, local edit: simple **0.068 ms**, typed cached **0.075 ms**,
  typed forced **0.103 ms**.
- Empty history, shared commit: simple **0.067 ms**, cached **0.095 ms**,
  forced **0.104 ms**.
- 10,000 history entries, local edit: simple **0.072 ms**, cached **0.336 ms**,
  forced **0.158 ms**.
- 10,000 history entries, shared commit: simple **0.062 ms**, cached **0.130 ms**,
  forced **0.137 ms**.

These are whole-candidate comparisons with different tree topology, **not** an
isolated estimate of caching overhead or a guarantee of speedup. Protocol: O3,
two warmups/five samples, rotating three-mode order, real events, setup/checks/
destruction excluded, headless CPU update and paint, unisolated machine. The
82-file suite and competing compilation had finished before measurement. Raw
samples and min/max/median splits are in `results.json`. An earlier successful run measured the empty-history local edit at
0.041/0.047/0.064 ms; `repeat-observation.json` retains its raw samples and
source provenance. Only the behavioral reorder test changed between runs. The
substantial absolute timing variation means the small local-edit advantage is
not statistically established. Native presentation,
input latency, and large pane counts were not measured here.

## Decision and limits

**High confidence:** use this simpler full-declaration composition as the
reference behavior for subsequent API work; the repeated application-specific
cache host is unnecessary for this workload. Keep selective updates an optional
implementation optimization whose benefit must beat the complete baseline.

**Moderate confidence:** ordinary fields and direct methods are a viable default
for applications of this shape. Evidence that would change that recommendation
includes larger representative applications whose full declaration cost
materially dominates, or user comprehension failures despite this reduction.

This still has eight routes, explicit stable keys, and an inspector generation
policy. Full refresh revisits all visible panes. Positional controls *inside* a
leaf still need explicit scope when conditional insertion would change their
identity; the test moves whole children, not arbitrary controls within Editor.
The prototype's retained control list keeps inactive slots after unmount, and
uses linear searches; long-running churn and large trees remain scaling risks.
We did not test replacing the entire root/collection while retaining callbacks.
The older collection-replacement identity counterexample remains unresolved.
There is no unfamiliar-reader usability result and no claim of Tags API comfort.

Run `python3 experiments/simple-composition/run.py`. To separate compilation
from measurement, use `--prepare`, then `--measure <prepared.json>` after other
work has stopped. The latter checks source and binary hashes before executing.
