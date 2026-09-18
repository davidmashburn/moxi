# Data workbench

The workbench is a standalone macOS application for exploring local numerical
observations: **which observations explain this distribution’s tail?** It
combines editable controls, linked plots, and a virtualized table through
Moxi’s ordinary `Component` and `App` event path.

```sh
pixi run data-workbench
```

The build packages a fresh app bundle, applies a local ad-hoc signature, and
verifies the signature before launch. No signing account is required.

The initial data comes from Moxi’s deterministic plotting fixture. No network
service or account is needed. The application is experimental and is not a
new stable framework API. See the [validation report](data-workbench-validation.md)
for measured behavior and unverified paths.

`examples/data/workbench-tail.csv` is a small synthetic import example. Its
`value > 10` tail contains observations with keys 6, 7, and 10, with values
18, 21, and 28. Use it to check that filtering, selection, and exported rows
agree on the answer.

## Controls and files

The X, Y, and Filter buttons cycle through the dataset's numeric fields.
Enter a threshold to keep values strictly greater than it; Clear restores
all rows. Sort toggles the table's order by the current Y field. Selecting
a table row toggles its stable observation key. With a row focused, Command-C
copies its Y value (or `missing`). Selection remains attached
to the observation when its position changes or a filter hides it.

Enter an absolute local CSV path and press Import. The status line reports
the loaded row/field counts or the input error. For the tail example, choose
`value` as the filter field and enter `10`, then select the three remaining
observations.

Export CSV writes `<CSV path>.selected.csv`; Export SVG writes
`<CSV path>.scatter.svg`. With an empty path field, the destinations are
`/tmp/moxi-workbench-selected.csv` and `/tmp/moxi-workbench-scatter.svg`.
The status line displays the destination or write error. Repeating an export
replaces that output file. SVG exports the current scatter plot; histogram,
PDF, and print-layout export are outside this application's scope.

## Source and boundaries

- `src/moxi_demo/workbench_data.mojo` owns import, row identity, filtering,
  sorting, selection, and selected-row CSV generation.
- `src/moxi_demo/data_workbench.mojo` owns the application controls, table,
  plot state, and event routing.
- `examples/data_workbench.mojo` connects the application to the native
  window, clipboard, and canvas renderer.
- `src/moxi_demo/workbench_files.mojo` bounds local reads before parsing and
  writes requested exports.

These modules are imported directly, rather than added to the package’s
compatibility export surface. Existing framework traits and public APIs stay
unchanged. The native host must render both retained controls and the plot
scene; declaring a canvas alone does not draw its contents.

## Reproducing validation

```sh
pixi run mojo run -I src tests/workbench_data.mojo
pixi run mojo run -I src tests/data_workbench.mojo
pixi run data-workbench-build
pixi run workbench-benchmark
```

The headless tests exercise the data contract and routed application events.
Native checks additionally need the visible window: select a plot point, sort
and filter its table row, resize and scroll, replace text with the keyboard,
copy a selected value, import malformed data, and export the result. Inspect
both the rendered content and the published accessibility tree. Passing
headless text events does not establish native input-method composition or
screen-reader usability.

Performance timing must include the composed application operations and report
cold construction separately. In-process CPU timings do not establish visible
input-to-display latency. The experimental workbench does not change the
repository’s reviewed performance baseline or supported platform matrix.

## Local CSV contract

Import accepts UTF-8 comma-separated text with a header and numerical values.
The limits are 100,000 data rows, 64 input columns, and 32 MiB. Blank lines are
ignored; empty cells and literal `null` represent missing values. Quoted
fields, embedded commas, and categorical/text data are outside this initial
subset. Headers must be unique and nonempty. Values use finite `Float32`
precision, including when imported from integer-looking text; this is not a
lossless high-precision analysis tool.

An optional `key` column supplies unique nonnegative integer row identities.
Without it, import assigns identities in source order. Sorting and filtering
operate on source-row indices and preserve these identities. A successful
replacement starts a new dataset and clears its selection; a failed import
retains the previous dataset and selection.

Selected-row CSV contains the `key` column and all numeric fields in source
order, including selected rows hidden by a filter. Missing values export as
empty cells. The displayed hidden-selection count makes that inclusion
explicit. CSV round-trip preserves the application’s stored precision, not
arbitrary source decimal precision.

## Composition lessons

The application exposed three concrete traps worth checking in other Moxi
consumers:

- Assign labels their own IDs. Deriving a label ID with `button_id + 1`
  collides when the next button already owns that number. Keep the control
  IDs explicit and allocate a separate label range.
- Submit the two plot scenes together. Two successive native
  `render_scene(...)` calls each begin a custom paint frame; the second
  replaces the first. `combined_scene(scatter_bounds, histogram_bounds)`
  gathers both scenes with separate clips for one native submission.
- Keep table position separate from observation identity. A virtual list's
  positional recycler keys locate visible slots; the row builder maps each
  position to the model's source index and stable observation key. Repeated
  `set_key(...)` calls scan the recycler and can reject permutations against
  its existing default keys.

For example, the initial host submitted each plot independently:

```mojo
scene_renderer.render_scene(app.component.scatter_scene(scatter_bounds))
scene_renderer.render_scene(app.component.histogram_scene(histogram_bounds))
```

The working host submits one frame containing both:

```mojo
scene_renderer.render_scene(
    app.component.combined_scene(scatter_bounds, histogram_bounds)
)
```

This application helper prevents frame replacement without changing the public
renderer trait. The native rectangle buffer also needed enough capacity for
both plots and selected-point overlays; a native submission test guards that
bound. Histogram domains explicitly include the final bin edge and start the
count axis at zero.

A plot data change was justified by this workload: `PlotDataTable` now
avoids a duplicate-key scan when a newly appended key is above all prior
keys. Previously, constructing a large canonical fixture performed a linear
scan per row. Lower explicit keys still receive duplicate checking, and tests
cover sparse keys, rollover, duplicates, and generated-key exhaustion.

These are implementation findings and self-assessed authoring guidance. No
independent developer usability study was conducted, and no new convenience
API or compatibility export was introduced for the application.

The native adapter also supplies standard Edit/Quit menu commands when the
host has not supplied a main menu. The desktop replay found that native text
editing lacked normal Command-A/C/V behavior without those menu actions.
