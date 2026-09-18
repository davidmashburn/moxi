# Make the workbench a reliable desktop application

## Execution evidence — September 18, 2026

Implementation is committed as `99b1ba7` on `feat/data-workbench`,
based on `c267311`. The companion report is
`docs/data-workbench-hardening.md` in the implementation worktree.

- H1: artifact provenance, negative checks, repaired prose guard, and isolated
  launch observer implemented. First launch and rebuilt desktop replay passed,
  including ordinary quit. The integrated repository check passed.
- H2: reproduced and fixed Mojo/C integer-width corruption of native action
  flags. Native AX import, selection, filtering, sorting, and export now work;
  the 64-case ABI regression passes. VoiceOver, CJK IME, and focus recovery
  acceptance remain open; dead-key composition is only a narrower verified case.
- H3: 3 × 100 native offscreen samples collected per case, with attributable
  phases and retained raw data. This measures custom-command paints, not the
  full native window or input-to-display latency. Comparison and supplementary
  offscreen memory soak passed. The separate 10-minute native-window observation
  completed with periodic interactions, exact selected-row export, and normal
  quit; no sustained RSS growth was observed. Visible latency remains unmeasured.
- H4: atomic batch key validation removes quadratic arbitrary-key construction.
  Targeted identity and failure regressions pass; time/memory tradeoffs are
  documented.
- H5: direct Core Graphics rectangle paths preserve tested pixels at 1×/2×.
  Retained after total CPU medians improved 3.1–4.8%; confidence is moderate
  because the host was not isolated. The 16.67 ms target still misses: scroll
  medians are 19.3 ms at 10k and 177.5 ms at 100k rows.
- H6: supplementary agent extension exercise and documentation improvements
  complete. Independent human acceptance remains open.

The original acceptance criteria below remain the milestone contract. Partial
native coverage and an agent authoring exercise do not close their open items.

### Follow-up measurements

The native probe and follow-up evidence are committed as `15ffce2` on
`feat/data-workbench`.

The implementation worktree's `docs/workbench-native-latency.md` records a real
native-window trace: twelve scroll samples per size yielded 19.203 ms median
at 10k and 83.364 ms at 100k from event enqueue to the end of CPU drawing.
This is not display-presentation latency. At 100k, scene construction and
drawing dominate; table-only scrolling still rebuilds and redraws the plots.
The next optimization should preserve unchanged plot output across table
scrolling, with explicit invalidation checks for plot-affecting interactions.

`docs/workbench-native-acceptance.md` records passing path-field focus/caret
retention across native window enlarge/restore. VoiceOver output and actual
Japanese marked-text composition could not be verified through the automation
interface; they remain acceptance gaps. Temporary test settings were restored.
`docs/workbench-memory-profile.md` records paired small-fixture/100k allocation
snapshots and the limitations of attributing allocations without stack logging.

## Decision and evidence

Use the workbench as Moxi's continuing integration workload. The next milestone
is reliable delivery and native interaction, with enough performance evidence
to choose a focused optimization. New widget families, platform ports, and a
general application framework remain outside this milestone.

Baseline: implementation branch `feat/data-workbench`, commit `c267311`, including
the app-bundle signing fix. This is a feature-branch baseline, not a claim that
the work is merged into main. Evidence lives in that revision's
`docs/data-workbench-validation.md` and `docs/benchmarks/data-workbench-2026-09-18/`.

Confidence is high that delivery and native acceptance need stronger checks:
a passing suite missed a fresh-launch signature failure, and published
accessibility controls did not reliably activate through native automation.
Confidence is moderate in the optimization order until native timing is
available. Measurements showing a different dominant cost would change that
order. This plan reviews existing evidence; it does not report new test runs.

The existing implementation establishes the A1/A4 workflow from
[APPLICATION-VALIDATION-PLAN.md](APPLICATION-VALIDATION-PLAN.md). A2 remains open;
A3 has self-assessed composition findings but no independent usability result;
A5 has an exploratory software-rendering baseline, not native latency or soak
acceptance. Preserve those distinctions.

## Execution order

