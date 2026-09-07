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

The complete matrix is available explicitly:

```sh
pixi run benchmark-full
```

The full profile adds statistical/large plots, collection interaction,
indexed plot queries, Metal plot packets, the interactive fractal workload,
and the offscreen Metal scene. Platform-specific cases build or skip through
their existing capability checks.

Each JSON report has `schema_version`, `profile`, `requested_runs`, and a
`cases` array. Every case records its command and each run's exit status,
wall-clock seconds, and deterministic metric lines (rows, commands, work
counters, checksums, and similar workload evidence). Wall-clock values are
diagnostic; compare the deterministic counters and checksums first.
