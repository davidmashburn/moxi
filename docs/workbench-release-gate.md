# Workbench release gate

The workbench gate is the repeatable automated checkpoint for the packaged
macOS workbench. It delegates to existing Pixi tasks, records the repository
revision and dirty state, and writes a JSON report plus one JSON log per task
under `dist/workbench-release-gate/<UTC timestamp>/`.

The root manifest exposes the gate with this task:

```toml
workbench-release-gate = "python3 scripts/workbench_release_gate.py"
```

Run the required checks from the repository root:

```sh
pixi run workbench-release-gate
```

The required lane is intentionally small and uses the existing task contracts:

| Task | Evidence |
| --- | --- |
| `workbench-test` | Workbench data and rendering correctness tests |
| `native-custom-paint-cache` | Cached/direct native pixels and conservative invalidation |
| `native-accessibility-abi` | Native accessibility ABI probe and regression cases |
| `data-workbench-build` | Native build and sealed `.app` packaging |
| `workbench-artifact-check` | Bundle identity, executable, signature, and build manifest |

The build and artifact tasks are both recorded. Packaging already invokes an
artifact check, while the explicit follow-up leaves a separate gate record for
the final bundle on disk. A failed command makes the gate exit non-zero; the
remaining independent commands still run so the report contains useful failure evidence.
The artifact check is skipped if its required build fails, so an older bundle
cannot stand in for the failed build. Output directories must be new to prevent
a later run from overwriting earlier evidence.
Each command log includes its argv, working directory, timestamps, duration,
exit code, stdout, and stderr. The top-level report includes `revision`,
`dirty`, a run `timestamp`, `failure_reasons`, and the required and optional
task lists.

Use an explicit output path when a caller needs a stable disposable directory
or a test fixture:

```sh
pixi run workbench-release-gate -- \
  --output-dir /tmp/moxi-workbench-gate
```

The optional lanes are opt-in because they are expensive or exploratory:

```sh
# Record the structured benchmark; no latency threshold is applied.
pixi run workbench-release-gate -- --benchmark

# Build and exercise the package consumer lane.
pixi run workbench-release-gate -- --package-consumer
```

When `--benchmark` is selected, the gate records the `workbench-benchmark`
command and places its generated report below the run's `benchmark/` directory;
the command JSON log points to that evidence. It does not
turn CPU drawing measurements into a release threshold or claim input-to-screen
latency. Compare benchmark reports only with the workload and environment
recorded by the benchmark itself.

## Native checks that remain manual

The automated gate never promotes process discovery, a successful build, or a
successful command into native desktop acceptance. Its `manual_acceptance`
section remains `pending` for every run and requires a human review of:

- opening the packaged app, exercising the visible workbench, and quitting
  normally;
- real IME composition, commit, cancellation, and selected-range replacement;
- VoiceOver labels, traversal order, activation, and announcements; and
- timing through visible presentation on a physical display.

The existing [native acceptance record](workbench-native-acceptance.md)
contains the observed Japanese input and VoiceOver follow-up plus the open
coverage limits. The [native timing record](workbench-native-latency.md)
separates CPU drawing completion from compositor and input-to-photon timing;
its numbers are evidence for review, not an automated screen-latency gate.
`workbench-launch-smoke` can prepare and observe a CUA-owned process, but it
does not supply the interaction evidence needed to clear these manual items.

Review the generated `report.json` together with every command JSON log before
using the automated result in a release decision. A passing report means the
listed automated tasks passed at the recorded revision and dirty state; it
does not close the native acceptance items above.