| Slice | Outcome | Dependency | Priority |
|---|---|---|---|
| H1 | Fresh packaged launch is a checked deliverable | Existing signing fix | First |
| H2 | Required controls work through native accessibility and keyboard input | H1 for final replay | First |
| H3 | Native timing identifies the expensive stages | H1 for reproducible runs | Parallel investigation |
| H4 | Arbitrary row keys avoid quadratic plot construction | Focused baseline; H3 for app impact | Next |
| H5 | One measured rendering bottleneck is reduced | H3; preserve H4 behavior | After evidence |
| H6 | Another developer completes a small extension | H1 and stable instructions | Before support decision |

Start with H1 and an H2 reproduction. H3 instrumentation can proceed independently,
but only one worker should own `native/macos_window.m` at a time. Separate model,
benchmark, and documentation ownership is suitable for sub-agents. The integrating
agent owns cross-boundary review, a fresh native replay, and the support decision.
Agent completion is not an acceptance signal.

## H1. Check the artifact users actually launch

Owner: packaging and validation. Targets: `scripts/package_workbench_app.sh`,
`pixi.toml`, `scripts/check.sh`, and the existing native validation harness.

Keep the fresh staged bundle and ad-hoc signature verification already added.
Add a bounded launch smoke check which records the exact executable/build,
new process identity, window readiness, and clean quit. Verify both first launch
and rebuild/relaunch; an older process must not satisfy the check. Do not close
unrelated user app instances to make automation pass. Use an isolated test run,
or explicitly report a conflicting existing instance.

Separate headless signature checks from checks requiring an active macOS desktop.
An unavailable desktop is a skip with a reason, never a native acceptance pass.
Use native/UI observations for window readiness and ordinary input for one
interaction; process existence alone is insufficient. Capture startup stderr
and matching crash reports on failure. Reuse a current harness before adding one.

Repair the existing prose-artifact guard in `scripts/check.sh`: identify its
intended current input and ensure missing required input fails explicitly.

Validation: `pixi run data-workbench-build`, strict bundle signature verification,
the new bounded launch check, and shell syntax checks. Exercise a malformed
bundle only in a disposable copy to prove the gate rejects it.

Acceptance: a fresh build launches into a responsive window, quits cleanly,
and launches again after rebuilding; the evidence identifies the new process
and build. A broken signature and a missing required guard input cause failure.
Non-goals: notarization, distribution signing, installer, or auto-update.

## H2. Close native interaction gaps

Owner: macOS adapter and event routing. Targets: `native/macos_window.m`,
`src/moxi/macos.mojo`, the workbench integration test, and existing text/AX tests.

First reproduce one failing native button activation with a minimal control.
Trace native AX action entry, queued identifier/action, event conversion, routed
component event, and resulting state. Compare pointer, Return, and native AX
activation. Establish whether the failure is in Moxi or the automation client;
the existing evidence does not identify a root cause. If it is tooling-specific,
prove application behavior with an independent native AX client or VoiceOver.

Then replay the required workflow with keyboard and VoiceOver: locate labeled
controls, change a filter, inspect selected table rows and plot purpose, activate
import/export, and recover focus after scrolling and resizing. Separately test
actual marked-text composition, cancellation, and commit in a text field,
including a mixed-script path. Numeric filter rejection must preserve usable
state without corrupting an active edit.

Validation: focused routed-action tests, `pixi run workbench-test`,
`pixi run text-conformance`, `pixi run native-text-parity`, and recorded native
replay. Record OS, backing scale, input method, assistive technology, and build.

Acceptance: required actions execute exactly once through each supported route;
row identities, focus, edits, and hidden selections survive the workflow.
Headless semantic routing alone cannot close this slice. If VoiceOver or IME
cannot be exercised, leave that acceptance item open and name the missing access.
Non-goals: every macOS control behavior or complete multilingual text support.

## H3. Measure native work before choosing the rendering change

Owner: benchmark instrumentation. Targets: `benchmarks/data_workbench.mojo`,
`scripts/workbench_benchmark.sh`, native timing hooks, and the validation report.

Retain the software benchmark as a separate comparable lane. Add timing spans
for input receipt/queueing, state update, plot construction, retained layout/paint,
native submission, and native drawing where observable. Record invalidations,
emitted marks, command overflows, and relevant cache hits/rebuilds. Instrument
only stages needed to explain the workload; avoid a general tracing subsystem.

Distinguish CPU work, event-to-draw completion, and actual display presentation.
Do not label a callback or submission timestamp input-to-photon latency. Where
presentation cannot be observed, name that boundary and keep the claim open.

