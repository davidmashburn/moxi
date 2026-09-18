# Workbench summary-panel authoring exercise

This is a supplementary **agent exercise**, not human developer usability
evidence. The worker had already worked on plot construction in this session,
so it had prior implementation familiarity. H6's independent human acceptance
item remains open. Confidence is high in the narrow tested behavior and low in
generalizing the effort or friction to a new developer.

## Task and isolation

Add a small panel showing the active Y field's valid visible count and mean.
Filtering must change the summary without clearing selected source identities.
Missing values must be excluded; an empty result must be explicit.

The experiment copied `src` and the workbench integration test to
`/tmp/moxi-authoring.O0Cp4s`. Only that copy received the extension. Shared
application source was not changed for this exercise. The copy included the
current H4 batch-construction change. Starting revision was `c267311` with local
hardening changes; toolchain was Mojo `1.1.0.dev2026082605` on macOS 26.6.2 arm64.

Steps:

1. Read `docs/data-workbench.md` and `examples/data_workbench.mojo`.
2. Inspect the component's `build` method and available model accessors.
3. Allocate label ID 106, implement the read-only summary below, and add one
   `ColumnView.add_label` after the status line.
4. Reserve 36 pixels for the 28-pixel label plus the column's 8-pixel gap by
   changing the table-height subtraction from 470 to 506 in the copied file.
5. Mount the copied component through `App`, dispatch real targeted
   `TextInputEvent` filter changes, and assert summary and selection behavior.
6. Run the copied existing workbench integration test.

## Reusable extension example

In `src/moxi_demo/data_workbench.mojo`, add an unused label ID alongside the
other label IDs:

```mojo
comptime DATA_WORKBENCH_SUMMARY_ID = 106
```

Add this method to `DataWorkbenchState`:

```mojo
def summary_text(self) -> String:
    """Summarize valid active Y values without changing row selection."""
    var count = 0
    var total: Float64 = 0.0
    for row in range(self.data.visible_count()):
        if self.data.visible_value_is_valid(self.y_field, row):
            total += Float64(self.data.visible_value_at(self.y_field, row))
            count += 1
    if count == 0:
        return String("Summary · ", self.y_field, " · no valid visible values")
    return String("Summary · ", self.y_field, " · ", count, " valid · mean ", total / Float64(count))
```

In `build`, immediately after the status label:

```mojo
root.add_label(DATA_WORKBENCH_SUMMARY_ID, self.summary_text(), 28.0)
```

Change `bounds.height - 470.0` to `bounds.height - 506.0` for the table height.
This calculation is specific to this app's current layout, not a general Moxi
layout rule. No new framework API, private method call, event handler, or cached
summary state is needed. The summary is O(visible rows) on every component build;
this experiment does not establish an acceptable 100k-row performance cost.

## Behavior check

The focused test imports this CSV through `WorkbenchData.load_csv`:

```csv
key,x,y
8,1,2
3,2,8
10,3,
```

It selects key 8, sets the filter field to `y`, and constructs
`App[DataWorkbenchState]` with a 1180×820 `Rect`.

| Action | Required summary | Required selection |
| --- | --- | --- |
| Initial mount | `Summary · y · 2 valid · mean 5.0` | Key 8 selected |
| Dispatch threshold `3` | `Summary · y · 1 valid · mean 8.0` | Key 8 still selected, one hidden |
| Dispatch threshold `99` | `Summary · y · no valid visible values` | Key 8 still selected |

The threshold events use `Event(TextInputEvent(text, start, end))`, target
`DATA_WORKBENCH_THRESHOLD_ID`, and pass through `App.dispatch`. The initial
replacement span is `[0, 4)` for the default `0.70`; the second span is `[0, 1)`.
The test also asserts that `app.view.bounds_for(DATA_WORKBENCH_SUMMARY_ID)` has
positive height. This verifies retained layout presence, not native visual fit.

Both checks passed on the isolated copy:

```sh
pixi run mojo run -I /tmp/moxi-authoring.O0Cp4s/src /tmp/moxi-authoring.O0Cp4s/summary_test.mojo
pixi run mojo run -I /tmp/moxi-authoring.O0Cp4s/src /tmp/moxi-authoring.O0Cp4s/test.mojo
```

Their logs are `summary-test.log` and `workbench-test.log` in that temporary
directory. The committed-document candidate contains the extension recipe and
exact behavioral assertions so the result does not depend on keeping temporary
files. No compile or assertion failure occurred in this exercise.

## Friction and recommended documentation change

The existing guide identifies the correct files and warns about label IDs and
stable source identity. Those instructions were sufficient to choose an
extension location without changing the host.

Three details still required reading implementation source:

- The model has `visible_value_at` and `visible_value_is_valid`, but the guide
  does not show them. Using a visible position with `value_at`, which expects a
  source row, would silently summarize the wrong observations after filtering.
- Read-only derived UI can be computed in `build`; it does not need a second
  mutation or refresh path. The guide does not currently show that pattern.
- The table's available height is manually calculated using 470, so adding a
  panel requires updating that unrelated-looking constant. This is app-specific
  layout knowledge, despite using public `ColumnView` APIs.

The highest-value documentation improvement is a short extension recipe using
the visible-row accessors and a routed filter test; the example above supplies
that recipe. A broader helper or layout redesign is not justified by this one
exercise. A human developer should repeat it without implementation coaching
before H6 is considered accepted.

Native screenshots, minimum-window layout, VoiceOver, mixed-script editing,
and summary performance were not checked by this supplementary exercise.
