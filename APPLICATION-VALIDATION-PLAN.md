# Prove Moxi through one useful application

## Decision and evidence boundary

Use a small macOS data exploration application to test whether Moxi's existing
UI, plotting, and rendering contracts compose into a useful development
experience. Prioritize the defects and API friction this application exposes
before expanding widget, plot-family, or platform coverage.

This is a proposed execution direction, not a new implementation or stability
claim. It expands the September 18, 2026 repository assessment against `main`
at `a34963f`. Confidence is moderate: the assessment inspected architecture,
selected runtime code, examples, test sources, and support/performance policy;
it did not rerun builds, tests, benchmarks, or desktop interaction. Historical
validation in CURRENT-STATE.md remains historical evidence, not a fresh pass.

The strongest product hypothesis is that Moxi is useful for interactive visual
applications close to Mojo computation. Explicit state ownership, typed data,
retained rendering, and native presentation reinforce that use case. The
capability bus remains an optional application policy boundary. Its existence
alone is not evidence that agent integration should lead the product story.

Evidence that would change this direction includes a different real consumer
with stronger needs, substantial difficulty composing the existing plotting
and UI surfaces, or application measurements showing that framework overhead
removes the expected benefit of keeping computation and interaction together.

## Relationship to the existing plan

Keep the landed package boundaries, compatibility inventories, shared fixtures,
and performance policy. This proposal gives the remaining work a concrete
consumer; it does not reopen settled packaging or trait decisions.

- S3, real desktop validation, becomes an early part of application validation.
- S2, oversized structs, remains an explicit decision. Split a type only when
  application work or an independently demonstrated ownership defect warrants
  it; file size alone is not a prerequisite for this milestone.
- Gate 2 text/native work and Gate 4 plotting work advance in bounded slices
  required by the application. Their full exit criteria remain separate.
- Gate 3, a linked non-macOS runtime, follows this application milestone unless
  a concrete consumer requires a different platform first.
- Existing ecosystem proposals remain recorded, but do not automatically add
  dependencies or release obligations to this milestone.

The application is complete when a user can answer a data question reliably,
not when it demonstrates every public feature.

## Application scope

Build a local workbench for exploring numerical measurements: select a dataset,
filter it, inspect a scatterplot and histogram, select observations, examine
matching rows, and export the selected data or supported plot output. A useful
example question is: “Which observations explain this distribution's tail?”

Start with one deterministic dataset from the existing plotting/scenario
infrastructure. Add one deliberately bounded local CSV import path so the
application becomes useful beyond its fixture. Define accepted column types,
row limits, missing-value behavior, and errors before implementing import.
Reuse an existing reader only if it fits those constraints; a general ingestion
framework is outside scope. A native file chooser is not a prerequisite.

Required experience:

1. Open a dataset and see its row count, supported columns, and any rejected
   input diagnostics. Failure preserves the last usable dataset.
2. Choose numeric fields and adjust a filter through ordinary controls.
3. Inspect linked scatter/histogram views and a virtualized data table.
4. Select observations and preserve row identity across filtering and sorting.
   Define whether hidden selections persist; show the resulting count clearly.
5. Navigate with the keyboard, edit filter text, copy a value, and resize or
   scroll without losing unrelated state.
6. Export selected rows and an existing supported plot format, with visible
   success or failure. Do not imply print-quality or PDF support.

One window and macOS are sufficient. Streaming, remote data, accounts,
collaboration, notebook integration, new plot families, and agent transport
are excluded. Do not invent a broad app framework to build this application.

## Work slices and acceptance

The paths below are implementation targets on `main`, not files to copy into
this orphan branch. New paths are proposals; use existing equivalent fixtures
and harnesses when they cover the same behavior.

### A1. Establish a complete fixture-driven workflow

Owner boundary: application state owns dataset, fields, filter, and selection;
Moxi owns generic controls/runtime; Moxi Plot owns plot semantics. Keep the
application outside the public library's compatibility surface.

Targets: proposed `examples/data_workbench.mojo`, application support under
`src/moxi_demo/`, existing `src/moxi/scenarios.mojo` fixture descriptors, and a
focused integration test such as `tests/data_workbench.mojo`.

Implement the workflow first using current public APIs. Record friction while
building it. Do not immediately move application helpers into core exports.

Validation: run the focused Mojo test, `pixi run scenario-check`, and
`pixi run demo-catalog-check` when registering the example. Replay filtering,
selection, sorting, and data replacement with expected row keys and counts.

Acceptance: the fixture-driven question can be answered through actual
controls; the selected rows agree with the data model; two independent child
surfaces preserve state while another surface updates. A static gallery or a
scripted sequence that bypasses input routing does not satisfy this slice.

Non-goals: API redesign, import, streaming, new marks, and platform expansion.

### A2. Prove native interaction and state preservation

Owner boundary: generic routing/state belongs to the runtime, native focus,
IME, clipboard, and accessibility publication belong to the macOS adapter.
Application code must not patch private runtime state to pass the workflow.

Targets: the application and focused tests; `src/moxi/app_runtime.mojo`,
`src/moxi/column_runtime.mojo`, text/collection modules, and
`native/macos_window.m` only for reproduced defects. Reuse S3's desktop harness
and existing text/accessibility contracts before adding another harness.

Exercise keyboard traversal, text selection and replacement, marked-text
composition, clipboard operations, table navigation, scroll dragging, plot
selection, resize, and focus restoration. Include mixed-script text and a
filter update while another component owns active interaction state.

