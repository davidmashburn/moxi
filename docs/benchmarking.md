# Benchmarking

Moxi's benchmark harness emits both human-readable workload output and a
machine-readable JSON report. The report is written under
`dist/benchmark-results/` (which is ignored) unless `MOXI_BENCHMARK_OUTPUT` or
`MOXI_BENCHMARK_DIR` is set.

Use the portable smoke profile while iterating:

```sh
pixi run benchmark-quick
```

It runs the typed localized-execution, retained layout/paint/scene, and
portable plot workloads once. Use `MOXI_BENCHMARK_RUNS=3` (or another positive
integer) when comparing runs.

Some benchmarks stay outside both profiles. `pixi run plot-reactive-benchmark`
compares retained `TypedSubtreeExecutor` dispatch against direct
`PlotView.dispatch` in one process and reports their ratio. A ratio between two
paths is a diagnostic rather than a deterministic counter, so it is not part of
the policy-checked matrix and does not contribute to a baseline. Keep workloads
of this shape out of the profiled programs: adding output to a profiled program
changes its deterministic signature and invalidates the reviewed baseline for
that case.

The localized and plot workloads identify themselves through
`canonical_scenarios()`. Run `pixi run scenario-check` when changing the
registry; it verifies that benchmark sources remain mapped to real files and
that the corresponding demo/test/golden metadata has not drifted. Each
descriptor also owns a deterministic `fixture_size`/`fixture_seed` pair; the
collection and plot factories derive their default workload from those values,
so changing a canonical fixture updates the demo/test/benchmark defaults
together. Text probes, theme golden modes, and the fractal preset/depth matrix
are likewise exported from the registry module rather than repeated in each
consumer. The complete capability step table is included in the same registry
so walkthrough fixtures do not drift from their demo or test metadata.

The localized workload also runs a 1/10/100-child matrix. Each case sends 1,000
targeted updates through a typed subtree and records initial/final builds,
invalidations, dependency visits, reconciled nodes, paint commands, and total
work. The keyed-subtree contract additionally records child insertions,
removals, reorders, parent composition, and explicit root fallback events.
These counters make subtree-size changes reviewable without treating a single
workstation's wall-clock time as a portability claim.

The complete matrix is available explicitly:

```sh
pixi run benchmark-full
```

The full profile adds statistical/large plots, collection interaction,
indexed plot queries, Metal plot packets, the interactive fractal workload,
and the offscreen Metal scene. Platform-specific cases build or skip through
their existing capability checks.

The checked-in [result schema](../benchmarks/result-schema.json) defines the
report shape. Each JSON report has `schema_version`, `profile`, `requested_runs`,
`warmup_runs`, an `environment` object, and a `cases` array. The environment
records the git revision/dirty state, Mojo compiler version, operating system,
and architecture. Every case records its command, profile/run parameters, and
each run's exit status, wall-clock seconds, and deterministic metric lines
(rows, commands, work counters, checksums, and similar workload evidence).
Wall-clock values are diagnostic; compare deterministic counters and checksums
first, and compare timings only between compatible environment records. The
comparator reports `median`, interpolated `p95`, and median absolute deviation
(`MAD`) for every case so a noisy sample is visible instead of being hidden by
a single average.

Reviewed release references live under
[`benchmarks/results/`](../benchmarks/results/). They are refreshed only from a
clean tree with the pinned compiler and repeated full profile; local/CI samples
remain in ignored `dist/benchmark-results/` output. The baseline policy treats
counter/checksum changes as contract review and wall-clock values as
same-environment diagnostics. The checked-in
[`benchmark-policy.json`](../benchmarks/benchmark-policy.json) is the host
matrix: it registers the reviewed macOS arm64 reference and records Linux and
Windows entries as planned. Run `pixi run benchmark-policy-check` when changing
the policy or a reviewed report. An unregistered host, compiler build, or
profile is rejected rather than compared as if it were macOS.

Portable work has a separate host-independent contract at
[`portable-quick-contract.json`](../benchmarks/results/portable-quick-contract.json).
It compares the exact structural metric lines and checksums for the quick
profile while deliberately omitting compiler, OS, architecture, and timing.
Run it on any supported host after producing a candidate report:

```sh
MOXI_BENCHMARK_RUNS=3 pixi run benchmark-quick
pixi run benchmark-contract-check -- --candidate dist/benchmark-results/quick.json
```

This is a cross-host deterministic gate, not a wall-clock claim. Keep using a
reviewed host baseline for full-profile timing; planned Linux and Windows full
entries are intentionally still blocked until clean host-specific references
exist.

Compare a compatible full-profile candidate with the reviewed macOS baseline:

```sh
MOXI_BENCHMARK_RUNS=3 pixi run benchmark-full
pixi run benchmark-compare
```

The comparison requires matching profile, run shape, Mojo version, OS, and
architecture; it requires at least three samples per case, checks deterministic
metric/checksum signatures exactly, and flags median regressions above 20% or
p95 regressions above 30% by default. Use `--max-regression-percent` and
`--max-p95-regression-percent` for review-specific diagnostic limits, and
`--allow-dirty` only for exploratory comparisons. A planned host needs its own
clean, repeated baseline before wall-clock comparison is enabled.

CI runs the quick profile three times and uploads `quick.json` as reviewable
evidence. That artifact is a smoke signal for deterministic work and sample
dispersion. The portable contract is the cross-host release signal; the
uploaded timing samples remain diagnostic.
