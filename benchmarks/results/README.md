# Reviewed benchmark baselines

This directory contains deliberately reviewed release references, not every
local or CI sample. The host matrix and timing thresholds live in
[`../benchmark-policy.json`](../benchmark-policy.json). A baseline is valid only
for the environment recorded in its JSON `environment` object (`git_revision`,
dirty state, Mojo version, OS, and architecture).

To refresh the macOS arm64 full-profile reference:

```sh
MOXI_BENCHMARK_PROFILE=full \
MOXI_BENCHMARK_RUNS=3 \
MOXI_BENCHMARK_OUTPUT=benchmarks/results/macos-arm64-full.json \
bash scripts/benchmark.sh
```

Run this from a clean tree after reviewing deterministic counter/checksum
changes, with at least the policy's three samples per case. The report is
generated before the baseline file is written, so its `git_dirty` field
describes the source revision being measured. Run
`pixi run benchmark-policy-check` and review the diff; commit the baseline only
when the workload change is intentional. Wall-clock samples (including their
median, p95, and MAD) are useful for same-environment diagnostics; they are not
portable promises.

To add another host, collect a clean full-profile report with the pinned Mojo
compiler, add a `reviewed` entry with exact `os`, `architecture`, and
`mojo_version` fields to the policy, and have the deterministic signatures and
timing dispersion reviewed together. Until then, planned host entries must not
be used for wall-clock comparisons.
