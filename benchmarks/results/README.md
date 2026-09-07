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

The portable quick profile also has a host-independent deterministic contract
at [`portable-quick-contract.json`](portable-quick-contract.json). It records
the exact structural metric lines and checksums for the three portable cases,
without compiler, OS, architecture, or timing fields. Any host can validate a
candidate after running the quick profile:

```sh
MOXI_BENCHMARK_RUNS=3 pixi run benchmark-quick
pixi run benchmark-contract-check -- --candidate dist/benchmark-results/quick.json
```

This is the cross-host gate for portable work. The full profile remains split:
use the deterministic contract when one is registered for that profile, and
use a reviewed host entry for wall-clock comparisons. A Linux or Windows full
baseline still needs its own clean repeated run before timing comparison is
enabled.

To add another host, collect a clean full-profile report with the pinned Mojo
compiler, add a `reviewed` entry with exact `os`, `architecture`, and
`mojo_version` fields to the policy, and have the deterministic signatures and
timing dispersion reviewed together. Until then, planned host entries must not
be used for wall-clock comparisons.
