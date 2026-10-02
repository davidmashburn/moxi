# External native consumer milestone

The next milestone tests whether Moxi's workbench improvements transfer to an
application outside this repository. The deliverable is a small macOS Apple
Silicon CSV comparison application, maintained in a separate local repository,
`../moxi-csv-compare`. No remote repository or public release is implied.

## Contract

- Compile against installed Moxi and Moxi Plot packages, without a Moxi source
  import path or a dependency on `moxi_demo`.
- Load two numerical CSV datasets, choose a column from each, compare their
  distributions using shared bins, and inspect/select rows.
- Report malformed files without replacing the last successfully loaded data.
- Document supported CSV syntax, size limits, setup, and native host provenance.
- Reproduce installation, tests, and signed application build from a fresh
  directory containing only the consumer and its documented dependency bundle.

The first implementation may use a locally built package channel. That proves
the package boundary, not public registry availability. The existing Moxi
consumer smoke test does not establish native host distribution: repository
demos link `native/macos_window.m` separately. Any host bundle needed by the
consumer must be explicit, carry its license and source provenance, and remain
available without an implicit path back into this checkout.

## Evidence and acceptance

Automated checks cover parsing, missing values, column changes, shared bins,
dataset-scoped row identity, failed imports, package resolution, and application
construction. Native window visibility, normal interaction, and ordinary quit
require their own observations. Do not infer them from a successful link.

The consumer's `docs/authoring-exercise.md` defines a summary-panel extension.
At the user's request, Codex performed it and recorded the implementation,
layout failures, source lookup, fixes, and verification in the consumer's
`docs/authoring-walkthrough.md`. This is evidence from the existing app's author,
not an independent first-time usability study. Human participation is not a
prerequisite for completing the requested agent exercise.

The companion [workbench release gate](workbench-release-gate.md) keeps existing
correctness, native bridge, and artifact checks repeatable. Its automated result
must remain separate from manual input, accessibility, and on-screen timing
acceptance. Additional VoiceOver testing remains paused at the user's request.

## Implementation evidence (2026-09-23)

The local consumer is implemented. Its fresh-directory installation, headless
checks, native compilation, and ad-hoc signature verification passed without a
Moxi source checkout. See `../moxi-csv-compare/docs/verification.md` for the
precise checks, logs, native interaction observations, and remaining limitations.
An earlier app build passed interactive CSV loading, column switching, selection,
paging, failed-import preservation, and normal quit. The baseline visual
recheck encountered desktop automation's `cgWindowNotFound`. During the subsequent
summary-panel exercise, final-build native interaction and compact-layout
verification succeeded. The B summary was visible but omitted from the automation
accessibility tree; that limitation remains unresolved.

The workbench gate passed all five required tasks at source revision
`90dc288b6dde9ad66c66cb9b3e7ef1b1659198fe` with local gate/documentation changes.
Evidence is in `dist/workbench-release-gate/20260923T223050Z/report.json`.
The gate's four unit tests also passed. The optional benchmark and existing
package-consumer lanes were not run as part of this gate invocation.

## Scope

This milestone does not add platforms, plot families, a general CSV framework,
or a new layout abstraction. Library changes should answer failures or authoring
obstacles demonstrated by this consumer. A public release, remote repository,
and independent human acceptance are separate steps from creating and verifying
the local application.