Measure cold load separately. For each steady operation at 10k and 100k rows,
collect at least 100 measured repetitions per process across three fresh runs,
after documented warm-up. Preserve raw samples, outliers, process boundaries,
row/key distributions, selection density, window dimensions, scale, revision,
and toolchain. Confirm instrumentation overhead with an uninstrumented comparison.
Use a fixed 10-minute interaction cycle to observe native memory after warm-up;
report interval samples and investigate persistent growth rather than treating
peak RSS or an arbitrary percentage as a leak verdict.

Validation: correctness assertions during measurement, benchmark contract checks,
and repeated native replay. Do not mix software and native values in one baseline.

Acceptance: a report attributes budget misses to measured stages, quantifies
repeat variability, and identifies the first optimization candidate. Keep
16.67 ms as a proposed CPU frame-work target on a named host, not a proven
native latency or universal 60 Hz guarantee. Non-goal: optimizing during baseline
collection or rerunning until a favorable sample appears.

## H4. Remove the known row-key construction trap

Owner: plot data construction. Targets: `src/moxi_plot/plot_data.mojo`, workbench
plot construction, `tests/plot_data.mojo`, and focused benchmark cases.

Compare monotone, reversed, shuffled, and sparse explicit keys. Choose the
smallest indexed or validated bulk construction change that eliminates repeated
duplicate-key scanning while preserving rejection semantics and stable identity.
Account for extra memory and keep the generated-key fast path inexpensive.

Validation: duplicate and exhausted-key cases, arbitrary import order, sorting,
filtering, hidden selections, and selected export. Measure construction across
increasing sizes with the same distributions; validate application impact through
H3's timing boundary. Run `pixi run workbench-test` and the focused plot tests.

Acceptance: construction no longer exhibits quadratic growth for accepted
nonmonotone keys, with no identity regression. Document any compatibility or
memory cost. Non-goal: changing imported IDs, dropping observations, or introducing
a broadly exposed ingestion API unless the implementation requires it.

## H5. Optimize the measured bottleneck once

Owner: the stage identified by H3. Candidate files are workbench scene assembly,
plot geometry/cache code, or the native renderer; choose after attribution.

If unnecessary scene rebuilding dominates, preserve unaffected plot work across
table scrolling or selection changes. If mark generation/drawing dominates,
evaluate batching or viewport reduction first. Aggregate or reduce geometry only
with explicit hit-testing and selection semantics: users must still recover the
correct source observations and export exact rows. Do not assume a GPU rewrite,
larger command buffer, or sampling is the answer.

Validation: the same workloads, correctness assertions, host, and measurement
boundaries before and after. Run the appropriate focused tests, benchmark
contract checks, and full regression benchmark for native/rendering changes.

Acceptance: measured improvement exceeds observed run-to-run variability, does
not trade away selection correctness, and has a stated memory/complexity cost.
Reassess the 10k target and state the 100k support limit explicitly. If the target
still misses, identify the next measured cause; do not conceal the miss by
silently shrinking the workload. One successful optimization completes this
slice; further changes need evidence from the new profile.

## H6. Test authoring usability with a small real task

Owner: documentation and an independent developer. Targets: workbench guide,
native host example, and only the APIs implicated by observed difficulty.

Ask another developer to add one summary panel that follows the active filter
and preserves existing selection. Give the documented setup and public APIs;
record questions, errors, and places requiring private implementation knowledge.
If no developer is available, report that gap; an agent exercise is supplementary.

Acceptance: capture a reproducible friction list and improve the highest-impact
documentation gap. Propose a helper only when a concrete repeated operation or
error justifies its compatibility cost. Run relevant composition tests and
`pixi run api-status-check` if public APIs change. Non-goal: a DSL or general API
redesign based on a single task.

## Milestone closeout

Deliver one evidence report linking launch results, native interaction replay,
timing breakdowns, raw benchmark data, key-order scaling, and authoring findings.
Run the repository checks after integrating code changes; inspect current CI
when a PR is created. Keep manual/unavailable checks visibly distinct from passes.

H1 and H2 gate the reliable-desktop claim. H3 and H4 gate credible performance
guidance for accepted input. H5 supplies a measured improvement, and H6 informs
the next authoring decision. Do not promote untested platform, accessibility,
text, or performance coverage. Choose the next milestone from the remaining
evidence rather than the size of the feature backlog.