Validation: `pixi run text-conformance`, `pixi run native-text-parity`, relevant
input/scroll/accessibility tests, and a real desktop replay. Use actual native
input and accessibility observations. Record any manually exercised steps;
headless event injection does not prove native IME or screen-reader behavior.

Acceptance: no lost edits, unexpected focus changes, stale selection, stuck
pointer capture, or inaccessible required control in the recorded workflow.
A screen-reader user can identify the plot's purpose and inspect selected data
through the table. Record assistive technology, OS, scale factor, input method,
and limitations. Mark unexercised paths unverified rather than passed.

Non-goals: full Unicode paragraph support, multiple windows, and all native
widget behaviors. Failures inside the required workflow block this slice.

### A3. Reduce demonstrated authoring friction

Owner boundary: application helpers stay local until a repeated operation
justifies a small supported convenience API. Preserve explicit ownership,
stable identity, and backend-neutral values.

Targets: `examples/hello_component.mojo`, the workbench, `src/moxi/component.mojo`,
`src/moxi/column_view.mojo`, relevant layout helpers, and API documentation.
Compatibility inventories change only if a public API changes.

Audit the actual effort required to compose children, assign stable IDs, route
actions, set ordinary layout/wrapping, and update localized state. For each
candidate improvement, capture a before/after call site, the error it prevents,
and its compatibility cost. The initial small example's explicit IDs, geometry,
wrapping setup, and layout call are investigation prompts, not proven defects.

Prefer at most a few narrowly demonstrated improvements. Do not introduce a
new DSL, callback registry, reflective system, or automatic identity scheme
without an application requirement and failure cases for the current approach.

Validation: focused component/layout/composition tests and
`pixi run api-status-check` for public changes. Ask another developer, when
available, to add a filter or child panel using the documentation; record where
they need implementation knowledge. Agent completion time is not usability
measurement. If no independent developer is available, label usability as
self-assessed.

Acceptance: ordinary application code uses documented public APIs; each added
helper removes observed repetition or an error mode; identity/state preservation
survives the change. A useful outcome may be documentation improvements with
no API changes.

### A4. Make the application useful with local data

Owner boundary: import/export and recoverable user errors stay application-local
unless an existing public value boundary already owns the operation.

Targets: workbench support, focused import/export fixtures and tests, and its
usage documentation. Preserve stable row keys independently of table order.

Validation: valid, empty, malformed, missing-value, unsupported-column, and
oversized input cases; selected-row export round-trip; supported plot export
inspection. Use synthetic or explicitly shareable data in checked-in artifacts.

Acceptance: a user can import an accepted local file, answer the stated data
question, and retrieve the result. Input failures explain what can be corrected
and preserve usable state. Document the supported input/export subset.

Non-goals: general ETL, arbitrary file formats, persistence, and PDF promises.

### A5. Measure the composed application and decide support

Owner boundary: application workloads feed existing benchmark infrastructure;
framework counters and native timing keep their existing meanings.

Targets: `benchmarks/`, the result schema only if needed, existing benchmark
scripts, `docs/performance.md`, and application documentation. Reuse the current
host metadata and baseline compatibility rules.

Measure cold load separately from steady-state filter, hover, selection,
scroll, and resize. Use 10,000 and 100,000 rows initially; larger workloads
require a demonstrated user need. Capture source rows, visible rows, emitted
geometry, rebuild/reconcile work, cache reuse, memory behavior, and repeated
latency samples. Verify selection against original row identity when geometry
is reduced.

Proposed target: steady-state interactive frame work has p95 at or below the
60 Hz budget of 16.67 ms on a named reference host. Establish the baseline and
exact timing boundary before treating this as a release gate. CPU submission
time is not end-to-end latency; measure visible completion separately where
possible and identify missing instrumentation. Report slow cold operations
separately, with explicit bounded behavior and progress requirements if needed.

Validation: appropriate focused application benchmarks, `pixi run benchmark-quick`,
`pixi run benchmark-contract-check`, compatible baseline comparison, and the
full profile for changes affecting native/rendering performance. Run the
repository's required integration/release checks before promoting support.
Do not repeat expensive unrelated checks for documentation-only changes.

Acceptance: the workload is repeatable, correctness survives repeated
interaction, steady-state resource use has no unexplained growth, and any
budget miss has an explicit measured cause and support decision. Store
revision, toolchain, hardware, workload, and result artifacts with the claim.
A missed target is a finding; it must not be hidden by reducing the workload
without documenting the resulting support limit.

## Evidence and release decision

Deliver one concise application report linking to:

- public-API application source and reproducible fixture/import instructions;
- correctness replay and native interaction results, with known failures;
- before/after authoring examples and any independent usability observations;
- benchmark artifacts and their exact measurement boundaries;
- a short native walkthrough, plus accessibility observations; and
- the supported platform, text, data, export, and performance subset.

Promote only the subset those results establish. This milestone does not by
itself establish a 1.0 API, general cross-platform support, or production
readiness. Keep an explicit list of unverified claims.

Keep the capability bus optional. Add a capability-backed action only after a
real workflow needs external authorization or shared UI/agent mutation policy.
Keep the Python surface within its existing declared contract during this
milestone; expand it when a consumer establishes a concrete interoperability
need. Revisit another platform after the application provides a reusable
acceptance workload and the runtime/toolchain feasibility is demonstrated.

The immediate next implementation slice is A1, followed by A2 before broad API
work. A3 and A4 then use the resulting evidence; A5 starts measurement early
and closes the milestone with a support decision. No calendar estimate is
assigned until A1 exposes the actual integration cost.
