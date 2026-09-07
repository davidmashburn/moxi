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

The localized and plot workloads identify themselves through
`canonical_scenarios()`. Run `pixi run scenario-check` when changing the
registry; it verifies that benchmark sources remain mapped to real files and
that the corresponding demo/test/golden metadata has not drifted.

The localized workload also runs a 1/10/100-child matrix. Each case sends 1,000
targeted updates through a typed subtree and records initial/final builds,
invalidations, dependency visits, reconciled nodes, paint commands, and total
work. These counters make subtree-size changes reviewable without treating a
single workstation's wall-clock time as a portability claim.

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
first, and compare timings only between compatible environment records.

Reviewed release references live under
[`benchmarks/results/`](../benchmarks/results/). They are refreshed only from a
clean tree with the pinned compiler and repeated full profile; local/CI samples
remain in ignored `dist/benchmark-results/` output. The baseline policy treats
counter/checksum changes as contract review and wall-clock values as
same-environment diagnostics.
